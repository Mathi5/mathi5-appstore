#!/usr/bin/env python3
"""
Validate the Runtipi app store structure.

For each app under apps/, checks:
  - apps/<id>/config.json is valid JSON
  - apps/<id>/docker-compose.yml is valid YAML and contains `x-runtipi: schema_version: 2`
  - apps/<id>/metadata/description.md exists
  - apps/<id>/metadata/logo.jpg exists
  - config.json `id` matches the folder name

Exit code 0 on success, 1 on any failure.
"""
import json
import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PyYAML is required: pip install pyyaml", file=sys.stderr)
    sys.exit(2)


def find_apps(root: Path):
    apps_dir = root / "apps"
    if not apps_dir.is_dir():
        return []
    return sorted(p for p in apps_dir.iterdir() if p.is_dir())


def check_app(app_dir: Path) -> list[str]:
    errors: list[str] = []
    folder_id = app_dir.name

    config_path = app_dir / "config.json"
    if not config_path.is_file():
        errors.append(f"[{folder_id}] missing config.json")
        return errors

    try:
        config = json.loads(config_path.read_text())
    except json.JSONDecodeError as e:
        errors.append(f"[{folder_id}] invalid config.json: {e}")
        return errors

    cfg_id = config.get("id")
    if cfg_id != folder_id:
        errors.append(
            f"[{folder_id}] config.json `id` ({cfg_id!r}) does not match folder name"
        )

    for required in ("name", "available", "port", "categories", "version"):
        if required not in config:
            errors.append(f"[{folder_id}] config.json missing required field: {required}")

    compose_path = app_dir / "docker-compose.yml"
    compose_alt = app_dir / "docker-compose.json"
    chosen = compose_path if compose_path.is_file() else (
        compose_alt if compose_alt.is_file() else None
    )
    if chosen is None:
        errors.append(
            f"[{folder_id}] missing docker-compose.yml (or legacy docker-compose.json)"
        )
    else:
        try:
            compose = yaml.safe_load(chosen.read_text())
        except yaml.YAMLError as e:
            errors.append(f"[{folder_id}] invalid {chosen.name}: {e}")
            compose = None
        if compose is not None:
            schema = (compose or {}).get("x-runtipi", {}).get("schema_version")
            if schema != 2:
                errors.append(
                    f"[{folder_id}] {chosen.name} missing `x-runtipi: schema_version: 2`"
                )
            services = (compose or {}).get("services", {}) or {}
            main = [
                name for name, svc in services.items()
                if (svc or {}).get("x-runtipi", {}).get("is_main")
            ]
            if not main:
                errors.append(
                    f"[{folder_id}] {chosen.name} has no service with `x-runtipi.is_main: true`"
                )

    if not (app_dir / "metadata" / "description.md").is_file():
        errors.append(f"[{folder_id}] missing metadata/description.md")
    if not (app_dir / "metadata" / "logo.jpg").is_file():
        errors.append(f"[{folder_id}] missing metadata/logo.jpg")

    return errors


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    apps = find_apps(root)
    if not apps:
        print("No apps found under apps/", file=sys.stderr)
        return 1

    all_errors: list[str] = []
    for app_dir in apps:
        errs = check_app(app_dir)
        all_errors.extend(errs)

    if all_errors:
        print("FAILED:", file=sys.stderr)
        for e in all_errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    print(f"OK: {len(apps)} app(s) validated")
    for app_dir in apps:
        print(f"  - {app_dir.name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
