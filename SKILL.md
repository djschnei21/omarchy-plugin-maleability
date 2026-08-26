---
name: plugin-customizations
description: >
  Record and re-apply local customizations to Omarchy shell plugins after
  those plugins update. Use when the user customizes a third-party or cloned
  plugin, when a plugin was updated and tweaks disappeared, when the plugin
  customizations bar icon is lit, or when they say re-apply plugin
  customizations. Triggers: customize this plugin, plugin updated, re-apply
  customizations, unread-only icon, plugin drift.
---

# Plugin customizations

Treat `~/.config/omarchy/plugins/<id>/` as disposable. Intent lives in
`~/.config/omarchy/plugin-customizations/<id>/<slug>.md`. Never commit into a
third-party plugin repo. Never edit `/usr/share/omarchy/`.

Skip this plugin itself (`djschnei21.plugin-customizations`).

Scanner (run this first on every invocation):

```bash
python3 ~/.config/omarchy/plugins/djschnei21.plugin-customizations/status
```

`--bootstrap` writes draft records for unrecorded diffs. `--fetch` updates remotes.

Record format: `references/record-format.md`.

## Record (after a customization)

1. Identify the plugin id from the path.
2. `git diff HEAD` in that checkout (or clone-vs-source for `omarchy.clonedFrom`).
3. Write or update the markdown record: Goal, Why, Where to look, Prior art
   (current hunks as an *example*), Re-apply notes. Set `applied.commit` to
   current `HEAD`. Set `bootstrapped: false` once Goal/Why are real.
4. Do not commit the plugin repo.
5. Re-run `status` and confirm the record is `applied`.

If `status` reports `draft` records, upgrade them before anything else: fill
Goal/Why/Where-to-look from the captured prior art and the working tree.

## Re-apply (plugin updated, icon lit, or user asked)

1. Run `status`. Handle every `stale`, `unrecorded`, and `draft` plugin, not
   only the one named.
2. `unrecorded` diffs: **Record** them first. Never reset a dirty tree with no
   covering record.
3. If `behind` (origin has new commits): `git fetch`, then
   `git reset --hard FETCH_HEAD` on the *target* plugin only after records
   cover its dirty paths.
4. For each record, read the new tree and re-implement the **Goal**. Use prior
   art as a map, not as a patch. If the old symbol is gone, find the new one
   that drives the same UX.
5. Run that plugin's tests if present.
6. Update `applied.commit`, `files`, and prior-art excerpts.
7. If upstream removed the feature, keep the record and say so. Do not delete it.

## Customize (user wants a new tweak)

Follow the Omarchy skill for safe edit locations. After the code change, always
**Record**.
