"""Release helpers, run by the GitHub workflow (.github/workflows/release.yml)
on every version tag (v1.0.0, v1.1.0-beta1...). Python standard library only.

    python tools/release.py check v1.0.0   the tag matches the TOC's version
    python tools/release.py notes          this version's CHANGELOG section
    python tools/release.py curseforge     upload the zip to CurseForge

CurseForge needs the CF_API_KEY environment variable (a GitHub secret). The
project ID comes from the TOC (## X-Curse-Project-ID), the game version from
CF_GAME_VERSION (default 1.60.1, WoW Forever) or CF_GAME_VERSION_ID.
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ADDON = "EasyController"
API = "https://wow.curseforge.com/api"


def toc_field(name):
    toc = (ROOT / f"{ADDON}.toc").read_text(encoding="utf-8")
    match = re.search(rf"^## {re.escape(name)}:\s*(\S+)", toc, re.M)
    return match and match.group(1)


def version():
    return toc_field("Version")


def notes(ver=None):
    """The CHANGELOG section of a version, without its title."""
    ver = ver or version()
    text = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    match = re.search(rf"^## {re.escape(ver)}(?=\s|$).*?$\n(.*?)(?=^## |\Z)", text, re.M | re.S)
    if not match:
        sys.exit(f"CHANGELOG.md has no '## {ver}' section")
    return match.group(1).strip() + "\n"


def release_type(ver):
    if "alpha" in ver:
        return "alpha"
    if "beta" in ver or "-" in ver:
        return "beta"
    return "release"


def request(url, token, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers={"X-Api-Token": token, **(headers or {})})
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read().decode("utf-8") or "null")
    except urllib.error.HTTPError as error:
        sys.exit(f"{url}: HTTP {error.code} {error.read().decode('utf-8', 'replace')}")


def game_version_id(token):
    if os.environ.get("CF_GAME_VERSION_ID"):
        return int(os.environ["CF_GAME_VERSION_ID"])
    wanted = os.environ.get("CF_GAME_VERSION") or "1.60.1"
    versions = request(f"{API}/game/versions", token)
    found = [v for v in versions if v.get("name") == wanted]
    if not found:
        close = sorted({v.get("name") for v in versions if str(v.get("name", "")).startswith(wanted.split(".")[0] + ".")})
        sys.exit(f"No CurseForge game version named {wanted}. Close ones: {', '.join(close[-20:])}\n"
                 "Set the CF_GAME_VERSION (or CF_GAME_VERSION_ID) repository variable.")
    if len(found) > 1:
        print("Several game versions named", wanted, [(v["id"], v.get("gameVersionTypeID")) for v in found])
    return found[-1]["id"]


def curseforge():
    token = os.environ.get("CF_API_KEY")
    if not token:
        sys.exit("CF_API_KEY is not set (GitHub: Settings > Secrets and variables > Actions)")
    project = toc_field("X-Curse-Project-ID")
    if not project:
        sys.exit("The TOC has no '## X-Curse-Project-ID'")
    ver = version()
    zip_path = ROOT / "dist" / f"{ADDON}-{ver}.zip"
    if not zip_path.is_file():
        sys.exit(f"{zip_path} is missing: run tools/package.py first")

    metadata = {
        "changelog": notes(ver),
        "changelogType": "markdown",
        "displayName": f"Easy Controller - Forever {ver}",
        "releaseType": release_type(ver),
        "gameVersions": [game_version_id(token)],
    }
    boundary = uuid.uuid4().hex
    body = b"".join([
        f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n\r\n".encode(),
        json.dumps(metadata).encode("utf-8"),
        f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"{zip_path.name}\"\r\n"
        "Content-Type: application/zip\r\n\r\n".encode(),
        zip_path.read_bytes(),
        f"\r\n--{boundary}--\r\n".encode(),
    ])
    result = request(f"{API}/projects/{project}/upload-file", token, body,
                     {"Content-Type": f"multipart/form-data; boundary={boundary}"})
    print(f"CurseForge: {zip_path.name} uploaded ({metadata['releaseType']}), file id {result and result.get('id')}")


def main():
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "check":
        tag = sys.argv[2] if len(sys.argv) > 2 else ""
        if tag != f"v{version()}":
            sys.exit(f"The tag {tag} doesn't match the TOC's version {version()} (expected v{version()})")
        notes()
        print(f"Version {version()}: ok")
    elif command == "notes":
        sys.stdout.write(notes(sys.argv[2] if len(sys.argv) > 2 else None))
    elif command == "curseforge":
        curseforge()
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
