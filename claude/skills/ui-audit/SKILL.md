---
name: ui-audit
description: >-
  Systematic visual audit of a web app. Two modes: (1) Wireframe comparison,
  matching implementation against a design spec HTML file with CSS property
  extraction. (2) Standalone UX/product review, evaluating usability, visual
  hierarchy, interaction patterns, and mobile responsiveness from a user
  perspective. Both modes produce severity-rated reports with screenshots.
  Use when asked to "audit the UI", "review the UX", "compare against wireframes",
  "product review", "check the design", "UX review", "usability check", or any
  request to evaluate a web app's user experience. Also trigger proactively
  after significant UI changes.
---

# UI Audit

Two audit modes for web apps. Pick the right one for the task.

## Mode 1: UX / Product Review (no wireframe needed)

Evaluate the app as a real user would. No design spec required.

### Workflow

1. **Capture every screen** at desktop (1280x800) and mobile (390x844):
```bash
python3 scripts/capture_screens.py <app_url> -o /tmp/ui-audit --config screens.json
```
Or manually navigate and screenshot each route.

2. **For each screen**, evaluate against the UX checklist (`references/ux-review-checklist.md`):
   - First impressions (what grabs attention, what confuses)
   - Information hierarchy (is the most important content most prominent?)
   - Navigation clarity (can the user find what they need?)
   - Interaction affordances (do clickable things look clickable?)
   - Content quality (clear labels, no jargon, helpful empty states)
   - Error and edge states (what happens when things go wrong?)
   - Mobile experience (not just a squeezed desktop, actually usable)
   - Loading and performance perception (skeleton states, progress indicators)
   - Accessibility basics (contrast, touch targets, focus indicators)

3. **Cross-screen analysis**:
   - Consistency (same patterns used everywhere?)
   - User flow (can a new user complete the core task without confusion?)
   - Visual cohesion (colors, spacing, typography consistent?)
   - Missing states (what screens/states are absent that users will hit?)

4. **Output report** grouped by severity (S1-S4), with screenshots and fix recommendations.

### When to use Mode 1
- No wireframe or design spec exists
- Evaluating a competitor's product
- Post-launch UX review
- Checking if the app "feels right" independent of any spec
- Product feedback before a redesign

## Mode 2: Wireframe Comparison (requires design spec)

Compare a live implementation against a static wireframe HTML file. Produces exact CSS property mismatches.

### Prerequisites

- `playwright` Python package with Chromium
- Wireframe HTML file path
- Live app URL (deployed or localhost)

### Workflow

1. **Screenshot every screen** at desktop and mobile:
```bash
python3 scripts/capture_screens.py <app_url> -o /tmp/ui-audit --config screens.json
```

2. **Extract computed CSS from wireframe**:
```bash
python3 scripts/extract_wireframe_specs.py <wireframe.html> --selectors selectors.json -o /tmp/wireframe-specs.json
```

3. **Screen-by-screen comparison** using `references/audit-checklist.md`:
   - Read wireframe HTML for that screen section
   - Read captured screenshot of the live app
   - Read implementation source (React/TSX/Vue/etc.)
   - Walk the per-component checklist (layout, spacing, colors, typography, borders, interactive states, icons, responsive)
   - For each mismatch: record severity, wireframe value, implementation value, file:line, fix

4. **Output report** grouped by screen, then severity.

### When to use Mode 2
- A wireframe or design system HTML exists
- Pixel-accuracy matters (design handoff)
- Post-implementation design QA before launch
- Verifying that a redesign matches the approved mockup

## Report Format

Both modes use the same severity scale and output format:

```markdown
# UI Audit Report - [App Name]
**Date:** YYYY-MM-DD
**Mode:** UX Review / Wireframe Comparison
**URL:** [url]
**Screens Audited:** [list]

## Summary
- Total issues: X
- S1 (Critical): X
- S2 (Major): X
- S3 (Minor): X
- S4 (Cosmetic): X

## Findings

### [Screen Name] - [Viewport]

#### [Issue Title]
- **Severity:** S2
- **Category:** Visual Hierarchy / Interaction / Content / Layout / Responsive
- **What:** [Description of the problem]
- **Why it matters:** [Impact on user experience]
- **Fix:** [Specific recommendation]
- **File:** [file:line if applicable]

[screenshot if available]
```

## Severity Levels

| Level | Name | Description | Example |
|-------|------|-------------|---------|
| S1 | Critical | Broken flow, missing screen, unusable on a viewport | Can't submit a form, page blank on mobile |
| S2 | Major | Confusing UX, wrong visual hierarchy, significant layout issues | CTA hidden below fold, wrong colors misleading users |
| S3 | Minor | Small spacing issues, subtle inconsistencies, minor polish | 4px padding mismatch, slightly wrong border radius |
| S4 | Cosmetic | Barely visible, animation timing, sub-pixel differences | 0.5px border, 50ms transition timing |

## Resources

- `references/ux-review-checklist.md` - Standalone UX/product review checklist
- `references/audit-checklist.md` - Per-component wireframe comparison checklist
- `references/wireframe-screens.md` - Template for screen inventory and selector mappings
- `scripts/capture_screens.py` - Playwright screenshot automation (config-driven)
- `scripts/extract_wireframe_specs.py` - Computed CSS extraction from wireframe HTML
