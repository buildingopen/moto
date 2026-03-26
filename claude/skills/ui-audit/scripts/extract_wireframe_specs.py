#!/usr/bin/env python3
"""
Extract design specs from a wireframe HTML file.

Parses a static HTML wireframe and extracts computed CSS properties
for every major UI component, organized by screen ID.

Selectors can come from a JSON config file or be auto-discovered from the document.

Usage:
    python3 extract_wireframe_specs.py <wireframe.html> [--selectors <selectors.json>] [--screen <id>] [--output <path>]

Selectors JSON format:
{
  "screen_id": [
    [".css-selector", "component-name"],
    [".another-selector", "another-component"]
  ]
}

Output: JSON file mapping screen_id -> component -> css_properties
"""

import argparse
import asyncio
import json
import sys
from pathlib import Path

# Properties to extract for each element
PROPERTIES = [
    "background", "background-color", "background-image",
    "color", "font-size", "font-weight", "font-family",
    "line-height", "letter-spacing", "text-align", "text-transform",
    "padding", "padding-top", "padding-right", "padding-bottom", "padding-left",
    "margin", "margin-top", "margin-right", "margin-bottom", "margin-left",
    "border", "border-radius", "border-color", "border-width",
    "box-shadow",
    "width", "height", "min-width", "min-height", "max-width", "max-height",
    "display", "flex-direction", "align-items", "justify-content", "gap",
    "opacity",
]


async def extract_specs(wireframe_path: str, selectors_path: str | None = None, screen_filter: str | None = None) -> dict:
    from playwright.async_api import async_playwright

    specs = {}

    # Load selectors from config or auto-discover
    screen_components = {}
    if selectors_path:
        raw = json.loads(Path(selectors_path).read_text())
        for screen_id, components in raw.items():
            screen_components[screen_id] = [(sel, name) for sel, name in components]

    async with async_playwright() as p:
        browser = await p.chromium.launch()
        page = await browser.new_page(viewport={"width": 1400, "height": 900})

        file_url = f"file://{Path(wireframe_path).resolve()}"
        await page.goto(file_url)
        await page.wait_for_timeout(1000)

        # Get all screen IDs from the document
        screen_ids = await page.evaluate("""
            () => Array.from(document.querySelectorAll('.screen[id], [data-screen][id], section[id]')).map(el => el.id)
        """)
        print(f"Found screens: {', '.join(screen_ids) if screen_ids else '(none, using document root)'}", file=sys.stderr)

        # If no selectors config, auto-discover major elements per screen
        if not screen_components:
            for sid in screen_ids:
                if screen_filter and sid != screen_filter and screen_filter != "all":
                    continue
                # Auto-discover elements with class names
                components = await page.evaluate(f"""
                    () => {{
                        const screen = document.getElementById('{sid}');
                        if (!screen) return [];
                        const els = screen.querySelectorAll('[class]');
                        const seen = new Set();
                        const result = [];
                        els.forEach(el => {{
                            const cls = '.' + Array.from(el.classList).join('.');
                            if (!seen.has(cls) && el.classList.length > 0) {{
                                seen.add(cls);
                                result.push([cls, el.classList[0]]);
                            }}
                        }});
                        return result;
                    }}
                """)
                if components:
                    screen_components[sid] = components

        for screen_id, components in screen_components.items():
            if screen_filter and screen_id != screen_filter and screen_filter != "all":
                continue

            screen_specs = {}
            target_screen = screen_id

            for selector, component_name in components:
                scoped = f"#{target_screen} {selector}" if target_screen in screen_ids else selector

                try:
                    result = await page.evaluate(f"""
                        (args) => {{
                            const el = document.querySelector(args.selector);
                            if (!el) return null;
                            const cs = window.getComputedStyle(el);
                            const props = {{}};
                            for (const prop of args.properties) {{
                                props[prop] = cs.getPropertyValue(prop);
                            }}
                            const rect = el.getBoundingClientRect();
                            props['_bbox'] = {{
                                width: Math.round(rect.width),
                                height: Math.round(rect.height),
                            }};
                            return props;
                        }}
                    """, {"selector": scoped, "properties": PROPERTIES})

                    if result:
                        screen_specs[component_name] = result
                    else:
                        print(f"  WARN: {scoped} not found", file=sys.stderr)
                except Exception as e:
                    print(f"  ERROR extracting {scoped}: {e}", file=sys.stderr)

            if screen_specs:
                specs[screen_id] = screen_specs
                print(f"Extracted {len(screen_specs)} components from '{screen_id}'", file=sys.stderr)

        await browser.close()

    return specs


def main():
    parser = argparse.ArgumentParser(description="Extract design specs from wireframe HTML")
    parser.add_argument("wireframe", help="Path to wireframe HTML file")
    parser.add_argument("--selectors", default=None, help="JSON file mapping screen_id -> [(selector, name)]")
    parser.add_argument("--screen", default="all", help="Screen ID to extract (default: all)")
    parser.add_argument("--output", "-o", default=None, help="Output JSON path (default: stdout)")
    args = parser.parse_args()

    specs = asyncio.run(extract_specs(args.wireframe, args.selectors, args.screen))

    output = json.dumps(specs, indent=2)
    if args.output:
        Path(args.output).write_text(output)
        print(f"Wrote specs to {args.output}", file=sys.stderr)
    else:
        print(output)


if __name__ == "__main__":
    main()
