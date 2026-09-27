#!/usr/bin/env python3
"""Build and maintain an AltStore Classic / SideStore source (standard library only)."""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path, PurePosixPath
import plistlib
import re
import subprocess
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import Request, urlopen
from zipfile import ZipFile


def numeric_version(value):
    if not re.fullmatch(r"(?:0|[1-9][0-9]*)(?:\.(?:0|[1-9][0-9]*)){1,2}", value):
        raise ValueError(f"Expected a stable numeric version such as 0.1.1, got {value!r}")
    parts = tuple(int(part) for part in value.split("."))
    return parts + (0,) * (3 - len(parts))


def build_name(ref, pubspec):
    if ref.startswith("refs/tags/"):
        tag = ref.removeprefix("refs/tags/")
        if not tag.startswith("v"):
            raise ValueError("Release tags must start with v, for example v0.1.1")
        version = tag[1:]
    else:
        match = re.search(r"^version:\s*['\"]?([0-9.]+)(?:\+[0-9]+)?['\"]?\s*(?:#.*)?$", pubspec, re.M)
        if not match:
            raise ValueError("pubspec.yaml must contain a numeric version such as 0.1.1+2")
        version = match[1]
    return ".".join(map(str, numeric_version(version)))


def required_string(info, key):
    value = info.get(key)
    if not isinstance(value, str) or not value.strip() or "$(" in value:
        raise ValueError(f"Missing or unresolved {key} in the built IPA")
    return value


def read_entitlements(bundle):
    result = subprocess.run(
        ["codesign", "--display", "--entitlements", "-", str(bundle)],
        capture_output=True,
        env={**os.environ, "LC_ALL": "C"},
        check=False,
    )
    if result.returncode:
        # --no-codesign produces unsigned bundles. Other codesign failures must
        # not silently turn into an empty permissions declaration.
        message = result.stderr.decode("utf-8", errors="replace")
        if "code object is not signed at all" in message:
            return {}
        raise ValueError(f"Cannot inspect entitlements for {bundle}: {message.strip()}")
    return plistlib.loads(result.stdout) if result.stdout.strip() else {}


def generate_source(ipa, app_bundle, repository, tag, expected_version, expected_build):
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", repository):
        raise ValueError("Repository must be in owner/repository format")
    if build_name(f"refs/tags/{tag}", "") != expected_version:
        raise ValueError("Release tag does not match the expected app version")

    with ZipFile(ipa) as archive:
        main_plists = [name for name in archive.namelist() if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", name)]
        if len(main_plists) != 1:
            raise ValueError("IPA must contain exactly one Payload/*.app/Info.plist")
        main_path = PurePosixPath(main_plists[0])
        app_root = main_path.parent
        info = plistlib.loads(archive.read(main_plists[0]))
        version = required_string(info, "CFBundleShortVersionString")
        build = required_string(info, "CFBundleVersion")
        if (version, build) != (expected_version, expected_build):
            raise ValueError(f"IPA version {version}+{build} does not match expected {expected_version}+{expected_build}")

        entitlements = set()
        privacy = {}
        # Inspect the actual app and any embedded app extensions, rather than
        # declaring every permission mentioned somewhere in the Xcode project.
        for name in archive.namelist():
            path = PurePosixPath(name)
            if not path.is_relative_to(app_root) or path.name != "Info.plist":
                continue
            if path.parent.suffix not in (".app", ".appex"):
                continue
            relative_bundle = path.parent.relative_to(app_root)
            if ".." in relative_bundle.parts:
                raise ValueError("Invalid bundle path in IPA")
            bundle = app_bundle.joinpath(*relative_bundle.parts)
            bundle_info = plistlib.loads(archive.read(name))
            if plistlib.loads((bundle / "Info.plist").read_bytes()) != bundle_info:
                raise ValueError(f"Built bundle and IPA metadata differ: {bundle}")
            entitlements.update(read_entitlements(bundle))
            for key, value in bundle_info.items():
                if "UsageDescription" in key and isinstance(value, str):
                    privacy.setdefault(key, value)

    # The signing tool supplies these per-user identifiers itself.
    entitlements.difference_update({"application-identifier", "com.apple.developer.team-identifier"})
    website = f"https://github.com/{repository}"
    source_url = f"{website}/releases/latest/download/apps.json"
    download_base = f"{website}/releases/download/{quote(tag, safe='')}"
    icon_url = f"{download_base}/icon.png"
    bundle_id = required_string(info, "CFBundleIdentifier")
    app = {
        "name": info.get("CFBundleDisplayName") or required_string(info, "CFBundleName"),
        "bundleIdentifier": bundle_id,
        "developerName": repository.split("/")[0],
        "localizedDescription": "明日方舟剧情阅读与回顾。支持剧情文本、语音和音乐播放。",
        "iconURL": icon_url,
        "category": "entertainment",
        "appPermissions": {"entitlements": sorted(entitlements), "privacy": privacy},
        "versions": [{
            "version": version,
            "buildVersion": build,
            "date": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "localizedDescription": f"Arknights Story {version}。更新说明：{website}/releases/tag/{quote(tag, safe='')}",
            "downloadURL": f"{download_base}/{quote(ipa.name, safe='')}",
            "size": ipa.stat().st_size,
            "minOSVersion": required_string(info, "MinimumOSVersion"),
        }],
    }
    return {
        "name": "Arknights Story",
        "identifier": f"io.github.{repository.replace('/', '.').replace('_', '-').lower()}",
        # Keep the canonical URL stable even when GitHub redirects to an asset.
        "sourceURL": source_url,
        "iconURL": icon_url,
        "website": website,
        "apps": [app],
        "news": [],
    }


def fetch_previous_source(url):
    request = Request(url, headers={"User-Agent": "ArknightsStory-Release"})
    try:
        with urlopen(request, timeout=60) as response:
            return json.load(response)
    except HTTPError as error:
        if error.code == 404:
            # First release using this workflow has no apps.json yet.
            return None
        raise


def merge_history(source, previous):
    if previous is None:
        return source
    if previous.get("identifier") != source["identifier"]:
        raise ValueError("Previous source has a different identifier")
    app = source["apps"][0]
    previous_apps = previous.get("apps", [])
    if len(previous_apps) != 1 or previous_apps[0].get("bundleIdentifier") != app["bundleIdentifier"]:
        raise ValueError("Bundle identifier changed; existing installations would not receive updates")
    old_app = previous_apps[0]
    old_versions = old_app.get("versions")
    if not isinstance(old_versions, list) or not old_versions:
        raise ValueError("Previous source has no version history")
    latest = app["versions"][0]
    # Each public release must use a new version/tag. This also prevents a slow
    # older build or a rerun from replacing the current stable source.
    if any(numeric_version(latest["version"]) <= numeric_version(old["version"]) for old in old_versions):
        raise ValueError("Version must be newer than the published source; publish a new tag instead of replacing a release")
    app["versions"].extend(old_versions)
    # Older compatible versions may still need permissions removed in this one.
    old_permissions = old_app.get("appPermissions", {})
    permissions = app["appPermissions"]
    permissions["entitlements"] = sorted(set(permissions["entitlements"]) | set(old_permissions.get("entitlements", [])))
    permissions["privacy"] = {**old_permissions.get("privacy", {}), **permissions["privacy"]}
    return source


def write_source(path, source):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    version_parser = commands.add_parser("version", help="Resolve the Flutter build name")
    version_parser.add_argument("--ref", default=os.environ.get("GITHUB_REF", ""))
    version_parser.add_argument("--pubspec", type=Path, default=Path("pubspec.yaml"))
    generate_parser = commands.add_parser("generate", help="Read an IPA and its built bundles on macOS")
    generate_parser.add_argument("--ipa", type=Path, required=True)
    generate_parser.add_argument("--app-bundle", type=Path, required=True)
    generate_parser.add_argument("--repository", required=True)
    generate_parser.add_argument("--tag", required=True)
    generate_parser.add_argument("--expected-version", required=True)
    generate_parser.add_argument("--expected-build", required=True)
    generate_parser.add_argument("--output", type=Path, required=True)
    merge_parser = commands.add_parser("merge", help="Preserve history from the current public source")
    merge_parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()
    try:
        if args.command == "version":
            print(f"build_name={build_name(args.ref, args.pubspec.read_text(encoding='utf-8'))}")
        elif args.command == "generate":
            source = generate_source(args.ipa, args.app_bundle, args.repository, args.tag, args.expected_version, args.expected_build)
            write_source(args.output, source)
        else:
            source = json.loads(args.source.read_text(encoding="utf-8"))
            previous = fetch_previous_source(source["sourceURL"])
            write_source(args.source, merge_history(source, previous))
    except (ValueError, OSError) as error:
        parser.exit(1, f"error: {error}\n")


if __name__ == "__main__":
    main()
