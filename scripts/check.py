#!/usr/bin/env python3
"""Run meaningful offline checks and build the Studio place. Fails on any error."""
from pathlib import Path
import shutil
import subprocess
import os

ROOT = Path(__file__).resolve().parents[1]


def tool(name):
    candidate = ROOT / ".tools" / (name + (".exe" if os.name == "nt" else ""))
    found = str(candidate) if candidate.is_file() else shutil.which(name)
    if not found:
        raise SystemExit(f"Missing {name}. See README.md for tool setup.")
    return found


def run(*args):
    print("+ " + " ".join(map(str, args)), flush=True)
    subprocess.run(list(map(str, args)), cwd=ROOT, check=True)


def main():
    lune, rojo = tool("lune"), tool("rojo")
    run(lune, "run", "tests/compile.spec.luau")
    run(lune, "run", "tests/equipment.spec.luau")
    run(lune, "run", "tests/models.spec.luau")
    run(lune, "run", "tests/world.spec.luau")
    run(lune, "run", "tests/combat.spec.luau")
    run(lune, "run", "tests/combat-service.spec.luau")
    run(lune, "run", "tests/attachments.spec.luau")
    run(lune, "run", "tests/training-world.spec.luau")
    run(lune, "run", "tests/progression.spec.luau")
    run(lune, "run", "tests/schema.spec.luau")
    run(lune, "run", "tests/session-store.spec.luau")
    run(lune, "run", "tests/player-data.spec.luau")
    run(lune, "run", "tests/rewards.spec.luau")
    run(lune, "run", "tests/village-world.spec.luau")
    run(lune, "run", "tests/quests.spec.luau")
    run(lune, "run", "tests/quest-service.spec.luau")
    run(lune, "run", "tests/enemies.spec.luau")
    run(lune, "run", "tests/enemy-rewards.spec.luau")
    run(lune, "run", "tests/rest.spec.luau")
    run(lune, "run", "tests/audio.spec.luau")
    run(lune, "run", "tests/grove.spec.luau")
    run(lune, "run", "tests/grove-service.spec.luau")
    run(lune, "run", "tests/grove-world.spec.luau")
    run(lune, "run", "tests/boss.spec.luau")
    run(lune, "run", "tests/boss-gear.spec.luau")
    (ROOT / "build").mkdir(exist_ok=True)
    run(rojo, "build", "default.project.json", "--output", "build/Aetherfall-Step-5.rbxl")
    run(lune, "run", "tests/place.spec.luau")
    (ROOT / "studio").mkdir(exist_ok=True)
    shutil.copyfile(ROOT / "build/Aetherfall-Step-5.rbxl", ROOT / "studio/Aetherfall.rbxl")
    print("Packaged studio/Aetherfall.rbxl", flush=True)


if __name__ == "__main__":
    main()
