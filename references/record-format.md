# Customization record format

One markdown file per intent:

`~/.config/omarchy/plugin-maleability/<plugin-id>/<slug>.md`

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
  version: 0.3.0
  tree: a1b2c3d4e5f67890
  source: ""
files:
  - Service.qml
  - Panel.qml
---
```

`enabled: false` keeps the record after **Reset to upstream** or **Update
(upstream only)**. Missing `enabled` is treated as true. Bootstrap drafts
are written `enabled: false`. Set `enabled: true` only after **Verify live**.

`applied.commit` is git HEAD, or `cloned` for `omarchy plugin clone` checkouts.
`applied.version` is that checkout’s `manifest.json` `version` at apply time —
a tag on the Prior art map, not a staleness signal (commit / source already
do that). `applied.tree` is a 16-char hash of the recorded files’ contents at
apply time. Further edits to those files become status `drift`. `applied.source`
is a 16-char fingerprint of the first-party catalog tree (clones only). When
that fingerprint moves, the record is `stale` and the plugin is `behind`.

The scanner backfills missing `tree` / `source` on scan without marking
stale or drift. It does not invent `version` for old records; the next apply
writes it.

`bootstrapped: true` plus a Goal that still says "Draft — refine" is status
`draft`, even when `enabled` is false. Deleting a draft removes only the
markdown.

Required sections: **Goal**, **Why / decisions**, **Where to look**, **Prior art**,
**Re-apply notes**. The scanner also accepts `## Why` as an alias for
**Why / decisions**.

**Prior art** is the implementation map for the *next* re-apply. After every
successful Customize, Record, or Re-apply, rewrite it from the work you just
did — do not leave a first-draft guess or a bootstrap diff. Include:

- The files you actually touched (`files:` in frontmatter must match)
- The symbols / strings / functions that carry the Goal
- A small before → after of each change (unique enough to find after an
  upstream rename; not a full-file dump and not a patch to apply blindly)
- What you deliberately did **not** change
- The plugin `applied.version` and `applied.commit` (or `cloned`) this map
  was captured against. Open Prior art with that tag, e.g.
  `Captured against version 0.3.0 (`c6e6633`).`

The next agent should be able to re-implement the Goal from Goal + Where to
look + this section without rediscovering the design. If upstream moved the
code, follow the Goal, then replace this section with the new map.

**Re-apply notes** are how to tell the Goal holds on the *running* plugin
(bar or panel, IPC if any, idle/empty state) — not which source string to grep,
and not a second copy of Prior art.
