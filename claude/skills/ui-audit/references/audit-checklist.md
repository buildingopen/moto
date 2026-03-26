# Wireframe Comparison Checklist

Systematic checklist for comparing a live implementation against a wireframe.
Work through each section per-screen, per-viewport (desktop + mobile).

## Per-Component Checklist

For every UI component, check these properties in order of visual impact:

### 1. Layout & Structure
- [ ] Correct element hierarchy (parent/child nesting)
- [ ] Correct display type (flex, grid, block)
- [ ] Correct flex-direction, align-items, justify-content, gap
- [ ] Correct width, height, min/max dimensions
- [ ] Component present on correct viewport (hidden/shown on desktop vs mobile)

### 2. Spacing
- [ ] Padding matches (top, right, bottom, left)
- [ ] Margin matches
- [ ] Gap between children matches

### 3. Colors & Backgrounds
- [ ] Background color/gradient matches
- [ ] Text color matches
- [ ] Border color matches
- [ ] Uses correct CSS variable (check wireframe source)
- [ ] Opacity matches

### 4. Typography
- [ ] Font size matches
- [ ] Font weight matches
- [ ] Line height matches
- [ ] Text alignment matches
- [ ] Letter spacing / text-transform matches

### 5. Borders & Shapes
- [ ] Border radius matches
- [ ] Border width matches
- [ ] Border style (solid, none, etc.)
- [ ] Box shadow matches

### 6. Interactive States
- [ ] Hover state matches (color, bg, transform, shadow changes)
- [ ] Active/pressed state matches
- [ ] Focus state matches (border color, glow/ring)
- [ ] Disabled state matches (opacity, cursor)
- [ ] Selected/active state matches (for toggles, tabs, cards)

### 7. Icons & Assets
- [ ] Correct icon used (check SVG path or icon library name)
- [ ] Icon size matches
- [ ] Icon color matches

### 8. Responsive Behavior
- [ ] Component shows/hides at correct breakpoint
- [ ] Mobile variant uses correct alternative layout
- [ ] Touch targets are adequate size (min 44x44 on mobile)

## Severity Levels

Rate each difference found:

| Level | Name | Description | Example |
|-------|------|-------------|---------|
| S1 | Critical | Wrong layout, missing component, broken interaction | Sidebar missing, wrong page structure |
| S2 | Major | Wrong colors, wrong spacing by >8px, wrong typography | Blue instead of green, 32px gap instead of 16px |
| S3 | Minor | Off by 1-4px, slightly different radius, subtle color shade | 16px radius vs 18px, rgba opacity 0.08 vs 0.1 |
| S4 | Cosmetic | Barely visible, animation timing, sub-pixel rendering | 0.5px border difference, 50ms transition |

## Audit Report Format

```markdown
# UI Audit Report - [App Name]
**Date:** YYYY-MM-DD
**Wireframe:** [filename]
**Live URL:** [url]
**Screens Audited:** [list]

## Summary
- Total issues: X
- S1 (Critical): X
- S2 (Major): X
- S3 (Minor): X
- S4 (Cosmetic): X

## Findings

### [Screen Name] - [Viewport]

#### [Component Name]
- **Severity:** S2
- **Property:** background-color
- **Wireframe:** [expected value]
- **Implementation:** [actual value] (src/components/Example.tsx:57)
- **Fix:** [specific change to make]

[screenshot comparison if available]
```

## Tips

- Extract CSS specs from the wireframe HTML using `scripts/extract_wireframe_specs.py`
- Compare computed values, not class names (Tailwind `bg-gray-50` != CSS `var(--bg-secondary)` even if they happen to match)
- Check mobile separately, not just "does it fit" but "is the mobile variant correct"
- CSS variables in wireframes may not match Tailwind utility classes; always resolve to computed values
