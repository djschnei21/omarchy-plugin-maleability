#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
STATUS="$ROOT/status"

fail() { echo "FAIL: $*" >&2; exit 1; }
assert_jq() { jq -e "$1" <<<"$2" >/dev/null || fail "$3"$'\n'"$2"; }
has() { jq -e "$1" <<<"$2" >/dev/null; }

sandbox=$(mktemp -d)
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox"
mkdir -p "$HOME/.config/omarchy/plugins" "$HOME/.config/omarchy/plugin-maleability" "$sandbox/bin" "$sandbox/catalog/omarchy.clock"

ln -s "$(command -v jq)" "$sandbox/bin/jq"
ln -s "$(command -v git)" "$sandbox/bin/git"
ln -s "$(command -v diff)" "$sandbox/bin/diff"
ln -s "$(command -v bash)" "$sandbox/bin/bash"
ln -s "$(command -v python3)" "$sandbox/bin/python3"

cat >"$sandbox/bin/omarchy-plugin-catalog" <<'CAT'
#!/usr/bin/env bash
cat "$HOME/.catalog.json"
CAT
chmod +x "$sandbox/bin/omarchy-plugin-catalog"

cat >"$sandbox/bin/omarchy-notification-send" <<'N'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HOME/notify.log"
N
chmod +x "$sandbox/bin/omarchy-notification-send"

cat >"$sandbox/bin/omarchy-plugin-validate" <<'V'
#!/usr/bin/env bash
exit 0
V
chmod +x "$sandbox/bin/omarchy-plugin-validate"

export PATH="$sandbox/bin:$PATH"

write_record() {
  local plugin=$1 id=$2
  shift 2
  mkdir -p "$HOME/.config/omarchy/plugin-maleability/$plugin"
  cat >"$HOME/.config/omarchy/plugin-maleability/$plugin/$id.md"
}

git_plugin() {
  local id=$1
  local dir="$HOME/.config/omarchy/plugins/$id"
  mkdir -p "$dir"
  git -C "$dir" init -q
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  printf '%s\n' "{\"schemaVersion\":1,\"id\":\"$id\",\"name\":\"$id\",\"version\":\"1.0.0\",\"kinds\":[\"bar-widget\"],\"entryPoints\":{\"barWidget\":\"Panel.qml\"}}" >"$dir/manifest.json"
  echo "stock" >"$dir/Panel.qml"
  git -C "$dir" add -A
  git -C "$dir" commit -qm stock
  git -C "$dir" remote add origin "$dir"
  git -C "$dir" update-ref refs/remotes/origin/master HEAD 2>/dev/null || git -C "$dir" update-ref refs/remotes/origin/main HEAD
}

export STATUS
python3 - <<'PY'
from importlib.machinery import SourceFileLoader
from pathlib import Path
import os
status_path = Path(os.environ["STATUS"])
mod = SourceFileLoader("statusmod", str(status_path)).load_module()

# Frontmatter: nested applied, files, title with colon
text = """---
id: foo
plugin: bar
title: Hello: world
enabled: true
applied:
  commit: abcdef1
  at: t
  tree: 111
  source: 222
files:
  - Service.qml
  - Panel.qml
---

# Hello

## Goal

Do the thing.

## Why

Because.

## Where to look

- x
"""
fm, body = mod.parse_frontmatter(text)
assert fm["title"] == "Hello: world", fm
assert fm["applied"]["commit"] == "abcdef1"
assert fm["files"] == ["Service.qml", "Panel.qml"]
assert mod.extract_section(body, "Goal") == "Do the thing."
assert mod.extract_why(body) == "Because."
assert mod.extract_section(body, "Why / decisions") == ""
print("frontmatter ok")

# Status matrix
rec = {"bootstrapped": True, "draftGoal": True, "enabled": False, "appliedCommit": "abc", "appliedTree": "", "appliedSource": "", "files": []}
assert mod.customization_status(rec, "abc") == "draft"
rec = {"bootstrapped": False, "draftGoal": False, "enabled": False, "appliedCommit": "abc", "appliedTree": "t", "appliedSource": "", "files": ["A"]}
assert mod.customization_status(rec, "abc") == "unapplied"
rec = {"bootstrapped": False, "draftGoal": False, "enabled": True, "appliedCommit": "oldsha", "appliedTree": "t", "appliedSource": "", "files": ["A"]}
assert mod.customization_status(rec, "newsha") == "stale"
rec = {"bootstrapped": False, "draftGoal": False, "enabled": True, "appliedCommit": "cloned", "appliedTree": "t", "appliedSource": "aaa", "files": ["A"]}
assert mod.customization_status(rec, "cloned", source_fp="bbb", current_tree="t") == "stale"
rec = {"bootstrapped": False, "draftGoal": False, "enabled": True, "appliedCommit": "abc", "appliedTree": "oldtree", "appliedSource": "", "files": ["A"]}
assert mod.customization_status(rec, "abc", current_tree="newtree") == "drift"
rec = {"bootstrapped": False, "draftGoal": False, "enabled": True, "appliedCommit": "abc", "appliedTree": "t", "appliedSource": "", "files": ["A"]}
assert mod.customization_status(rec, "abc", current_tree="t") == "applied"
print("status matrix ok")
PY

# --- CLI: git plugin bootstrap ---
git_plugin acme.one
echo "local" >"$HOME/.config/omarchy/plugins/acme.one/Panel.qml"
echo "brand-new" >"$HOME/.config/omarchy/plugins/acme.one/notes.txt"
printf '%s\n' '[]' >"$HOME/.catalog.json"

out=$(python3 "$STATUS" --bootstrap)
assert_jq '.ok == true' "$out" "bootstrap ok"
assert_jq '.counts.draft == 1' "$out" "bootstrap creates a draft"
assert_jq '.counts.unapplied == 0' "$out" "draft is not counted as unapplied"
assert_jq '.attention == true' "$out" "draft lights attention"
rec_file=$(jq -r '.plugins[0].customizations[0].path' <<<"$out")
[[ -f $rec_file ]] || fail "record missing"
grep -q '^enabled: false' "$rec_file" || fail "bootstrap draft must be enabled: false"
grep -q '^  tree: ' "$rec_file" || fail "bootstrap must write applied.tree"
grep -q '^  version: 1.0.0' "$rec_file" || fail "bootstrap must write applied.version from the plugin manifest"
assert_jq '.plugins[0].customizations[0].appliedVersion == "1.0.0"' "$out" "scan exposes appliedVersion"
assert_jq '.plugins[0].version == "1.0.0"' "$out" "scan exposes plugin version"
grep -q 'brand-new' "$rec_file" || fail "untracked file body must be in prior art"
grep -q 'Draft — refine' "$rec_file" || fail "draft goal"

# unapplied does not light attention
python3 "$STATUS" --reset acme.one >/dev/null
# reset of a draft-only plugin: draft still draft (placeholder), checkout stock
out=$(python3 "$STATUS")
# After reset, draft still exists with enabled false but still draft status
assert_jq '.counts.draft == 1' "$out" "placeholder draft stays draft after reset"
assert_jq '.attention == true' "$out" "draft still lights attention"

# --- Delete draft is unlink-only (checkout stays) ---
echo "keep-me" >"$HOME/.config/omarchy/plugins/acme.one/extra-untracked.txt"
cid=$(jq -r '.plugins[0].customizations[0].id' <<<"$out")
out=$(python3 "$STATUS" --delete acme.one "$cid")
assert_jq '.ok == true' "$out" "delete draft ok"
[[ ! -f $rec_file ]] || fail "draft markdown should be gone"
[[ -f $HOME/.config/omarchy/plugins/acme.one/extra-untracked.txt ]] || fail "delete draft must not git-clean"
assert_jq '.plugins[0].customizations | length == 0' "$out" "no records left"

# --- Enabled delete: reset then unlink, keep record on reset failure ---
git_plugin acme.two
echo "tweaked" >"$HOME/.config/omarchy/plugins/acme.two/Panel.qml"
write_record acme.two keep-me <<'MD'
---
id: keep-me
plugin: acme.two
title: Keep
bootstrapped: false
enabled: true
applied:
  commit: HEADPLACE
  at: t
files:
  - Panel.qml
---

# Keep

## Goal

Real goal.

## Why / decisions

Because.

## Where to look

- Panel.qml

## Prior art

x

## Re-apply notes

y
MD
# put the real HEAD into applied.commit so it is applied, not stale
head=$(git -C "$HOME/.config/omarchy/plugins/acme.two" rev-parse HEAD)
sed -i "s/HEADPLACE/${head}/" "$HOME/.config/omarchy/plugin-maleability/acme.two/keep-me.md"

out=$(python3 "$STATUS")
assert_jq '.plugins[] | select(.id=="acme.two") | .customizations[0].status == "applied"' "$out" "applied after backfill"

# missing plugin id on delete of enabled should fail and keep file — use a fake plugin id
# (record lives under acme.two; deleting with unknown plugin)
out=$(python3 "$STATUS" --delete missing.plugin keep-me 2>/dev/null) || true
assert_jq '.ok == false' "$out" "delete unknown plugin fails"
[[ -f $HOME/.config/omarchy/plugin-maleability/acme.two/keep-me.md ]] || fail "record must survive failed delete"

# enabled delete on acme.two resets checkout and removes markdown
echo "tweaked" >"$HOME/.config/omarchy/plugins/acme.two/Panel.qml"
out=$(python3 "$STATUS" --delete acme.two keep-me)
assert_jq '.ok == true' "$out" "enabled delete ok"
[[ ! -f $HOME/.config/omarchy/plugin-maleability/acme.two/keep-me.md ]] || fail "enabled delete removes markdown"
grep -q stock "$HOME/.config/omarchy/plugins/acme.two/Panel.qml" || fail "enabled delete resets checkout"

# --- Error JSON has no plugins ---
out=$(python3 "$STATUS" --reset does.not.exist 2>/dev/null) || true
assert_jq '.ok == false' "$out" "missing plugin error"
has '.plugins' "$out" && fail "error payload must not include plugins" || true
assert_jq '.error != null' "$out" "error string present"

# --- Clone fingerprint stale + untracked new file in clone ---
mkdir -p "$sandbox/catalog/omarchy.clock"
echo "clock-src" >"$sandbox/catalog/omarchy.clock/Panel.qml"
echo '{"schemaVersion":1,"id":"omarchy.clock","name":"Clock","version":"1","kinds":["bar-widget"],"entryPoints":{"barWidget":"Panel.qml"}}' >"$sandbox/catalog/omarchy.clock/manifest.json"
mkdir -p "$HOME/.config/omarchy/plugins/user.clock"
echo "clock-src" >"$HOME/.config/omarchy/plugins/user.clock/Panel.qml"
echo '{"schemaVersion":1,"id":"user.clock","name":"Clock","version":"1","kinds":["bar-widget"],"entryPoints":{"barWidget":"Panel.qml"},"omarchy":{"clonedFrom":"omarchy.clock"}}' >"$HOME/.config/omarchy/plugins/user.clock/manifest.json"
echo "added" >"$HOME/.config/omarchy/plugins/user.clock/extra.qml"
# catalog maps omarchy.clock to source
python3 - <<PY
import json, os
from pathlib import Path
Path(os.environ["HOME"], ".catalog.json").write_text(json.dumps([
  {"id": "omarchy.clock", "sourceDir": str(Path(os.environ["HOME"]).parent / "catalog/omarchy.clock") if False else "$sandbox/catalog/omarchy.clock"}
]))
PY
printf '%s\n' "[{\"id\":\"omarchy.clock\",\"sourceDir\":\"$sandbox/catalog/omarchy.clock\"}]" >"$HOME/.catalog.json"

out=$(python3 "$STATUS" --bootstrap)
assert_jq '.ok == true' "$out" "clone bootstrap ok"
# extra.qml is unrecorded new file → draft
assert_jq '[.plugins[] | select(.id=="user.clock") | .customizations[].status] | index("draft") != null' "$out" "clone extra file is draft"
clone_rec=$(jq -r '.plugins[] | select(.id=="user.clock") | .customizations[0].path' <<<"$out")
grep -q '^enabled: false' "$clone_rec" || fail "clone draft enabled false"
grep -q '^  source: ' "$clone_rec" || fail "clone draft has applied.source"
grep -q 'added' "$clone_rec" || fail "new clone file body in prior art"

# Fill draft into a real enabled record to test clone stale
python3 - <<PY
from pathlib import Path
import os, re
p = Path("$clone_rec")
text = p.read_text()
text = text.replace("enabled: false", "enabled: true")
text = text.replace("bootstrapped: true", "bootstrapped: false")
text = text.replace("Draft — refine with the plugin-maleability skill.", "Keep extra.qml.")
p.write_text(text)
PY
out=$(python3 "$STATUS")
assert_jq '[.plugins[] | select(.id=="user.clock") | .customizations[].status] | index("applied") != null' "$out" "clone record applied"

# Change first-party source → stale + behind
echo "clock-src-v2" >"$sandbox/catalog/omarchy.clock/Panel.qml"
out=$(python3 "$STATUS")
assert_jq '[.plugins[] | select(.id=="user.clock") | .customizations[].status] | index("stale") != null' "$out" "clone source change is stale"
assert_jq '.plugins[] | select(.id=="user.clock") | .behind == true' "$out" "clone behind"
assert_jq '.counts.stale >= 1' "$out" "stale counted"
assert_jq '.attention == true' "$out" "stale lights attention"

# --- Drift: change recorded file after tree snapshot ---
git_plugin acme.three
head3=$(git -C "$HOME/.config/omarchy/plugins/acme.three" rev-parse HEAD)
echo "custom" >"$HOME/.config/omarchy/plugins/acme.three/Panel.qml"
write_record acme.three drift-me <<MD
---
id: drift-me
plugin: acme.three
title: Drift me
bootstrapped: false
enabled: true
applied:
  commit: ${head3}
  at: t
  tree: deadbeefdeadbeef
files:
  - Panel.qml
---

# Drift me

## Goal

Stay custom.

## Why / decisions

x

## Where to look

- Panel.qml

## Prior art

y

## Re-apply notes

z
MD
out=$(python3 "$STATUS")
assert_jq '.plugins[] | select(.id=="acme.three") | .customizations[0].status == "drift"' "$out" "tree mismatch is drift"
assert_jq '.counts.drift == 1' "$out" "drift counted"
assert_jq '.attention == true' "$out" "drift lights attention"

# --- Unrecorded files light attention without a customization status of unrecorded ---
git_plugin acme.four
head4=$(git -C "$HOME/.config/omarchy/plugins/acme.four" rev-parse HEAD)
echo "custom" >"$HOME/.config/omarchy/plugins/acme.four/Panel.qml"
tree=$(python3 - <<PY
import hashlib
from pathlib import Path
p = Path("$HOME/.config/omarchy/plugins/acme.four/Panel.qml")
h = hashlib.sha256()
h.update(b"Panel.qml\0")
h.update(p.read_bytes())
h.update(b"\n")
print(h.hexdigest()[:16])
PY
)
write_record acme.four rec-four <<MD
---
id: rec-four
plugin: acme.four
title: Four
bootstrapped: false
enabled: true
applied:
  commit: ${head4}
  at: t
  tree: ${tree}
files:
  - Panel.qml
---

# Four

## Goal

Panel tweak.

## Why / decisions

x

## Where to look

- Panel.qml

## Prior art

y

## Re-apply notes

z
MD
echo "another" >"$HOME/.config/omarchy/plugins/acme.four/Other.qml"
out=$(python3 "$STATUS")
assert_jq '.plugins[] | select(.id=="acme.four") | .customizations[0].status == "applied"' "$out" "listed files still applied"
assert_jq '.plugins[] | select(.id=="acme.four") | (.unrecordedFiles | index("Other.qml") != null)' "$out" "Other.qml unrecorded"
assert_jq '.counts.unrecorded >= 1' "$out" "unrecorded counted"
assert_jq '.attention == true' "$out" "unrecorded lights attention"

# --- Reset marks enabled false; unapplied does not light attention if no drafts ---
# Remove leftover drafts from acme.one
rm -rf "$HOME/.config/omarchy/plugin-maleability/acme.one"
out=$(python3 "$STATUS" --reset acme.four)
assert_jq '.ok == true' "$out" "reset ok"
assert_jq '.plugins[] | select(.id=="acme.four") | .customizations[0].status == "unapplied"' "$out" "reset unapplied"
# attention may still be true from other plugins; check this plugin isn't the sole reason
# isolated: only acme.four would be unapplied among remaining... user.clock is stale, acme.three drift
# Check unapplied is counted and NOT in the attention tuple by constructing a clean scan:
rm -rf "$HOME/.config/omarchy/plugin-maleability/user.clock" \
       "$HOME/.config/omarchy/plugin-maleability/acme.three" \
       "$HOME/.config/omarchy/plugins/user.clock" \
       "$HOME/.config/omarchy/plugins/acme.three" \
       "$HOME/.config/omarchy/plugins/acme.one" \
       "$HOME/.config/omarchy/plugins/acme.two"
out=$(python3 "$STATUS")
assert_jq '.counts.unapplied >= 1' "$out" "unapplied counted"
assert_jq '.attention == false' "$out" "unapplied does not light attention"
assert_jq 'has("plugins")' "$out" "success has plugins"

# --- Why alias on item payload ---
write_record acme.four why-alias <<MD
---
id: why-alias
plugin: acme.four
title: Why alias
bootstrapped: false
enabled: false
applied:
  commit: ${head4}
  at: t
files:
  - Panel.qml
---

# Why alias

## Goal

g

## Why

alias body

## Where to look

- Panel.qml

## Prior art

p

## Re-apply notes

r
MD
out=$(python3 "$STATUS")
assert_jq '.plugins[] | select(.id=="acme.four") | .customizations[] | select(.id=="why-alias") | .why == "alias body"' "$out" "Why alias extracted"

echo "ALL PASS"
