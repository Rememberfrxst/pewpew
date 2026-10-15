#!/usr/bin/env python3
"""Prepare this cloud checkout's Android exporter without modifying game files."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import urllib.request
import zipfile

ROOT = Path('/workspace/tooling')
VERSION = '4.6.3'


def main():
    project = Path(__file__).resolve().parent.parent
    subprocess.run(['python3', str(project / 'tools/setup_android.py'), str(ROOT / 'android-sdk')], check=True)
    data = Path(os.environ.get('XDG_DATA_HOME', str(ROOT / 'user-data')))
    templates = data / 'godot/export_templates' / (VERSION + '.stable')
    if not all((templates / n).exists() for n in ['android_debug.apk', 'android_release.apk']):
        cache = ROOT / 'downloads'
        cache.mkdir(parents=True, exist_ok=True)
        base = f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/'
        name = f'Godot_v{VERSION}-stable_export_templates.tpz'
        with urllib.request.urlopen(base + 'SHA512-SUMS.txt', timeout=60) as response:
            sums = response.read().decode()
        expected = next(line.split()[0] for line in sums.splitlines() if line.endswith(name))
        archive = cache / 'templates.tpz'
        if not archive.exists():
            print('Downloading official export templates (~1.2 GB)', flush=True)
            urllib.request.urlretrieve(base + name, archive)
        with archive.open('rb') as file:
            assert hashlib.file_digest(file, 'sha512').hexdigest() == expected, 'Export template checksum mismatch'
        templates.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive) as zipped:
            for name in ['android_debug.apk', 'android_release.apk']:
                with zipped.open('templates/' + name) as source, (templates / name).open('wb') as target:
                    shutil.copyfileobj(source, target)
    keystore = ROOT / 'debug.keystore'
    if not keystore.exists():
        subprocess.run(['keytool', '-genkeypair', '-keystore', str(keystore), '-storepass', 'android', '-alias', 'androiddebugkey', '-keypass', 'android', '-dname', 'CN=Android Debug,O=Android,C=US', '-keyalg', 'RSA', '-keysize', '2048', '-validity', '10000'], check=True)
    config = Path(os.environ.get('XDG_CONFIG_HOME', str(ROOT / 'config'))) / 'godot'
    config.mkdir(parents=True, exist_ok=True)
    editor = config / 'editor_settings-4.6.tres'
    text = editor.read_text() if editor.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
    java = shutil.which('java')
    assert java, 'Install Java before exporting'
    entries = {
        'export/android/android_sdk_path': str(ROOT / 'android-sdk'),
        'export/android/java_sdk_path': str(Path(java).resolve().parent.parent),
        'export/android/debug_keystore': str(keystore),
        'export/android/debug_keystore_user': 'androiddebugkey',
        'export/android/debug_keystore_pass': 'android',
    }
    for key, value in entries.items():
        line = key + ' = ' + json.dumps(value)
        pattern = '^' + re.escape(key) + r'\s*=.*$'
        text = re.sub(pattern, lambda _: line, text, flags=re.M) if re.search(pattern, text, re.M) else text.rstrip() + '\n' + line + '\n'
    editor.write_text(text)
    print('Cloud Android exporter configured; game source unchanged.')


if __name__ == '__main__':
    main()
