#!/usr/bin/env python3
"""
Capture screenshots of a live web app for UI audit.

Takes screenshots at both desktop (1280x800) and mobile (390x844) viewports.
Screen definitions can come from a JSON config file or use built-in defaults.

Usage:
    python3 capture_screens.py <base_url> [--output-dir <path>] [--config <screens.json>] [--screens <id,...>]

Config JSON format:
{
  "screen_id": {
    "desktop": { "route": "/path", "name": "screen-desktop" },
    "mobile": { "route": "/path", "name": "screen-mobile" }
  }
}

Optional per-screen keys: "click" (selector), "prefill" ({"selector": ..., "text": ...}),
"setup_js" (JavaScript to run before capture).

Output: PNG screenshots in the output directory + manifest.json.
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path

# Default screens if no config provided
DEFAULT_SCREENS = {
    "home": {
        "desktop": {"route": "/", "name": "home-desktop"},
        "mobile": {"route": "/", "name": "home-mobile"},
    },
}


async def capture_all(base_url: str, output_dir: str, screens: dict, screen_filter: list[str] | None = None):
    from playwright.async_api import async_playwright

    out = Path(output_dir)
    out.mkdir(parents=True, exist_ok=True)

    async with async_playwright() as p:
        browser = await p.chromium.launch()

        desktop_ctx = await browser.new_context(viewport={"width": 1280, "height": 800})
        desktop_page = await desktop_ctx.new_page()

        mobile_ctx = await browser.new_context(viewport={"width": 390, "height": 844})
        mobile_page = await mobile_ctx.new_page()

        captured = []

        for screen_id, viewports in screens.items():
            if screen_filter and screen_id not in screen_filter:
                continue

            for viewport, config in viewports.items():
                page = desktop_page if viewport == "desktop" else mobile_page
                name = config.get("name", f"{screen_id}-{viewport}")
                route = config.get("route", "/")
                url = f"{base_url.rstrip('/')}{route}"

                await page.goto(url)

                # Run setup JavaScript if provided
                if "setup_js" in config:
                    try:
                        await page.evaluate(config["setup_js"])
                        await page.wait_for_timeout(500)
                    except Exception as e:
                        print(f"  WARN: setup_js failed for {name}: {e}", file=sys.stderr)

                await page.wait_for_timeout(1200)

                # Click action (e.g. navigate to sub-page)
                if "click" in config:
                    try:
                        await page.locator(config["click"]).click(timeout=5000)
                        await page.wait_for_timeout(800)
                    except Exception as e:
                        print(f"  WARN: click failed for {name}: {e}", file=sys.stderr)

                # Prefill input
                if "prefill" in config:
                    pf = config["prefill"]
                    try:
                        await page.fill(pf["selector"], pf["text"])
                        await page.wait_for_timeout(300)
                    except Exception as e:
                        print(f"  WARN: prefill failed for {name}: {e}", file=sys.stderr)

                path = out / f"{name}.png"
                await page.screenshot(path=str(path), full_page=False)
                captured.append({"screen": screen_id, "viewport": viewport, "file": str(path)})
                print(f"Captured: {name}", file=sys.stderr)

        await browser.close()

    manifest_path = out / "manifest.json"
    manifest_path.write_text(json.dumps(captured, indent=2))
    print(f"\nCaptured {len(captured)} screenshots -> {output_dir}", file=sys.stderr)
    return captured


def main():
    parser = argparse.ArgumentParser(description="Capture app screenshots for UI audit")
    parser.add_argument("base_url", help="Base URL of the live app")
    parser.add_argument("--output-dir", "-o", default="/tmp/ui-audit-screenshots",
                        help="Output directory for screenshots")
    parser.add_argument("--config", "-c", default=None,
                        help="JSON config file defining screens to capture")
    parser.add_argument("--screens", "-s", default=None,
                        help="Comma-separated screen IDs to capture (default: all)")
    args = parser.parse_args()

    if args.config:
        screens = json.loads(Path(args.config).read_text())
    else:
        screens = DEFAULT_SCREENS

    screen_filter = args.screens.split(",") if args.screens else None
    asyncio.run(capture_all(args.base_url, args.output_dir, screens, screen_filter))


if __name__ == "__main__":
    main()
