import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var shell: null
  property var settings: ({})
  property bool loading: false
  property bool installing: false
  property bool attention: false
  property var counts: ({ stale: 0, draft: 0, unrecorded: 0, updateAvailable: 0, applied: 0, unapplied: 0, drift: 0 })
  property var plugins: []
  property int pluginsRevision: 0
  property string message: "Loading…"
  property string lastError: ""
  property string _stdout: ""
  property string _stderr: ""
  property bool refreshQueued: false
  property bool fetchNext: false
  property bool fetchAfterLocal: false
  property bool acting: false
  property bool reapplyAfterAction: false
  property string actionPluginId: ""
  property var pendingReapplyIds: []
  property string defaultAgent: ""
  property bool agentProbed: false
  readonly property string pluginVersion: "1.1.0"

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 120, 30, 3600)

  function pluginHome(pluginId) {
    return Quickshell.env("HOME") + "/.config/omarchy/plugins/" + String(pluginId || "")
  }

  function itemPrompt(item) {
    var plugin = String((item && item.pluginId) || "")
    var id = String((item && item.customizationId) || "")
    var status = String((item && item.status) || "")
    var home = pluginHome(plugin)
    if (status === "draft")
      return "Refine the draft Omarchy plugin customization '" + id + "' on plugin '" + plugin + "' at " + home + ". Use the plugin-maleability skill. Fill Goal, Why, Where to look, and Prior art from the current implementation (see references/record-format.md). Only this customization. Do not git reset. Do not commit."
    if (status === "unrecorded" || status === "drift")
      return "Record the " + (status === "drift" ? "local drift on" : "unrecorded local edits on") + " Omarchy plugin '" + plugin + "' at " + home + ". Use the plugin-maleability skill. Write Prior art from the implementation you record (references/record-format.md). Verify live before enabled: true. Do not git reset. Do not commit. Do not re-apply other customizations."
    return "Re-apply the Omarchy plugin customization '" + id + "' on plugin '" + plugin + "' at " + home + ". Use the plugin-maleability skill. Read that record first. Re-implement the Goal using Prior art as a map, not a patch. After it holds, rewrite that record's Prior art from the implementation you just did, tagged with the plugin's current manifest version (applied.version). Only this customization — do not re-apply others. Do not git reset (other customizations may be applied). Do not commit. Verify live before enabled: true."
  }

  function intSetting(name, fallback, minimum, maximum) {
    var value = parseInt(String(settings && settings[name] !== undefined ? settings[name] : fallback), 10)
    if (!isFinite(value))
      value = fallback
    return Math.max(minimum, Math.min(maximum, value))
  }

  function helperPath() {
    return Qt.resolvedUrl("status").toString().replace(/^file:\/\//, "")
  }

  function installPath() {
    return Qt.resolvedUrl("scripts/install").toString().replace(/^file:\/\//, "")
  }

  function refresh(fetch) {
    if (scanProcess.running || installProcess.running || actionProcess.running) {
      refreshQueued = true
      fetchNext = fetchNext || !!fetch
      return
    }
    loading = true
    lastError = ""
    _stdout = ""
    _stderr = ""
    fetchAfterLocal = !!fetch
    var cmd = ["python3", helperPath(), "--notify"]
    scanProcess.command = cmd
    scanProcess.running = true
  }

  function apply(raw) {
    try {
      var data = JSON.parse(String(raw || ""))
      if (data && data.ok === false) {
        lastError = String(data.error || "Action failed.")
        message = lastError
        return false
      }
      attention = data.attention === true
      counts = data.counts || counts
      plugins = Array.isArray(data.plugins) ? data.plugins : []
      pluginsRevision++
      pendingReapplyIds = Array.isArray(data.reapplyIds) ? data.reapplyIds : []
      lastError = ""
      if (counts && counts.unapplied > 0)
        message = counts.unapplied + " unapplied — Re-apply when ready"
      else
        message = attention ? "Customizations need attention" : "All recorded customizations are applied"
      return true
    } catch (error) {
      lastError = "Could not read customization status."
      message = lastError
      return false
    }
  }

  function launchPrompt(prompt) {
    var text = String(prompt || "")
    if (text === "")
      return
    if (agentProbed && defaultAgent === "") {
      lastError = "Set a default agent: omarchy default agent"
      message = lastError
      return
    }
    lastError = ""
    Quickshell.execDetached(["omarchy-agent-prompt", text])
  }

  function launchItem(item) {
    if (!item)
      return
    launchPrompt(itemPrompt(item))
  }

  function launchCustomize(pluginId, text) {
    var request = String(text || "").trim()
    var id = String(pluginId || "")
    if (id === "" || request === "")
      return
    var home = pluginHome(id)
    launchPrompt("On Omarchy plugin '" + id + "' at " + home + ", implement this customization and record it with the plugin-maleability skill. Prior art in the record must be the implementation you just did (references/record-format.md), not a sketch. Verify live before enabled: true. Do not git reset. Do not commit. Request: " + request)
  }

  function launchReapplyPlugin(pluginId, ids) {
    var id = String(pluginId || "")
    if (id === "")
      return
    var list = []
    if (ids && ids.length)
      for (var i = 0; i < ids.length; i++)
        list.push(String(ids[i]))
    var home = pluginHome(id)
    var scope = list.length
      ? " Re-apply only these customizations, in order: " + list.join(", ") + "."
      : " Re-apply its recorded customizations one by one."
    launchPrompt("Plugin '" + id + "' at " + home + " is reset to current upstream (HEAD, not a fetch)." + scope + " Use the plugin-maleability skill. Skip drafts that still have a placeholder Goal. For each one, read the record, re-implement the Goal from Prior art as a map, then rewrite that Prior art from the implementation you just did. Verify live before enabled: true. Do not git reset; the helper already did. Do not commit.")
  }

  function runAction(kind, pluginId, thenReapply) {
    if (actionProcess.running || scanProcess.running || installProcess.running)
      return
    var id = String(pluginId || "")
    if (id === "" || (kind !== "reset" && kind !== "update"))
      return
    acting = true
    lastError = ""
    reapplyAfterAction = thenReapply === true
    actionPluginId = id
    actionProcess.command = ["python3", helperPath(), kind === "update" ? "--update" : "--reset", id]
    actionProcess.running = true
  }

  function deleteCustomization(pluginId, customizationId) {
    if (actionProcess.running || scanProcess.running || installProcess.running)
      return
    var id = String(pluginId || "")
    var cid = String(customizationId || "")
    if (id === "" || cid === "")
      return
    acting = true
    lastError = ""
    reapplyAfterAction = false
    actionPluginId = id
    actionProcess.command = ["python3", helperPath(), "--delete", id, cid]
    actionProcess.running = true
  }

  function openRecord(path) {
    var value = String(path || "")
    if (value === "")
      return
    Quickshell.execDetached(["omarchy-launch-editor", value])
  }

  Component.onCompleted: {
    installing = true
    installProcess.command = [installPath()]
    installProcess.running = true
  }

  Timer {
    interval: root.refreshIntervalSec * 1000
    repeat: true
    running: true
    onTriggered: root.refresh(false)
  }

  Process {
    id: installProcess
    running: false
    command: []
    onExited: function() {
      root.installing = false
      var stdout = String(installOut.text || "")
      if (stdout.trim() !== "")
        root.apply(stdout)
      root.refresh(false)
    }
    stdout: StdioCollector {
      id: installOut
      waitForEnd: true
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  Process {
    id: scanProcess
    running: false
    command: []
    onExited: function(exitCode) {
      root.loading = false
      var stdout = String(scanOut.text || root._stdout || "")
      var ok = false
      if (stdout.trim() !== "")
        ok = root.apply(stdout)
      else {
        root.lastError = String(scanErr.text || root._stderr || "Status scan failed.").trim()
        root.message = root.lastError
      }
      if (exitCode !== 0 && ok)
        ok = false
      if (ok && root.fetchAfterLocal) {
        root.fetchAfterLocal = false
        root.loading = true
        scanProcess.command = ["python3", root.helperPath(), "--notify", "--fetch"]
        Qt.callLater(function() { scanProcess.running = true })
        return
      }
      root.fetchAfterLocal = false
      if (root.refreshQueued) {
        var fetch = root.fetchNext
        root.refreshQueued = false
        root.fetchNext = false
        Qt.callLater(function() { root.refresh(fetch) })
      }
    }
    stdout: StdioCollector {
      id: scanOut
      waitForEnd: true
      onStreamFinished: root._stdout = text
    }
    stderr: StdioCollector {
      id: scanErr
      waitForEnd: true
      onStreamFinished: root._stderr = text
    }
  }

  Process {
    id: actionProcess
    running: false
    command: []
    onExited: function(exitCode) {
      root.acting = false
      var stdout = String(actionOut.text || "")
      var ok = exitCode === 0
      if (stdout.trim() !== "") {
        var applied = root.apply(stdout)
        if (!applied)
          ok = false
      } else if (exitCode !== 0) {
        ok = false
        root.lastError = "Action failed."
        root.message = root.lastError
      }
      if (ok && root.pendingReapplyIds && root.pendingReapplyIds.length)
        root.launchReapplyPlugin(root.actionPluginId, root.pendingReapplyIds)
      else if (root.reapplyAfterAction && ok)
        root.launchReapplyPlugin(root.actionPluginId, [])
      root.reapplyAfterAction = false
      root.pendingReapplyIds = []
      root.actionPluginId = ""
      Qt.callLater(function() { root.refresh(false) })
    }
    stdout: StdioCollector {
      id: actionOut
      waitForEnd: true
    }
    stderr: StdioCollector { waitForEnd: true }
  }

  Process {
    id: agentProbe
    running: true
    command: ["omarchy-default-agent"]
    stdout: StdioCollector {
      id: agentOut
      waitForEnd: true
    }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function() {
      root.defaultAgent = String(agentOut.text || "").trim()
      root.agentProbed = true
    }
  }
}
