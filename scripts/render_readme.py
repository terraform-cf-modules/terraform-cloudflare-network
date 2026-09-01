#!/usr/bin/env python3
"""
Render README.md from README.yaml, matching the CloudDrove house layout used
across terraform-az-modules, terraform-do-modules and clouddrove.

README.yaml is the single source of truth. This script only renders it, so the
result stays compatible with the shared `readme` workflow (geine), which
regenerates the same file from the same input.

Also refreshes docs/io.md (root) and modules/<name>/README.md via terraform-docs.

Usage:
    python3 scripts/render_readme.py          # render README.md and docs
    python3 scripts/render_readme.py --check  # fail if either is stale

Only the standard library is used; PyYAML is optional and a small parser is
used when it is unavailable.
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


# --------------------------------------------------------------------------
# Minimal YAML reader (only the shapes README.yaml actually uses)
# --------------------------------------------------------------------------

def load_yaml(path: str) -> dict:
    try:
        import yaml  # type: ignore

        with open(path) as fh:
            return yaml.safe_load(fh) or {}
    except ImportError:
        pass

    data: dict = {}
    key = None
    block: list[str] | None = None
    block_indent = 0
    seq_key = None

    with open(path) as fh:
        lines = fh.read().split("\n")

    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.rstrip()
        stripped = line.strip()

        if block is not None:
            if not stripped:
                block.append("")
                i += 1
                continue
            indent = len(raw) - len(raw.lstrip())
            if indent >= block_indent:
                block.append(raw[block_indent:])
                i += 1
                continue
            data[key] = "\n".join(block).strip("\n")
            block = None

        if not stripped or stripped.startswith("#") or stripped == "---":
            i += 1
            continue

        if stripped.startswith("- ") and seq_key:
            item: dict = {}
            first = stripped[2:]
            if ":" in first:
                k, _, v = first.partition(":")
                item[k.strip()] = v.strip().strip('"').strip("'")
            j = i + 1
            while j < len(lines):
                nxt = lines[j]
                if not nxt.strip() or nxt.strip().startswith("#"):
                    j += 1
                    continue
                ind = len(nxt) - len(nxt.lstrip())
                if ind < 4 or nxt.strip().startswith("- "):
                    break
                k, _, v = nxt.strip().partition(":")
                item[k.strip()] = v.strip().strip('"').strip("'")
                j += 1
            data.setdefault(seq_key, []).append(item)
            i = j
            continue

        m = re.match(r"^([A-Za-z_][\w]*):\s*(.*)$", stripped)
        if m:
            key, value = m.group(1), m.group(2)
            if value in ("|-", "|", ">-", ">"):
                block, block_indent, seq_key = [], 2, None
            elif value == "":
                seq_key = key
                data.setdefault(key, [])
            else:
                data[key] = value.strip('"').strip("'")
                seq_key = None
        i += 1

    if block is not None and key:
        data[key] = "\n".join(block).strip("\n")
    return data


# --------------------------------------------------------------------------
# terraform-docs
# --------------------------------------------------------------------------

def have(binary: str) -> bool:
    return subprocess.run(["which", binary], capture_output=True).returncode == 0


def terraform_docs() -> None:
    """Write docs/io.md for the root module and a README for each submodule."""
    if not have("terraform-docs"):
        print("terraform-docs not installed, skipping io.md", file=sys.stderr)
        return

    os.makedirs(os.path.join(ROOT, "docs"), exist_ok=True)

    # Root: .terraform-docs.yml writes docs/io.md, matching the house layout.
    subprocess.run(["terraform-docs", ROOT], capture_output=True, text=True, cwd=ROOT)

    # Submodules keep their tables inline, so they use the second config.
    sub_cfg = os.path.join(ROOT, ".terraform-docs-submodule.yml")
    mod_dir = os.path.join(ROOT, "modules")
    if not os.path.isdir(mod_dir) or not os.path.exists(sub_cfg):
        return
    for name in sorted(os.listdir(mod_dir)):
        path = os.path.join(mod_dir, name)
        if not os.path.isdir(path) or not os.path.exists(os.path.join(path, "README.md")):
            continue
        subprocess.run(
            ["terraform-docs", "--config", sub_cfg, path],
            capture_output=True, text=True, cwd=ROOT,
        )


# --------------------------------------------------------------------------
# Render
# --------------------------------------------------------------------------

BANNER = "https://clouddrove.s3.ca-central-1.amazonaws.com/img/clouddrove-github-cover.png"


def render(cfg: dict) -> str:
    repo = cfg.get("github_repo", "")
    name = cfg.get("name", "Terraform Module")

    out = [
        "<!-- This file was automatically generated from `README.yaml`. "
        "Make all changes to `README.yaml` and run `make readme` to rebuild this file. -->",
        "<p align=\"center\">",
        f"  <img width=\"1000\" alt=\"CloudDrove Banner\" src=\"{BANNER}\" />",
        "</p>",
        "<h1 align=\"center\">",
        f"    {name}",
        "</h1>",
        "",
        "<p align=\"center\" style=\"font-size: 1.2rem;\">",
        f"    {cfg.get('intro', '').strip()}",
        "</p>",
        "",
        "<p align=\"center\">",
        "",
    ]

    for badge in cfg.get("badges", []):
        out += [
            f"<a href=\"{badge.get('url', '')}\">",
            f"  <img src=\"{badge.get('image', '')}\" alt=\"{badge.get('name', '')}\">",
            "</a>",
        ]
    if repo:
        for wf, label in (("tf-checks", "tf-checks"), ("tflint", "tf-lint"),
                          ("checkov", "checkov"), ("test", "test")):
            out += [
                f"<a href=\"https://github.com/{repo}/actions/workflows/{wf}.yml\">",
                f"  <img src=\"https://github.com/{repo}/actions/workflows/{wf}.yml/badge.svg\" "
                f"alt=\"{label}\">",
                "</a>",
            ]
    out += ["", "</p>", "<hr>", "", ""]

    if cfg.get("description"):
        out += [cfg["description"].strip(), "", ""]

    prereq = cfg.get("prerequisites", [])
    providers = cfg.get("providers", [])
    if prereq or providers:
        out += [
            "## Prerequisites and Providers",
            "",
            "This table contains both Prerequisites and Providers:",
            "",
            "| Description | Name | Version |",
            "|-------------|------|---------|",
        ]
        for p in prereq:
            out.append(f"| Prerequisite | {p.get('name','')} | {p.get('version','')} |")
        for p in providers:
            out.append(f"| Provider | {p.get('name','')} | {p.get('version','')} |")
        out += ["", "---", "", ""]

    if cfg.get("submodules"):
        out += [
            "## 🧩 Submodules",
            "",
            "Each submodule is separately addressable with the double slash source syntax, so you "
            "can take only the piece you need instead of the whole root module.",
            "",
            cfg["submodules"].strip(),
            "",
            "---",
            "",
            "",
        ]

    if cfg.get("usage"):
        out += ["## 🚀 Usage", "", cfg["usage"].strip(), "", "---", "", ""]

    out += [
        "## 📦 Examples",
        "",
        f"> ⚠️ **Important:** Avoid using the `main` branch directly, as it may include unstable "
        f"changes. Always use stable [release versions](https://github.com/{repo}/releases).",
        "",
        "Explore real-world usage scenarios and implementation patterns in the "
        "[`examples/`](./examples/) directory.",
        "",
        "---",
        "",
        "",
        "## 📥 Inputs and Outputs",
        "",
        "Detailed input variables and output values are documented for easier integration and "
        "day-to-day usage.",
        "",
        "📘 [View full documentation](docs/io.md)",
        "",
        "---",
        "",
        "",
        "## 📝 Changelog",
        "",
        "Track module updates, improvements, and breaking changes across versions.",
        "",
        "📌 [View Changelog](CHANGELOG.md)",
        "",
        "---",
        "",
        "",
        "## ✨ Contributors",
        "",
        "Big thanks to our contributors for elevating our project with their dedication and "
        "expertise!",
        "",
        "<div align=\"center\">",
        f"  <a href=\"https://github.com/{repo}/graphs/contributors\" title=\"Contributors\">",
        f"    <img src=\"https://contrib.rocks/image?repo={repo}\" />",
        "  </a>",
        "</div>",
        "",
        "All contributors must follow the [Conventional Commits]"
        "(https://www.conventionalcommits.org) specification for commit messages.",
        "",
        "---",
        "",
        "",
        "## 🚀 Our Accomplishment",
        "",
        "We maintain Terraform modules across AWS, Azure, Google Cloud, DigitalOcean, "
        "Hetzner Cloud and Cloudflare 🙌.",
        "",
        "- [**Terraform Module Registry**]"
        "(https://registry.terraform.io/namespaces/terraform-cf-modules): "
        "Discover our Cloudflare modules here.",
        "- [**Full module catalog**](https://github.com/clouddrove/toc): "
        "Every CloudDrove module and submodule, across every cloud.",
        "",
        "---",
        "",
        "## Notes",
        "",
        "- Do not use the `main` branch for production deployments.",
        "- Always reference a stable version using Git tags or official releases.",
        "- Using tagged versions ensures consistency, stability, and reproducible deployments.",
        "",
        "---",
        "",
        "## Feedback",
        "",
        f"Report issues or request features on [GitHub](https://github.com/{repo}/issues), "
        "or write to [business@clouddrove.com](mailto:business@clouddrove.com).",
        "",
        "## About us",
        "",
        "At [CloudDrove](https://clouddrove.com), we build reliable, secure and cost efficient "
        "cloud native solutions. Join our "
        "[Slack community](https://www.launchpass.com/devops-talks).",
    ]
    return "\n".join(out).rstrip() + "\n"



def render_llms(cfg: dict) -> str:
    """Compact machine index for LLMs, llmstxt.org convention."""
    repo = cfg.get("github_repo", "")
    name = cfg.get("name", "Terraform Module")
    registry = cfg.get("registry_address") or ""
    if not registry and repo.startswith("terraform-cf-modules/terraform-cloudflare-"):
        registry = (
            "terraform-cf-modules/"
            + repo.split("terraform-cloudflare-", 1)[1]
            + "/cloudflare"
        )

    about = (cfg.get("about") or cfg.get("intro") or "").strip()
    out = [
        f"# {name}",
        "",
        f"> {about}",
        "",
        f"Terraform module for Cloudflare, maintained by CloudDrove. "
        f"Source: `{registry}`. Repository: https://github.com/{repo}",
        "",
        "Requires Terraform >= 1.12.0 (or OpenTofu >= 1.12) and the "
        "`cloudflare/cloudflare` provider ~> 5.24. Provider v5 renamed most "
        "resources from v4, so verify resource names against the current "
        "provider docs rather than older examples.",
        "",
        "## Usage",
        "",
        "```hcl",
        'module "this" {',
        f'  source  = "{registry}"',
        '  version = "~> 0.1"',
        "}",
        "```",
        "",
    ]

    mod_dir = os.path.join(ROOT, "modules")
    subs = []
    if os.path.isdir(mod_dir):
        subs = sorted(
            d for d in os.listdir(mod_dir)
            if os.path.isdir(os.path.join(mod_dir, d))
        )
    if subs:
        out += [
            "## Submodules",
            "",
            "Each is separately addressable with the double slash source syntax.",
            "",
        ]
        for sname in subs:
            out.append(
                f"- [{sname}](https://github.com/{repo}/tree/main/modules/{sname}): "
                f"`{registry}//modules/{sname}`"
            )
        out.append("")

    out += [
        "## Documentation",
        "",
        f"- [README](https://github.com/{repo}/blob/main/README.md): overview and usage",
        f"- [Inputs and outputs](https://github.com/{repo}/blob/main/docs/io.md): "
        "every variable and output",
        f"- [Examples](https://github.com/{repo}/tree/main/examples): runnable configurations",
        f"- [Architecture](https://github.com/{repo}/blob/main/docs/architecture.md): "
        "resource map and provider quirks",
        "",
        "## Related",
        "",
        "- [All CloudDrove modules](https://github.com/clouddrove/toc): every module and "
        "submodule across AWS, Azure, Google Cloud, DigitalOcean, Hetzner Cloud and Cloudflare",
        "- [Organisation](https://github.com/terraform-cf-modules): the Cloudflare module family",
        "- [Terraform Registry](https://registry.terraform.io/namespaces/terraform-cf-modules)",
    ]
    return "\n".join(out).rstrip() + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="fail if README.md is stale")
    args = ap.parse_args()

    cfg = load_yaml(os.path.join(ROOT, "README.yaml"))
    terraform_docs()
    body = render(cfg)

    llms = render_llms(cfg)
    target = os.path.join(ROOT, "README.md")
    llms_target = os.path.join(ROOT, "llms.txt")

    if args.check:
        stale = []
        for path, want in ((target, body), (llms_target, llms)):
            have_now = open(path).read() if os.path.exists(path) else ""
            if have_now != want:
                stale.append(os.path.basename(path))
        if stale:
            print(f"Stale: {', '.join(stale)}. Run `make readme`.", file=sys.stderr)
            return 1
        print("README.md and llms.txt are up to date.")
        return 0

    with open(target, "w") as fh:
        fh.write(body)
    with open(llms_target, "w") as fh:
        fh.write(llms)
    print(f"wrote {target} and {llms_target}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
