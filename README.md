# Plugin Maleability

An Omarchy bar widget plus an agent skill that keep local tweaks to other
shell plugins after those plugins update — a play on the malleable computer.

Third-party plugins are git checkouts. `omarchy plugin update` fast-forwards
them and will not keep uncommitted edits. This plugin records **why** you
changed something — goal, decisions, symbols, a worked example — outside those
checkouts, lights the bar when an update would wipe the work, and re-applies
it through whatever agent `omarchy default agent` selected.

## Install

```bash
omarchy plugin add https://github.com/djschnei21/omarchy-plugin-maleability.git --enable
```

On first load the widget:

- links this tree into each Omarchy agent skill directory
- scans installed plugins for existing local diffs and writes draft records
- sits in the right section of the bar (move it with `omarchy bar move`)

The home list is every local plugin. Open one to see its records.

- **Reset to upstream** restores stock code and marks records unapplied (they stay).
- **Re-apply** resets, then asks your default agent to put each record back.
- **Customize** is a text box: describe a change and an agent implements and records it.
- **Update** (when origin is ahead) is upstream-only or upstream-then-re-apply.

Per-record **Re-apply** / **Refine** still run on that item only.

## Remove

Stock `omarchy plugin remove` only deletes the checkout. Use this instead:

```bash
~/.config/omarchy/plugins/djschnei21.plugin-maleability/scripts/uninstall
```

That removes skill links, the intent store at
`~/.config/omarchy/plugin-maleability/`, and the plugin itself. The panel's
Uninstall button runs the same script.

## Requirements

- Omarchy Quattro with shell plugins
- `python3`, `git`, `diff`, `jq` (Omarchy already has these)
- A default coding agent (`omarchy default agent`)

## License

MIT
