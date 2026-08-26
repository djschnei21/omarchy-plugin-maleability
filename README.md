# Plugin Maleability

An Omarchy bar widget plus an agent skill that keep local tweaks to other
shell plugins after those plugins update — a play on the malleable computer.

Third-party plugins are git checkouts. `omarchy plugin update` fast-forwards
them and will not keep uncommitted edits. This plugin records **why** you
changed something — goal, decisions, symbols, a worked example — outside those
checkouts, lights the bar when an update would wipe the work, and re-applies
it through whatever agent `omarchy default agent` selected.

It runs inside the long-running `omarchy-shell` process. It does not start a
second Quickshell instance.

## Install

```sh
omarchy plugin add https://github.com/djschnei21/omarchy-plugin-maleability.git --enable
```

On first load the widget:

- links this tree into each Omarchy agent skill directory under `$HOME`
- scans installed plugins for existing local diffs and writes draft records
- sits in the right section of the bar

The home list is every local plugin. Open one to see its records.

- **Reset to upstream** restores stock code and marks records unapplied (they stay).
- **Re-apply** resets, then asks your default agent to put each record back.
- **Customize** is a text box: describe a change and an agent implements and records it.
- **Update** (when origin is ahead) is upstream-only or upstream-then-re-apply.

Per-record **Re-apply** / **Refine** still run on that item only.

## Usage

Click the bar icon to open or close the panel. Press Escape to go back a page,
then to close. Right-click or middle-click the icon to refresh. `r` refreshes
while the panel is open.

## Configure

```sh
omarchy bar move djschnei21.plugin-maleability --section right
```

## Remove

```sh
omarchy plugin remove djschnei21.plugin-maleability
```

Records at `~/.config/omarchy/plugin-maleability/` stay, so a later reinstall
can still re-apply them. Skill symlinks under `$HOME` will point at a removed
tree; drop them if you are not reinstalling:

```sh
rm -f ~/.agents/skills/plugin-maleability \
      ~/.claude/skills/plugin-maleability \
      ~/.codex/skills/plugin-maleability \
      ~/.pi/agent/skills/plugin-maleability \
      ~/.grok/skills/plugin-maleability
```

## Requirements

- Omarchy Quattro with shell plugins
- `python3`, `git`, `diff`, `jq` (Omarchy already has these)
- A default coding agent (`omarchy default agent`)

## Privilege boundary

This plugin is unsandboxed, like every Omarchy plugin. It does not ask for
`sudo` or `pkexec`.

- `scripts/install` writes skill symlinks under `$HOME` and bootstraps records
  under `~/.config/omarchy/plugin-maleability/`.
- The bar widget runs `python3 status` in the shell process and launches the
  default agent with `omarchy-agent-prompt`.
- Removal is `omarchy plugin remove`. It does not delete records.

## Development

```sh
PLUGIN_DIR="$HOME/.config/omarchy/plugins/djschnei21.plugin-maleability"
omarchy plugin validate "$PLUGIN_DIR"
qmllint -I "$OMARCHY_PATH/shell" \
  "$PLUGIN_DIR/BarWidget.qml" "$PLUGIN_DIR/Panel.qml"
```

The details panel is part of this `bar-widget`. `BarWidget.qml` is the
manifest entry; it loads `Panel.qml`. There is no separate `panel` kind.

## License

MIT
