#!/usr/bin/env python3
"""
PaywallKit deploy tool.

Usage:
  # Deploy a new variant
  python3 deploy.py --app serene --placement onboarding --variant B --file /tmp/serene_b.html --weight 50

  # Show rotation status
  python3 deploy.py --app serene --status

  # Kill a variant (redistributes weight evenly)
  python3 deploy.py --app serene --placement onboarding --kill-variant A

  # Promote a winner to 100%
  python3 deploy.py --app serene --placement onboarding --promote B
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from google.cloud import storage

BUCKET = os.environ.get("PAYWALL_BUCKET", "kreativekoala-paywalls")
CONFIG_BLOB = "paywalls/config.json"


def get_client():
    return storage.Client()


def download_config(client) -> dict:
    bucket = client.bucket(BUCKET)
    blob = bucket.blob(CONFIG_BLOB)
    if blob.exists():
        return json.loads(blob.download_as_text())
    return {"placements": {}, "rules": []}


def upload_config(client, config: dict):
    bucket = client.bucket(BUCKET)
    blob = bucket.blob(CONFIG_BLOB)
    blob.upload_from_string(
        json.dumps(config, indent=2),
        content_type="application/json",
    )
    print(f"✅ Config updated: gs://{BUCKET}/{CONFIG_BLOB}")


def upload_html(client, app_id: str, placement: str, variant_id: str, file_path: str) -> str:
    gcs_path = f"paywalls/{app_id}/{placement}_{variant_id.lower()}.html"
    bucket = client.bucket(BUCKET)
    blob = bucket.blob(gcs_path)
    with open(file_path, "rb") as f:
        blob.upload_from_file(f, content_type="text/html")
    print(f"✅ HTML uploaded: gs://{BUCKET}/{gcs_path}")
    return gcs_path


def status(args):
    client = get_client()
    config = download_config(client)
    placements = config.get("placements", {})

    app_prefix = f"{args.app}/" if args.app else ""
    found = False

    for placement_key, placement_data in placements.items():
        if not placement_key.startswith(app_prefix):
            continue
        found = True
        exp = placement_data.get("experiment", "—")
        print(f"\n📍 {placement_key}  [experiment: {exp}]")
        variants = placement_data.get("variants", [])
        for v in variants:
            bar = "█" * (v["weight"] // 5)
            print(f"   {'→' if v == variants[0] else ' '} {v['id']}  [{v['weight']:3d}%] {bar}  {v['url']}")

    if not found:
        print(f"No placements found for app: {args.app or 'all'}")


def deploy(args):
    if not args.file or not os.path.exists(args.file):
        print(f"❌ File not found: {args.file}")
        sys.exit(1)

    client = get_client()
    config = download_config(client)
    placements = config.setdefault("placements", {})

    placement_key = f"{args.app}/{args.placement}"
    placement_data = placements.setdefault(placement_key, {
        "experiment": f"exp_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M')}",
        "variants": []
    })

    # Upload HTML
    gcs_path = upload_html(client, args.app, args.placement, args.variant, args.file)

    # Update or add variant
    variants = placement_data["variants"]
    existing = next((v for v in variants if v["id"] == args.variant), None)

    if existing:
        existing["url"] = gcs_path
        existing["weight"] = args.weight
        print(f"📝 Updated variant {args.variant}")
    else:
        variants.append({"id": args.variant, "weight": args.weight, "url": gcs_path})
        print(f"➕ Added variant {args.variant}")

    # Normalize weights to sum to 100
    _normalize_weights(variants, pinned=args.variant, pinned_weight=args.weight)

    upload_config(client, config)
    _print_rotation(placement_key, placement_data)


def kill_variant(args):
    client = get_client()
    config = download_config(client)
    placement_key = f"{args.app}/{args.placement}"
    placement_data = config.get("placements", {}).get(placement_key)
    if not placement_data:
        print(f"❌ Placement not found: {placement_key}")
        sys.exit(1)

    variants = [v for v in placement_data["variants"] if v["id"] != args.kill_variant]
    if not variants:
        print("❌ Can't kill last variant")
        sys.exit(1)

    # Redistribute weight evenly
    per = 100 // len(variants)
    remainder = 100 - per * len(variants)
    for i, v in enumerate(variants):
        v["weight"] = per + (1 if i < remainder else 0)

    placement_data["variants"] = variants
    upload_config(client, config)
    print(f"🗑  Killed variant {args.kill_variant}")
    _print_rotation(placement_key, placement_data)


def promote(args):
    client = get_client()
    config = download_config(client)
    placement_key = f"{args.app}/{args.placement}"
    placement_data = config.get("placements", {}).get(placement_key)
    if not placement_data:
        print(f"❌ Placement not found: {placement_key}")
        sys.exit(1)

    variants = placement_data["variants"]
    winner = next((v for v in variants if v["id"] == args.promote), None)
    if not winner:
        print(f"❌ Variant {args.promote} not found")
        sys.exit(1)

    for v in variants:
        v["weight"] = 100 if v["id"] == args.promote else 0

    # Remove zero-weight variants
    placement_data["variants"] = [winner]
    placement_data["experiment"] = f"exp_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M')}_promoted"

    upload_config(client, config)
    print(f"🏆 Promoted variant {args.promote} to 100%")


def _normalize_weights(variants: list, pinned: str, pinned_weight: int):
    others = [v for v in variants if v["id"] != pinned]
    remaining = 100 - pinned_weight
    if not others:
        return
    per = remaining // len(others)
    remainder = remaining - per * len(others)
    for i, v in enumerate(others):
        v["weight"] = per + (1 if i < remainder else 0)


def _print_rotation(placement_key: str, placement_data: dict):
    print(f"\n📍 {placement_key}")
    for v in placement_data.get("variants", []):
        bar = "█" * (v["weight"] // 5)
        print(f"   {v['id']}  [{v['weight']:3d}%] {bar}")


def main():
    parser = argparse.ArgumentParser(description="PaywallKit deploy tool")
    parser.add_argument("--app", required=True, help="App ID e.g. serene, lifecanvas")
    parser.add_argument("--placement", help="Placement name e.g. onboarding, feature_gate")
    parser.add_argument("--variant", help="Variant ID e.g. A, B, C")
    parser.add_argument("--file", help="Path to HTML file")
    parser.add_argument("--weight", type=int, default=50, help="Traffic weight 0-100")
    parser.add_argument("--status", action="store_true", help="Show current rotation")
    parser.add_argument("--kill-variant", help="Remove a variant from rotation")
    parser.add_argument("--promote", help="Promote variant to 100 percent traffic")

    args = parser.parse_args()

    if args.status:
        status(args)
    elif args.kill_variant:
        kill_variant(args)
    elif args.promote:
        promote(args)
    elif args.file:
        deploy(args)
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
