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
enabled: true
applied:
  commit: c6e6633
  at: 2026-08-26T14:00:00Z
files:
  - Service.qml
  - Panel.qml
---
```

`enabled: false` keeps the record after **Reset to upstream** or **Update
(upstream only)**. Missing `enabled` is treated as true.

`bootstrapped: true` plus a Goal that still says "Draft — refine" is status
`draft`.

Required sections: **Goal**, **Why / decisions**, **Where to look**, **Prior art**,
**Re-apply notes**.
