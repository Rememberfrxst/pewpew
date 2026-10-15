#!/usr/bin/env python3
"""Install official Android SDK binaries with repository-provided checksums.

Useful in proxy environments where Java's sdkmanager cannot fetch manifests.
No credentials or TLS overrides are used. Requires Python 3 and Internet access.
"""
import hashlib
import os
from pathlib import Path
import shutil
import sys
import urllib.request
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(sys.argv[1] if len(sys.argv) > 1 else "/workspace/tooling/android-sdk")
BASE = "https://dl.google.com/android/repository/"
PACKAGES = {
    "platform-tools": "platform-tools",
    "build-tools;36.0.0": "build-tools/36.0.0",
    "platforms;android-36": "platforms/android-36",
}


def main():
    ROOT.mkdir(parents=True, exist_ok=True)
    cache = ROOT / ".downloads"
    cache.mkdir(exist_ok=True)
    with urllib.request.urlopen(BASE + "repository2-3.xml", timeout=60) as response:
        manifest = ET.fromstring(response.read())
    for package, destination in PACKAGES.items():
        node = next(p for p in manifest.findall("remotePackage") if p.attrib["path"] == package)
        archive = next(a for a in node.findall("archives/archive") if a.findtext("host-os") in (None, "linux"))
        complete = archive.find("complete")
        name = complete.findtext("url")
        local = cache / name
        if not local.exists():
            print("Downloading", name, flush=True)
            urllib.request.urlretrieve(BASE + name, local)
        checksum = complete.find("checksum")
        with local.open("rb") as file:
            digest = hashlib.file_digest(file, checksum.attrib["type"]).hexdigest()
        if digest != checksum.text:
            raise RuntimeError(f"Checksum mismatch: {name}; remove {local} and retry")
        target = ROOT / destination
        if target.exists():
            print("Verified archive; keeping installed", package)
            continue
        stage = cache / (name + ".unpacked")
        stage.mkdir(exist_ok=True)
        with zipfile.ZipFile(local) as zipped:
            for entry in zipped.infolist():
                extracted = Path(zipped.extract(entry, stage))
                mode = entry.external_attr >> 16
                if mode:
                    os.chmod(extracted, mode)
        contents = list(stage.iterdir())
        assert len(contents) == 1 and contents[0].is_dir(), name
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(contents[0]), target)
        stage.rmdir()
        print("Installed and checksum verified:", package)


if __name__ == "__main__":
    main()
