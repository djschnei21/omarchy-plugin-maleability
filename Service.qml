import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var settings: ({})
  property bool loading: false
  property bool installing: false
  property bool attention: false
  property var counts: ({ stale: 0, draft: 0, unrecorded: 0, updateAvailable: 0, applied: 0 })
  property var plugins: []
  property int pluginsRevision: 0
  property string message: "Loading…"
  property string _stdout: ""
  property string _stderr: ""
  property bool refreshQueued: false
  property bool fetchNext: false
  property bool installedOnce: false
  property bool acting: false
  property bool reapplyAfterAction: false
  property string actionPluginId: ""
  property var pendingReapplyIds: []

  readonly property int refreshIntervalSec: intSetting("refreshIntervalSec", 120, 30, 3600)
  function itemPrompt(item) {
    var plugin = String((item && item.pluginId) || "")
    var id = String((item && item.customizationId) || "")
    var status = String((item && item.status) || "")
    if (status === "draft")
      return "Refine the draft Omarchy plugin customization '" + id + "' on plugin '" + plugin + "'. Use the plugin-maleability skill. Only this customization."
    if (status === "unrecorded")
      return "Record the unrecorded local edits on Omarchy plugin '" + plugin + "'. Use the plugin-maleability skill. Do not re-apply other customizations."
    return "Re-apply the Omarchy plugin customization '" + id + "' on plugin '" + plugin + "'. Use the plugin-maleability skill. Only this customization — do not re-apply others."
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

  function uninstallPath() {
    return Qt.resolvedUrl("scripts/uninstall").toString().replace(/^file:\/\//, "")
  }

  function refresh(fetch) {
    if (scanProcess.running || installProcess.running || actionProcess.running) {
      refreshQueued = true
      fetchNext = fetchNext || !!fetch
      return
    }
    loading = true
    _stdout = ""
    _stderr = ""
    var cmd = ["python3", helperPath(), "--notify"]
    if (fetch)
      cmd.push("--fetch")
    scanProcess.command = cmd
    scanProcess.running = true
  }

  function apply(raw) {
    try {
      var data = JSON.parse(String(raw || ""))
      attention = data.attention === true
      counts = data.counts || counts
      plugins = Array.isArray(data.plugins) ? data.plugins : []
      pluginsRevision++
      pendingReapplyIds = Array.isArray(data.reapplyIds) ? data.reapplyIds : []
      message = attention ? "Customizations need attention" : "All recorded customizations are applied"
    } catch (error) {
      message = "Could not read customization status."
      plugins = []
    }
  }

  function launchItem(item) {
    if (!item)
      return
    Quickshell.execDetached(["omarchy-agent-prompt", itemPrompt(item)])
  }

  function launchCustomize(pluginId, text) {
    var request = String(text || "").trim()
    var id = String(pluginId || "")
    if (id === "" || request === "")
      return
    Quickshell.execDetached(["omarchy-agent-prompt",
      "On Omarchy plugin '" + id + "', implement this customization and record it with the plugin-maleability skill (enabled: true). Request: " + request])
  }

  function launchReapplyPlugin(pluginId, ids) {
    var id = String(pluginId || "")
    if (id === "")
      return
    var list = []
    if (ids && ids.length)
      for (var i = 0; i < ids.length; i++)
        list.push(String(ids[i]))
    var scope = list.length
      ? " Re-apply only these customizations, in order: " + list.join(", ") + "."
      : " Re-apply its recorded customizations one by one."
    Quickshell.execDetached(["omarchy-agent-prompt",
      "Plugin '" + id + "' is reset to current upstream (HEAD, not a fetch)." + scope + " Use the plugin-maleability skill. Skip drafts that still have a placeholder Goal. Set enabled: true on each record you apply. Do not git reset; the helper already did."])
  }

  function runAction(kind, pluginId, thenReapply) {
    if (actionProcess.running || scanProcess.running)
      return
    var id = String(pluginId || "")
    if (id === "" || (kind !== "reset" && kind !== "update"))
      return
    acting = true
    reapplyAfterAction = thenReapply === true
    actionPluginId = id
    actionProcess.command = ["python3", helperPath(), kind === "update" ? "--update" : "--reset", id]
    actionProcess.running = true
  }

  function deleteCustomization(pluginId, customizationId) {
    if (actionProcess.running || scanProcess.running)
      return
    var id = String(pluginId || "")
    var cid = String(customizationId || "")
    if (id === "" || cid === "")
      return
    acting = true
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

  function uninstall() {
    if (uninstallProcess.running)
      return
    uninstallProcess.command = [uninstallPath()]
    uninstallProcess.running = true
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
      root.installedOnce = true
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
    onExited: function() {
      root.loading = false
      var stdout = String(scanOut.text || root._stdout || "")
      if (stdout.trim() !== "")
        root.apply(stdout)
      else
        root.message = String(scanErr.text || root._stderr || "Status scan failed.").trim()
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
    id: uninstallProcess
    running: false
    command: []
  }

  Process {
    id: actionProcess
    running: false
    command: []
    onExited: function() {
      root.acting = false
      var stdout = String(actionOut.text || "")
      var ok = true
      if (stdout.trim() !== "") {
        root.apply(stdout)
        try {
          var data = JSON.parse(stdout)
          if (data.ok === false)
            ok = false
        } catch (error) {
        }
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
}
