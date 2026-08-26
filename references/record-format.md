# Customization record format

One markdown file per intent:

`~/.config/omarchy/plugin-customizations/<plugin-id>/<slug>.md`

Not a patch. After an upstream refactor the agent re-implements the **Goal**
using **Where to look** and **Prior art** as a map.

```yaml
---
id: bar-icon-unread-only
plugin: robzolkos.github
title: Bar icon only for unread notifications
bootstrapped: false
applied:
  commit: c6e6633
  at: 2026-08-26T14:00:00Z
files:
  - Service.qml
  - Panel.qml
---
```

`bootstrapped: true` plus a Goal that still says "Draft — refine" is status
`draft`. Upgrade those before the next update.

Required sections:

- **Goal** — what the user should observe
- **Why / decisions** — rejected alternatives
- **Where to look** — symbols and call chain
- **Prior art** — before/after from the revision it was last applied to
- **Re-apply notes** — how to tell it already holds; tests to run

Worked example: the GitHub unread-only icon, once upgraded from the install
bootstrap, in `~/.config/omarchy/plugin-customizations/robzolkos.github/`.
