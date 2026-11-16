#!/usr/bin/env python3
"""Add a published IPA to the AltStore/SideStore/Feather source in app.json.

The version and build number come from the packaged app's Info.plist, so the
source always matches what SideStore and Feather actually download.
"""

import argparse
import hashlib
import json
import os
import plistlib
import sys
import zipfile


def read_ipa(ipa_path):
    with zipfile.ZipFile(ipa_path) as ipa:
        info_name = next(
            (
                name
                for name in ipa.namelist()
                if name.startswith("Payload/")
                and name.count("/") == 2
                and name.endswith(".app/Info.plist")
            ),
            None,
        )
        if info_name is None:
            raise SystemExit(f"{ipa_path} does not contain an app Info.plist")
        info = plistlib.load(ipa.open(info_name))

    version = info.get("CFBundleShortVersionString")
    build = info.get("CFBundleVersion")
    if not version or not build:
        raise SystemExit(f"{ipa_path} has no version metadata")
    return version, build


def sha256(ipa_path):
    digest = hashlib.sha256()
    with open(ipa_path, "rb") as ipa:
        for chunk in iter(lambda: ipa.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-json", required=True, help="source file to update")
    parser.add_argument("--ipa", required=True, help="packaged IPA to describe")
    parser.add_argument("--download-url", required=True, help="public URL of the IPA")
    parser.add_argument("--date", required=True, help="release date, YYYY-MM-DD")
    parser.add_argument("--min-os", default="17.0", help="minimum iOS version")
    args = parser.parse_args()

    version, build = read_ipa(args.ipa)

    try:
        with open(args.app_json, encoding="utf-8") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        sys.exit(f"Could not read {args.app_json}: {error}")

    apps = data.get("apps") or []
    if not apps:
        sys.exit(f"{args.app_json} has no apps entry")

    app = apps[0]
    versions = app.setdefault("versions", [])
    if any(
        entry.get("version") == version and entry.get("buildVersion") == build
        for entry in versions
    ):
        print(f"{args.app_json} already lists {version} ({build})")
        return

    versions.insert(
        0,
        {
            "version": version,
            "buildVersion": build,
            "date": args.date,
            "downloadURL": args.download_url,
            "size": os.path.getsize(args.ipa),
            "minOSVersion": args.min_os,
            "sha256": sha256(args.ipa),
        },
    )

    with open(args.app_json, "w", encoding="utf-8") as handle:
        json.dump(data, handle, indent=2)
        handle.write("\n")
    print(f"Added {version} ({build}) to {args.app_json}")


if __name__ == "__main__":
    main()
