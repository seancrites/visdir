#!/usr/bin/env python3
# =============================================================================
# convert-data.py
#
# PURPOSE: Bidirectional converter between VisDir JSON data files and CSV.
#          JSON -> CSV exports the array portion with a union of all keys.
#          CSV -> JSON wraps rows in a VisDir-compatible object with a site
#          object either copied from an existing JSON file or a template.
#
# USAGE:
#   python convert-data.py --to-csv  input.json output.csv
#   python convert-data.py --to-json input.csv output.json
#   python convert-data.py --to-json input.csv output.json --site-from old.json
#
# AUTHOR: Generated for the visdir project
# VERSION: 1.0.0
# DATE: 2026-04-25
# =============================================================================

import argparse
import csv
import json
import os
import sys

# ---------------------------------------------------------------------------
# Template site object (used when no existing JSON is referenced)
# ---------------------------------------------------------------------------
DEFAULT_SITE = {
    "name": "Visual Directory",
    "slogan": "A beautiful visual directory for any group",
    "motto": "See it. Find it. Connect.",
    "year": 2026,
    "maintainer": "",
    "show_contact": False,
    "support_url": "",
    "support_label": "",
    "logo_svg": (
        '<svg xmlns="http://www.w3.org/2000/svg" width="42" height="42" '
        'viewBox="0 0 24 24" fill="none" stroke="#f59e0b" stroke-width="2.5" '
        'stroke-linecap="round" stroke-linejoin="round">'
        '<path d="M3 8L12 20L21 8"/></svg>'
    )
}


def confirm_overwrite(path, auto_yes=False):
    """Prompt for overwrite confirmation unless auto_yes is True."""
    if auto_yes or not os.path.exists(path):
        return True
    response = input(f"'{path}' already exists. Overwrite? [y/N]: ").strip().lower()
    return response in ("y", "yes")


def find_array(data):
    """Locate the list/array inside a JSON dict.

    Checks common keys first, then falls back to the first list value found.
    Returns (key_name, list_value).
    """
    for key in ("entities", "churches", "items", "data"):
        if key in data and isinstance(data[key], list):
            return key, data[key]
    for key, value in data.items():
        if isinstance(value, list):
            return key, value
    raise ValueError("No array found in JSON data")


def json_to_csv(json_path, csv_path, auto_yes=False):
    """Convert a VisDir JSON file to CSV (array portion only)."""
    with open(json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    array_key, rows = find_array(data)
    if not rows:
        print(f"Warning: '{array_key}' array is empty.")

    # Preserve key order from first row, then append extra keys in discovery order
    seen = set()
    headers = []
    for row in rows:
        if isinstance(row, dict):
            for key in row.keys():
                if key not in seen:
                    seen.add(key)
                    headers.append(key)

    if not confirm_overwrite(csv_path, auto_yes):
        print("Aborted.")
        sys.exit(0)

    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=headers, quoting=csv.QUOTE_ALL)
        writer.writeheader()
        for row in rows:
            if isinstance(row, dict):
                writer.writerow({h: row.get(h, "") for h in headers})
            else:
                writer.writerow({h: "" for h in headers})

    print(
        f"✓ Wrote {len(rows)} rows to '{csv_path}' with {len(headers)} columns."
    )


def csv_to_json(csv_path, json_path, site_from=None, auto_yes=False):
    """Convert a CSV file to a VisDir-compatible JSON file."""
    rows = []
    with open(csv_path, "r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            cleaned = {k: (v.strip() if v else "") for k, v in row.items()}
            rows.append(cleaned)

    site = None
    if site_from:
        with open(site_from, "r", encoding="utf-8") as f:
            existing = json.load(f)
        if "site" in existing:
            site = existing["site"]
            print(f"✓ Copied 'site' object from '{site_from}'")
        else:
            print(f"Warning: '{site_from}' has no 'site' object; using template.")

    if site is None:
        site = DEFAULT_SITE.copy()
        print("✓ Using template 'site' object")

    output = {"site": site, "entities": rows}

    if not confirm_overwrite(json_path, auto_yes):
        print("Aborted.")
        sys.exit(0)

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(output, f, indent=3, ensure_ascii=False)
        f.write("\n")

    print(f"✓ Wrote {len(rows)} entities to '{json_path}'.")


def main():
    parser = argparse.ArgumentParser(
        description="Convert between VisDir JSON data files and CSV."
    )
    parser.add_argument(
        "--to-csv",
        nargs=2,
        metavar=("INPUT.json", "OUTPUT.csv"),
        help="Convert JSON array to CSV",
    )
    parser.add_argument(
        "--to-json",
        nargs=2,
        metavar=("INPUT.csv", "OUTPUT.json"),
        help="Convert CSV to JSON with site object",
    )
    parser.add_argument(
        "--site-from",
        metavar="FILE.json",
        help="Existing JSON file to copy the site object from",
    )
    parser.add_argument(
        "-y", "--yes",
        action="store_true",
        help="Auto-confirm overwrites",
    )

    args = parser.parse_args()

    if not args.to_csv and not args.to_json:
        parser.print_help()
        sys.exit(1)

    if args.to_csv and args.to_json:
        print("Error: Use --to-csv OR --to-json, not both.")
        sys.exit(1)

    if args.to_csv:
        json_path, csv_path = args.to_csv
        if not os.path.exists(json_path):
            print(f"Error: '{json_path}' not found.")
            sys.exit(1)
        json_to_csv(json_path, csv_path, auto_yes=args.yes)

    if args.to_json:
        csv_path, json_path = args.to_json
        if not os.path.exists(csv_path):
            print(f"Error: '{csv_path}' not found.")
            sys.exit(1)

        site_from = args.site_from
        if not site_from and sys.stdin.isatty():
            response = (
                input(
                    "Use an existing JSON file to copy the 'site' object from? [y/N]: "
                )
                .strip()
                .lower()
            )
            if response in ("y", "yes"):
                site_from = input("Enter path to the JSON file: ").strip()
                if site_from and not os.path.exists(site_from):
                    print(f"Warning: '{site_from}' not found; using template.")
                    site_from = None

        csv_to_json(csv_path, json_path, site_from=site_from, auto_yes=args.yes)


if __name__ == "__main__":
    main()
