---
name: plugin-maleability
description: >
  Companion skill for the Plugin Maleability Omarchy bar widget. That widget
  launches the user's default agent with prompts that name this skill
  (Customize, Refine, Re-apply, and the rest of its buttons). Users also
  invoke it themselves when they want Maleability to record, refine, re-apply,
  reset, update, or delete a local Omarchy shell-plugin customization. Use
  whenever Plugin Maleability is in play, including /plugin-maleability.
  Do not use for writing a new plugin from scratch.
---

# Plugin Maleability

Treat `~/.config/omarchy/plugins/<id>/` as disposable. Intent lives in
`~/.config/omarchy/plugin-maleability/<id>/<slug>.md`. Never commit into a
third-party plugin repo. Never edit `/usr/share/omarchy/`.

Skip this plugin itself (`djschnei21.plugin-maleability`).

Scanner:

```bash
python3 ~/.config/omarchy/plugins/djschnei21.plugin-maleability/status
```

`--bootstrap` writes draft records. `--fetch` updates remotes.
`--reset PLUGIN_ID` restores that checkout and sets every record `enabled: false`.
`--update PLUGIN_ID` fetches origin, hard-resets to it, then `enabled: false`.
Do **not** run git reset yourself when the prompt says the plugin is already reset.

Record format: `references/record-format.md`. Frontmatter `enabled: true|false`
(missing means true). Set `enabled: true` only after **Verify live**.

## Scope

The panel names a plugin id and sometimes a customization id. Work only that
scope. Do not walk every plugin unless asked to re-apply all.

## Verify live

Source edits and plugin tests are not enough. The **Goal** is user-visible
behavior on the running plugin. Before `enabled: true`:

1. Make sure the live plugin is serving this checkout (`omarchy-shell shell
   rescanPlugins`, or `omarchy restart shell` if a reload looks stale).
2. Observe the Goal the way a user would: bar chrome, the plugin panel,
   `omarchy-shell <plugin-id> …` if it exposes state. Use **Re-apply notes**
   when they say how to tell it holds; otherwise derive checks from the Goal.
3. Confirm both sides you can see: the condition that should change, and the
   condition that should not (empty, idle, off).
4. If you cannot observe it, say so and leave `enabled: false` until the user
   confirms or you find an observable. Do not treat a matching source string
   as success.

## Customize (user described a change)

1. Implement the request in `~/.config/omarchy/plugins/<id>/`.
2. Write the record (Goal, Why, Where to look, Prior art, `bootstrapped: false`).
3. **Verify live**, then set `enabled: true` and `applied.commit` to HEAD.
4. Do not commit the plugin repo.

## Record (after a manual tweak)

Same as Customize, from `git diff HEAD` (or clone-vs-source).

If `status` reports `draft`, fill Goal/Why/Where-to-look and set
`bootstrapped: false`. Docs-only refine does not need Verify live unless you
also changed plugin source.

## Re-apply one customization

1. Run `status`. Find that plugin/id.
2. Do not reset the whole plugin (other customizations may be applied).
3. Re-implement that record's **Goal** on the current tree. Prior art is a map,
   not a patch.
4. Run the plugin's tests if present.
5. **Verify live**, then set `enabled: true` and update `applied.commit` /
   files / prior art.
6. If upstream removed the feature, leave the record, set `enabled: false`, say so.

## Re-apply a plugin (after helper reset)

The checkout is already stock. For each record on that plugin except drafts
with a placeholder Goal, re-apply one by one as above.

## Reset / update

The widget helper does this. Do not delete records. `enabled: false` means
unapplied, not gone.

## Delete

The panel **Delete** button runs `status --delete PLUGIN_ID CUSTOMIZATION_ID`.

- Unapplied: only the markdown is removed.
- Enabled: the markdown is removed, the plugin checkout is reset to **current
  HEAD** (not a fetch), remaining records are marked `enabled: false`, then
  the agent is asked to re-apply the records that were still enabled, one by
  one. Do not git reset again. Do not re-apply the deleted id.

Overlapping file edits are why we do not restore one record's files in place.
