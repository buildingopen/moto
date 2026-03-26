# UX / Product Review Checklist

Systematic checklist for evaluating a web app from a user's perspective.
No wireframe or design spec needed. Work through each section per screen, per viewport.

## Per-Screen Evaluation

### 1. First Impressions (5-second test)
- [ ] What is this page for? (Can you tell within 5 seconds?)
- [ ] What is the primary action? (Is it obvious?)
- [ ] What grabs attention first? (Is it the right thing?)
- [ ] Is there anything confusing or unexpected?
- [ ] Does the page feel finished or work-in-progress?

### 2. Information Hierarchy
- [ ] Most important content is most prominent (size, position, contrast)
- [ ] Secondary content is clearly subordinate
- [ ] Nothing competes with the primary CTA for attention
- [ ] Headings and labels describe content accurately
- [ ] Empty states are helpful (tell user what to do, not just "nothing here")

### 3. Navigation & Wayfinding
- [ ] User can tell where they are (active state, breadcrumbs, title)
- [ ] User can get back (back button, home link, breadcrumbs)
- [ ] Navigation labels match user mental models (not internal jargon)
- [ ] Important features are discoverable (not hidden in menus)
- [ ] Navigation is consistent across pages

### 4. Interaction Design
- [ ] Clickable elements look clickable (buttons look like buttons)
- [ ] Non-clickable elements don't look clickable
- [ ] Hover states provide feedback
- [ ] Forms have clear labels, not just placeholders
- [ ] Input validation is inline and immediate (not only on submit)
- [ ] Destructive actions require confirmation
- [ ] Loading states exist for async operations
- [ ] Success/error feedback is clear and timely

### 5. Content & Copy
- [ ] Labels are clear and concise
- [ ] No jargon, abbreviations, or internal terminology
- [ ] Error messages explain what went wrong AND what to do
- [ ] Placeholder text is helpful (not "Enter text here")
- [ ] Microcopy guides the user (tooltips, helper text)
- [ ] Dates, numbers, currencies are formatted for locale

### 6. Visual Design
- [ ] Color palette is consistent (no random one-off colors)
- [ ] Typography hierarchy is clear (H1 > H2 > body > caption)
- [ ] Spacing is consistent (same gaps between similar elements)
- [ ] Icons are consistent style (not mixing outline and filled)
- [ ] Images/illustrations serve a purpose (not decorative filler)
- [ ] Contrast ratios are sufficient for readability

### 7. Mobile Experience
- [ ] Not just a squeezed desktop (actually optimized for mobile)
- [ ] Touch targets are at least 44x44px
- [ ] No horizontal scrolling
- [ ] Important actions are thumb-reachable (bottom of screen)
- [ ] Modals and dropdowns work on small screens
- [ ] Keyboard doesn't obscure the active input
- [ ] Text is readable without zooming (min 14px body)

### 8. Edge Cases & Error States
- [ ] Empty states (no data yet)
- [ ] Error states (API failure, network down)
- [ ] Loading states (skeleton, spinner, progress)
- [ ] Long content (overflow, truncation, pagination)
- [ ] Many items (performance, scroll, lazy loading)
- [ ] No items (clear message, not blank)
- [ ] Offline behavior (graceful degradation)

### 9. Accessibility Basics
- [ ] Sufficient color contrast (4.5:1 for text, 3:1 for large text)
- [ ] Focus indicators visible for keyboard navigation
- [ ] Images have alt text
- [ ] Form inputs have labels (not just placeholders)
- [ ] Heading hierarchy is logical (no skipped levels)
- [ ] Interactive elements are keyboard-accessible

### 10. Performance Perception
- [ ] Above-the-fold content loads fast
- [ ] Skeleton screens or loading indicators for slow content
- [ ] No layout shifts after page load
- [ ] Large images are lazy-loaded
- [ ] Animations are smooth (no janky transitions)

## Cross-Screen Analysis

After evaluating individual screens, assess the app holistically:

### Consistency
- [ ] Same component looks and behaves the same everywhere
- [ ] Color usage is semantically consistent (green = success, red = error)
- [ ] Spacing system is consistent (not ad-hoc per page)
- [ ] Button styles are consistent (primary, secondary, ghost)

### User Flow
- [ ] Core user journey can be completed without confusion
- [ ] No dead ends (every page has a next step or escape)
- [ ] Onboarding/first-use experience is smooth
- [ ] Error recovery is possible (can undo, can retry)

### Missing States
- [ ] What screens would a real user expect that don't exist?
- [ ] What happens at each decision point if the user says "no"?
- [ ] Are confirmation and success screens present?
- [ ] Does the app handle the user coming back after a week?

## Scoring

Rate the overall UX on these dimensions:

| Dimension | Weight | Score (1-10) |
|-----------|--------|-------------|
| Clarity | 25% | Can users understand what to do? |
| Efficiency | 20% | Can users complete tasks quickly? |
| Consistency | 15% | Same patterns used everywhere? |
| Error handling | 15% | Does the app help when things go wrong? |
| Mobile | 15% | Fully usable on phones? |
| Delight | 10% | Any moments of "oh, nice"? |

**Overall = weighted average. List flaws before scoring.**
