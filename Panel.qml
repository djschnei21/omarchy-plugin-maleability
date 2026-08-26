import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "djschnei21.plugin-maleability"
  ipcTarget: "djschnei21.plugin-maleability"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var model: {
    var sh = bar && bar.shell ? bar.shell : null
    if (sh && typeof sh.serviceFor === "function")
      return sh.serviceFor(root.moduleName)
    return null
  }
  readonly property bool attention: !!(model && model.attention === true)

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property string page: "home"
  property var selectedPlugin: null
  property var selectedItem: null
  property var pluginIds: []
  property bool updateOpen: false
  property string customizeText: ""
  property string confirmKind: ""
  property string confirmMessage: ""

  function findPlugin(id) {
    var list = (model && model.plugins) ? model.plugins : []
    for (var i = 0; i < list.length; i++)
      if (list[i].id === id)
        return list[i]
    return null
  }

  function pluginScore(p) {
    if (!p)
      return 0
    var n = 0
    if (p.unrecordedFiles && p.unrecordedFiles.length)
      n += 4
    if (p.behind)
      n += 3
    var recs = p.customizations || []
    for (var i = 0; i < recs.length; i++) {
      var s = recs[i].status
      if (s === "stale") n += 5
      else if (s === "drift") n += 4
      else if (s === "draft") n += 3
      else if (s === "unapplied") n += 1
    }
    return n
  }

  function rebuild() {
    var scored = []
    var list = (model && model.plugins) ? model.plugins : []
    for (var i = 0; i < list.length; i++)
      scored.push({
        id: list[i].id,
        name: String(list[i].name || list[i].id).toLowerCase(),
        score: pluginScore(list[i])
      })
    scored.sort(function(a, b) {
      if (b.score !== a.score)
        return b.score - a.score
      if (a.name < b.name)
        return -1
      if (a.name > b.name)
        return 1
      return String(a.id).localeCompare(String(b.id))
    })
    var ids = []
    for (var j = 0; j < scored.length; j++)
      ids.push(scored[j].id)
    pluginIds = ids
    if (selectedPlugin) {
      var next = findPlugin(selectedPlugin.id)
      selectedPlugin = next
      if (!next) {
        page = "home"
        selectedItem = null
      } else if (selectedItem) {
        if (selectedItem.status === "unrecorded") {
          if (!next.unrecordedFiles || next.unrecordedFiles.length === 0) {
            selectedItem = null
            if (page === "item")
              page = "plugin"
          } else {
            selectedItem = unrecordedItem(next)
          }
        } else {
          var kept = null
          var recs = next.customizations || []
          for (var k = 0; k < recs.length; k++)
            if (recs[k].id === selectedItem.id)
              kept = recs[k]
          selectedItem = kept
          if (!kept && page === "item")
            page = "plugin"
        }
      }
    }
  }

  function hasRecords(p) {
    return !!(p && p.customizations && p.customizations.length > 0)
  }

  function unrecordedItem(p) {
    var files = (p && p.unrecordedFiles) ? p.unrecordedFiles : []
    return {
      id: "__unrecorded__",
      title: "Unrecorded local edits",
      status: "unrecorded",
      goal: files.length ? ("Record files not yet in a customization: " + files.join(", ")) : "",
      why: "",
      files: files,
      path: ""
    }
  }

  function pluginSummary(p) {
    if (!p)
      return ""
    var applied = 0, unapplied = 0, draft = 0, stale = 0, drift = 0
    var recs = p.customizations || []
    for (var i = 0; i < recs.length; i++) {
      var s = recs[i].status
      if (s === "applied") applied++
      else if (s === "unapplied") unapplied++
      else if (s === "draft") draft++
      else if (s === "stale") stale++
      else if (s === "drift") drift++
    }
    var bits = []
    if (stale) bits.push(stale + " stale")
    if (drift) bits.push(drift + " drift")
    if (applied) bits.push(applied + " applied")
    if (unapplied) bits.push(unapplied + " unapplied")
    if (draft) bits.push(draft + " draft")
    if (p.unrecordedFiles && p.unrecordedFiles.length)
      bits.push(p.unrecordedFiles.length + " unrecorded")
    if (p.behind) bits.push("update available")
    if (bits.length === 0) return "clean"
    return bits.join(" · ")
  }

  function itemActionLabel(item) {
    if (!item) return ""
    if (item.status === "draft") return "Refine"
    if (item.status === "unrecorded" || item.status === "drift") return "Record"
    return "Re-apply"
  }

  function goHome() {
    page = "home"
    selectedPlugin = null
    selectedItem = null
    updateOpen = false
    confirmKind = ""
    customizeText = ""
    if (panelFlick) panelFlick.contentY = 0
  }

  function goPlugin(id) {
    selectedPlugin = findPlugin(id)
    selectedItem = null
    page = selectedPlugin ? "plugin" : "home"
    updateOpen = false
    confirmKind = ""
    customizeText = ""
    if (panelFlick) panelFlick.contentY = 0
  }

  function goItem(item) {
    selectedItem = item
    page = item ? "item" : "plugin"
    confirmKind = ""
    if (panelFlick) panelFlick.contentY = 0
  }

  function askConfirm(kind, message) {
    confirmKind = kind
    confirmMessage = message
  }

  function runConfirmed() {
    var kind = confirmKind
    confirmKind = ""
    if (!model || !selectedPlugin)
      return
    if (kind === "reset")
      model.runAction("reset", selectedPlugin.id, false)
    else if (kind === "reapply")
      model.runAction("reset", selectedPlugin.id, true)
    else if (kind === "update")
      model.runAction("update", selectedPlugin.id, false)
    else if (kind === "updateReapply")
      model.runAction("update", selectedPlugin.id, true)
    else if (kind === "delete" && selectedItem)
      model.deleteCustomization(selectedPlugin.id, selectedItem.id)
  }

  function open() {
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function refreshModel() {
    if (model)
      model.refresh(true)
  }

  function debugState() {
    return JSON.stringify({
      v: model && model.pluginVersion ? model.pluginVersion : "1.1.0",
      page: root.page,
      plugins: root.pluginIds.length,
      plugin: root.selectedPlugin ? root.selectedPlugin.id : ""
    })
  }

  function heroMeta() {
    if (!model)
      return "Loading…"
    if (model.lastError)
      return model.lastError
    if (model.installing)
      return "Installing skill links…"
    if (model.acting)
      return "Working on plugin…"
    if (model.loading)
      return "Scanning plugins…"
    if (root.page === "item" && root.selectedItem)
      return (root.selectedPlugin ? root.selectedPlugin.name + " · " : "") + root.selectedItem.status
    if (root.page === "plugin" && root.selectedPlugin)
      return root.pluginSummary(root.selectedPlugin)
    var n = root.pluginIds.length
    var label = n + " plugin" + (n === 1 ? "" : "s")
    if (model.counts && model.counts.unapplied > 0)
      return label + " · " + model.counts.unapplied + " unapplied — Re-apply when ready"
    return label
  }

  onOpenedChanged: if (opened) {
    confirmKind = ""
    goHome()
    if (model)
      model.refresh(true)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  onSettingsChanged: {
    if (model)
      model.settings = root.settings
  }

  Connections {
    target: root.model
    enabled: root.model !== null
    function onPluginsRevisionChanged() { root.rebuild() }
    function onLoadingChanged() { if (root.model && !root.model.loading) root.rebuild() }
  }

  onModelChanged: {
    if (model) {
      model.settings = root.settings
      root.rebuild()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(Math.max(content.implicitHeight, Style.space(420)), Style.space(640))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: customizeField.activeFocus
      onCloseRequested: {
        if (root.confirmKind !== "") { root.confirmKind = ""; return }
        if (root.page === "item") { root.goPlugin(root.selectedPlugin.id); return }
        if (root.page === "plugin") { root.goHome(); return }
        root.close()
      }
      onReturnRequested: {
        if (root.confirmKind !== "")
          root.runConfirmed()
      }
      onTabRequested: function(direction) {
        if (root.confirmKind !== "")
          return
        root.switchPanel(direction)
      }
      onTextKey: function(text) {
        if (root.confirmKind !== "")
          return
        if (text === "r" || text === "R") root.refreshModel()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: content
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: {
              if (root.page === "item" && root.selectedItem) return root.selectedItem.title
              if (root.page === "plugin" && root.selectedPlugin) return root.selectedPlugin.name
              return "Plugin Maleability"
            }
            meta: root.heroMeta()
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰠱"
                color: root.attention ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }
          }

          Column {
            visible: root.page === "home"
            width: parent.width
            spacing: Style.space(8)

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(12)
              Button {
                text: "Refresh"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: root.refreshModel()
              }
            }

            Repeater {
              model: root.pluginIds.length
              Button {
                required property int index
                width: content.width
                leftAlign: true
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                text: {
                  var p = root.findPlugin(root.pluginIds[index])
                  if (!p) return root.pluginIds[index]
                  return p.name + "  ·  " + root.pluginSummary(p)
                }
                onClicked: root.goPlugin(root.pluginIds[index])
              }
            }
          }

          Column {
            visible: root.page === "plugin" && root.selectedPlugin
            width: parent.width
            spacing: Style.space(10)

            Row {
              spacing: Style.space(8)
              Button {
                text: "Back"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: root.goHome()
              }
            }

            PanelSectionHeader {
              width: parent.width
              text: "CUSTOMIZATIONS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Text {
              visible: root.selectedPlugin && (!root.selectedPlugin.customizations || root.selectedPlugin.customizations.length === 0) && !(root.selectedPlugin.unrecordedFiles && root.selectedPlugin.unrecordedFiles.length)
              width: parent.width
              text: "No recorded customizations."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }

            Button {
              visible: !!(root.selectedPlugin && root.selectedPlugin.unrecordedFiles && root.selectedPlugin.unrecordedFiles.length)
              width: content.width
              leftAlign: true
              bordered: true
              foreground: root.urgent
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              verticalPadding: Style.spacing.controlPaddingY
              text: root.selectedPlugin ? ("Unrecorded local edits  ·  " + root.selectedPlugin.unrecordedFiles.length) : ""
              onClicked: root.goItem(root.unrecordedItem(root.selectedPlugin))
            }

            Repeater {
              model: root.selectedPlugin && root.selectedPlugin.customizations ? root.selectedPlugin.customizations.length : 0
              Button {
                required property int index
                width: content.width
                leftAlign: true
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                text: {
                  var recs = root.selectedPlugin ? (root.selectedPlugin.customizations || []) : []
                  var rec = recs[index]
                  if (!rec) return ""
                  return rec.title + "  ·  " + rec.status
                }
                onClicked: {
                  var recs = root.selectedPlugin ? (root.selectedPlugin.customizations || []) : []
                  root.goItem(recs[index])
                }
              }
            }

            PanelSeparator { foreground: root.foreground }

            PanelSectionHeader {
              width: parent.width
              text: "CUSTOMIZE"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            TextField {
              id: customizeField
              width: parent.width
              foreground: root.foreground
              placeholderText: "Describe a change…"
              text: root.customizeText
              onTextChanged: root.customizeText = text
              onAccepted: {
                if (root.customizeText.trim() === "" || !root.model)
                  return
                root.model.launchCustomize(root.selectedPlugin.id, root.customizeText)
                root.customizeText = ""
                customizeField.text = ""
              }
              Keys.onEscapePressed: keyCatcher.forceActiveFocus()
            }
            Button {
              text: "Send to agent"
              enabled: root.customizeText.trim() !== "" && root.model && !root.model.acting
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: {
                root.model.launchCustomize(root.selectedPlugin.id, root.customizeText)
                root.customizeText = ""
                customizeField.text = ""
              }
            }

            PanelSeparator {
              visible: root.hasRecords(root.selectedPlugin) || (root.selectedPlugin && root.selectedPlugin.behind)
              foreground: root.foreground
            }

            Flow {
              visible: root.hasRecords(root.selectedPlugin) || (root.selectedPlugin && root.selectedPlugin.behind)
              width: parent.width
              spacing: Style.space(8)
              Button {
                visible: root.hasRecords(root.selectedPlugin)
                text: "Reset to upstream"
                enabled: root.model && !root.model.acting
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: root.askConfirm("reset", "Reset this plugin to upstream? Untracked files in the checkout will be removed. Records stay, marked unapplied.")
              }
              Button {
                visible: root.hasRecords(root.selectedPlugin)
                text: "Re-apply"
                enabled: root.model && !root.model.acting
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: root.askConfirm("reapply", "Reset to upstream, then re-apply recorded customizations? Untracked files in the checkout will be removed.")
              }
              Button {
                visible: root.selectedPlugin && root.selectedPlugin.behind
                text: {
                  if (!root.hasRecords(root.selectedPlugin))
                    return "Update"
                  return root.updateOpen ? "Cancel update" : "Update"
                }
                enabled: root.model && !root.model.acting
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  if (!root.hasRecords(root.selectedPlugin)) {
                    root.askConfirm("update", "Update this plugin to upstream? Untracked files in the checkout will be removed.")
                    return
                  }
                  root.updateOpen = !root.updateOpen
                }
              }
            }

            Column {
              visible: root.updateOpen && root.hasRecords(root.selectedPlugin) && root.selectedPlugin && root.selectedPlugin.behind
              width: parent.width
              spacing: Style.space(8)
              Button {
                width: parent.width
                leftAlign: true
                text: "Upstream only"
                enabled: root.model && !root.model.acting
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  root.updateOpen = false
                  root.askConfirm("update", "Update to upstream only? Local customizations stay recorded but unapplied. Untracked files will be removed.")
                }
              }
              Button {
                width: parent.width
                leftAlign: true
                text: "Upstream then re-apply"
                enabled: root.model && !root.model.acting
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  root.updateOpen = false
                  root.askConfirm("updateReapply", "Update to upstream, then re-apply recorded customizations? Untracked files will be removed.")
                }
              }
            }
          }

          Column {
            visible: root.page === "item" && root.selectedItem
            width: parent.width
            spacing: Style.space(12)

            Text {
              visible: root.selectedItem && root.selectedItem.goal !== ""
              width: parent.width
              text: root.selectedItem ? root.selectedItem.goal : ""
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }
            Text {
              visible: root.selectedItem && root.selectedItem.why !== ""
              width: parent.width
              text: root.selectedItem ? root.selectedItem.why : ""
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            Text {
              visible: root.selectedItem && (root.selectedItem.appliedVersion || (root.selectedPlugin && root.selectedPlugin.version))
              width: parent.width
              text: {
                var rec = root.selectedItem
                var plugin = root.selectedPlugin
                var applied = rec && rec.appliedVersion ? rec.appliedVersion : ""
                var current = plugin && plugin.version ? plugin.version : ""
                if (applied && current && applied !== current)
                  return "Prior art  v" + applied + "  ·  plugin now v" + current
                if (applied)
                  return "Prior art  v" + applied
                if (current)
                  return "Plugin  v" + current
                return ""
              }
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Text {
              visible: root.selectedItem && root.selectedItem.files && root.selectedItem.files.length > 0
              width: parent.width
              text: root.selectedItem ? "Files  " + root.selectedItem.files.join(", ") : ""
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Row {
              spacing: Style.space(8)
              Button {
                text: "Back"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: root.goPlugin(root.selectedPlugin.id)
              }
              Button {
                visible: root.selectedItem && root.selectedItem.path !== ""
                text: "Open record"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  root.model.openRecord(root.selectedItem.path)
                }
              }
              Button {
                visible: root.itemActionLabel(root.selectedItem) !== ""
                text: root.itemActionLabel(root.selectedItem)
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  root.model.launchItem({
                    pluginId: root.selectedPlugin.id,
                    customizationId: root.selectedItem.id,
                    status: root.selectedItem.status
                  })
                }
              }
              Button {
                visible: root.selectedItem && root.selectedItem.status !== "unrecorded"
                text: "Delete"
                enabled: root.model && !root.model.acting
                bordered: true
                foreground: root.urgent
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  var destructive = root.selectedItem && root.selectedItem.status !== "unapplied" && root.selectedItem.status !== "draft"
                  root.askConfirm("delete", destructive
                    ? "Delete this customization? The plugin will reset to current HEAD, then remaining enabled customizations will be re-applied. Untracked files will be removed."
                    : "Delete this record? The plugin checkout is left as-is.")
                }
              }
            }
          }
        }
      }

      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        z: 20
        opened: root.confirmKind !== ""
        message: root.confirmMessage
        confirmText: "Confirm"
        cancelText: "Cancel"
        background: Color.popups.background
        foreground: root.foreground
        fontFamily: root.fontFamily
        onCanceled: root.confirmKind = ""
        onConfirmed: root.runConfirmed()
      }
    }
  }
}
