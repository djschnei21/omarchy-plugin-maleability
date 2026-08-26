# Plugin Malleability

An Omarchy bar widget plus an agent skill that keep local tweaks to other
shell plugins after those plugins update — a play on the malleable computer.

Third-party plugins are git checkouts. `omarchy plugin update` fast-forwards
them and will not keep uncommitted edits — on a dirty tree it refuses. This
plugin records **why** you changed something — goal, decisions, symbols, a
worked example — outside those checkouts, lights the bar when an update would
wipe the work, and re-applies it through whatever agent `omarchy default agent`
selected.

Cloned built-ins (`omarchy plugin clone`) have no git origin. Malleability
fingerprints the first-party catalog source and treats a moved source the
same way: stale, with Update / Re-apply.

It runs inside the long-running `omarchy-shell` process. The scanner is a
`service` singleton; the bar icon is the `bar-widget`. It does not start a
second Quickshell instance.

## Install

```sh
omarchy plugin add https://github.com/djschnei21/omarchy-plugin-malleability.git --enable
```

The plugin id, skill, records path, and GitHub repo are **malleability** (two L’s).
Older releases used the misspelling *maleability*. GitHub redirects the old
repo URL. `scripts/install` moves skill links, records, and a leftover
checkout directory, and rewrites the bar widget id in `shell.json`.

On first load the widget:

- links `SKILL.md` and `references/` into each Omarchy agent skill directory under `$HOME`
- scans installed plugins for existing local diffs and writes draft records
- sits in the right section of the bar

The home list is every local plugin (attention-first). Open one to see its records.

- **Reset to upstream** restores stock code and marks records unapplied (they stay).
- **Re-apply** resets, then asks your default agent to put each record back.
- **Customize** is a text box: describe a change and an agent implements and records it.
- **Update** (when origin is ahead, or a clone’s first-party source moved) is upstream-only or upstream-then-re-apply. This is a hard reset to upstream, not `omarchy plugin update`’s fast-forward.

Per-record **Re-apply** / **Refine** / **Record** still run on that item only.

## Usage

Click the bar icon to open or close the panel. Press Escape to go back a page,
then to close. Right-click or middle-click the icon to refresh. `r` refreshes
while the panel is open.

## Configure

```sh
omarchy bar move djschnei21.plugin-malleability --section right
```

## Remove

```sh
omarchy plugin remove djschnei21.plugin-malleability
```

Records at `~/.config/omarchy/plugin-malleability/` stay, so a later reinstall
can still re-apply them. Skill links under `$HOME` will point at a removed
tree; drop them if you are not reinstalling:

```sh
rm -rf ~/.agents/skills/plugin-malleability \
      ~/.claude/skills/plugin-malleability \
      ~/.codex/skills/plugin-malleability \
      ~/.pi/agent/skills/plugin-malleability \
      ~/.grok/skills/plugin-malleability
```

## Requirements

- Omarchy Quattro with shell plugins
- `python3`, `git`, `diff` (Omarchy already has these)
- A default coding agent (`omarchy default agent`)

## Privilege boundary

This plugin is unsandboxed, like every Omarchy plugin. It does not ask for
`sudo` or `pkexec`.

- `scripts/install` writes skill links under `$HOME` and bootstraps records
  under `~/.config/omarchy/plugin-malleability/`.
- The service runs `python3 status` in the shell process and launches the
  default agent with `omarchy-agent-prompt`.
- Removal is `omarchy plugin remove`. It does not delete records.

## Development

```sh
PLUGIN_DIR="$HOME/.config/omarchy/plugins/djschnei21.plugin-malleability"
bash "$PLUGIN_DIR/tests/status-test.sh"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" \
  "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml" "$PLUGIN_DIR/Service.qml"
```

The details panel is part of this `bar-widget`. `BarWidget.qml` is the
manifest bar entry; `Service.qml` is the singleton scanner. There is no
separate `panel` kind.

## License

MIT
