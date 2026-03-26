# Wireframe Screen Inventory (Template)

Template for documenting screens defined in your wireframe HTML.
Copy this file and fill in your app's screens.

## Screen IDs

| ID | Description | Viewports |
|----|-------------|-----------|
| home | Home / landing page | desktop, mobile |
| dashboard | Main dashboard | desktop, mobile |
| settings | Settings page | desktop, mobile |
| profile | User profile | desktop, mobile |
| auth-login | Login form | desktop, mobile |
| auth-signup | Signup form | desktop, mobile |

## Audit Priority

### P0 - Core screens (audit every time)
- home (desktop + mobile)
- dashboard (desktop + mobile)

### P1 - Important states
- settings (desktop + mobile)
- profile (desktop + mobile)
- auth-login, auth-signup

### P2 - Secondary
- Error pages, modals, toasts, empty states

## Component-to-Selector Mapping

Map your wireframe's CSS classes to what you need to extract.

**Example:**
| Wireframe Class | What It Is |
|----------------|------------|
| `.nav-sidebar` | Side navigation |
| `.nav-item.active` | Active nav item |
| `.header` | Top header bar |
| `.card` | Content card |
| `.btn-primary` | Primary action button |
| `.input-field` | Form input |
| `.modal` | Modal dialog |

Customize this mapping for your wireframe, then pass it to `extract_wireframe_specs.py --selectors`.
