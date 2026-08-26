---
name: plugin-customizations
description: >
  Record and re-apply local customizations to Omarchy shell plugins after
  those plugins update. Use when the user customizes a third-party or cloned
  plugin, when a plugin was updated and tweaks disappeared, when the plugin
  customizations bar icon is lit, or when they say re-apply plugin
  customizations. Triggers: customize this plugin, plugin updated, re-apply
  customizations, unread-only icon, plugin drift, reset to upstream.
---

# Plugin customizations

Treat `~/.config/omarchy/plugins/<id>/` as disposable. Intent lives in
`~/.config/omarchy/plugin-customizations/<id>/<slug>.md`. Never commit into a
third-party plugin repo. Never edit `/usr/share/omarchy/`.

Skip this plugin itself (`djschnei21.plugin-customizations`).

Scanner:

```bash
python3 ~/.config/omarchy/plugins/djschnei21.plugin-customizations/status
```

`--bootstrap` writes draft records. `--fetch` updates remotes.
`--reset PLUGIN_ID` restores that checkout and sets every record `enabled: false`.
`--update PLUGIN_ID` fetches origin, hard-resets to it, then `enabled: false`.
Do **not** run git reset yourself when the prompt says the plugin is already reset.

Record format: `references/record-format.md`. Frontmatter `enabled: true|false`
(missing means true). After a successful apply set `enabled: true` and
`applied.commit` to current HEAD.

## Scope

The panel names a plugin id and sometimes a customization id. Work only that
scope. Do not walk every plugin unless asked to re-apply all.

## Customize (user described a change)

1. Implement the request in `~/.config/omarchy/plugins/<id>/`.
2. Write a new record with Goal, Why, Where to look, Prior art, `enabled: true`,
   `bootstrapped: false`, `applied.commit` = HEAD.
3. Do not commit the plugin repo.

## Record (after a manual tweak)

Same as Customize, from `git diff HEAD` (or clone-vs-source).

If `status` reports `draft`, fill Goal/Why/Where-to-look and set
`bootstrapped: false`.

## Re-apply one customization

1. Run `status`. Find that plugin/id.
2. Do not reset the whole plugin (other customizations may be applied).
3. Re-implement that record's **Goal** on the current tree. Prior art is a map,
   not a patch.
4. Run the plugin's tests if present.
5. Set `enabled: true`, update `applied.commit` / files / prior art.
6. If upstream removed the feature, leave the record, set `enabled: false`, say so.

## Re-apply a plugin (after helper reset)

The checkout is already stock. For each record on that plugin except drafts
with a placeholder Goal, re-apply one by one as above.

## Reset / update

The widget helper does this. Do not delete records. `enabled: false` means
unapplied, not gone.
