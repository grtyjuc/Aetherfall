#!/usr/bin/env python3
"""Install pinned official tools in .tools on Linux x86_64. No global changes."""
import hashlib
import io
import platform
from pathlib import Path
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOOLS = (
    ("rojo", "rojo-rbx/rojo", "7.7.1", "00feb4fa0829a1dd72b49df2639da519a352bfe13cadcd83969e2ba2bb5693c4"),
    ("lune", "lune-org/lune", "0.11.1", "39859282ce677fce19e6eb45c37596a90a25c324c95b4e7e02d428b6cae294a1"),
)


def main():
    if (platform.system(), platform.machine()) != ("Linux", "x86_64"):
        raise SystemExit("Use official Rojo 7.7.1 and Lune 0.11.1 releases for your OS; this cloud installer supports Linux x86_64.")
    folder = ROOT / ".tools"
    folder.mkdir(exist_ok=True)
    for name, repo, version, digest in TOOLS:
        url = f"https://github.com/{repo}/releases/download/v{version}/{name}-{version}-linux-x86_64.zip"
        with urllib.request.urlopen(url, timeout=60) as response:
            archive = response.read()
        if hashlib.sha256(archive).hexdigest() != digest:
            raise SystemExit(f"Checksum mismatch for {name}; tool was not installed.")
        with zipfile.ZipFile(io.BytesIO(archive)) as zipped:
            members = [n for n in zipped.namelist() if Path(n).name == name]
            if len(members) != 1:
                raise SystemExit(f"Unexpected release structure for {name}.")
            output = folder / name
            output.write_bytes(zipped.read(members[0]))
            output.chmod(0o755)
        print(f"Installed {name} {version} (SHA256 verified).", flush=True)


if __name__ == "__main__":
    main()
