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
  readonly property bool attention: model.attention === true

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  property string page: "home"
  property var selectedPlugin: null
  property var selectedItem: null
  property var pluginIds: []
  property bool resetArmed: false
  property bool reapplyArmed: false
  property bool updateOpen: false
  property bool deleteArmed: false
  property string customizeText: ""

  function findPlugin(id) {
    var list = model.plugins || []
    for (var i = 0; i < list.length; i++)
      if (list[i].id === id)
        return list[i]
    return null
  }

  function rebuild() {
    var ids = []
    var list = model.plugins || []
    for (var i = 0; i < list.length; i++)
      ids.push(list[i].id)
    pluginIds = ids
    if (selectedPlugin) {
      var next = findPlugin(selectedPlugin.id)
      selectedPlugin = next
      if (!next) {
        page = "home"
        selectedItem = null
      } else if (selectedItem) {
        var kept = null
        var recs = next.customizations || []
        for (var j = 0; j < recs.length; j++)
          if (recs[j].id === selectedItem.id)
            kept = recs[j]
        selectedItem = kept
        if (!kept && page === "item")
          page = "plugin"
      }
    }
  }

  function hasRecords(p) {
    return !!(p && p.customizations && p.customizations.length > 0)
  }

  function pluginSummary(p) {
    if (!p)
      return ""
    var applied = 0, unapplied = 0, draft = 0, stale = 0
    var recs = p.customizations || []
    for (var i = 0; i < recs.length; i++) {
      var s = recs[i].status
      if (s === "applied") applied++
      else if (s === "unapplied") unapplied++
      else if (s === "draft") draft++
      else if (s === "stale") stale++
    }
    var bits = []
    if (stale) bits.push(stale + " stale")
    if (applied) bits.push(applied + " applied")
    if (unapplied) bits.push(unapplied + " unapplied")
    if (draft) bits.push(draft + " draft")
    if (p.behind) bits.push("update available")
    if (bits.length === 0) return "clean"
    return bits.join(" · ")
  }

  function itemActionLabel(item) {
    if (!item) return ""
    if (item.status === "draft") return "Refine"
    return "Re-apply"
  }

  function goHome() {
    page = "home"
    selectedPlugin = null
    selectedItem = null
    resetArmed = false
    reapplyArmed = false
    updateOpen = false
    deleteArmed = false
    customizeText = ""
    if (panelFlick) panelFlick.contentY = 0
  }

  function goPlugin(id) {
    selectedPlugin = findPlugin(id)
    selectedItem = null
    page = selectedPlugin ? "plugin" : "home"
    resetArmed = false
    reapplyArmed = false
    updateOpen = false
    deleteArmed = false
    customizeText = ""
    if (panelFlick) panelFlick.contentY = 0
  }

  function goItem(item) {
    selectedItem = item
    page = item ? "item" : "plugin"
    deleteArmed = false
    if (panelFlick) panelFlick.contentY = 0
  }

  function clearArms() {
    resetArmed = false
    reapplyArmed = false
    updateOpen = false
    deleteArmed = false
    resetArmTimer.stop()
    reapplyArmTimer.stop()
    deleteArmTimer.stop()
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
    model.refresh(true)
  }

  function debugState() {
    return JSON.stringify({
      v: "1.0.5",
      page: root.page,
      plugins: root.pluginIds.length,
      plugin: root.selectedPlugin ? root.selectedPlugin.id : ""
    })
  }

  onOpenedChanged: if (opened) {
    clearArms()
    goHome()
    model.refresh(true)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service { id: model; settings: root.settings }

  Connections {
    target: model
    function onPluginsRevisionChanged() { root.rebuild() }
    function onLoadingChanged() { if (!model.loading) root.rebuild() }
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
        if (root.page === "item") { root.goPlugin(root.selectedPlugin.id); return }
        if (root.page === "plugin") { root.goHome(); return }
        root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "r" || text === "R") model.refresh(true)
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
            meta: {
              if (model.installing) return "Installing skill links…"
              if (model.acting) return "Working on plugin…"
              if (model.loading) return "Scanning plugins…"
              if (root.page === "item" && root.selectedItem)
                return (root.selectedPlugin ? root.selectedPlugin.name + " · " : "") + root.selectedItem.status
              if (root.page === "plugin" && root.selectedPlugin)
                return root.pluginSummary(root.selectedPlugin)
              return root.pluginIds.length + " plugin" + (root.pluginIds.length === 1 ? "" : "s")
            }
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰠱"
                color: model.attention ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }
          }

          // ---- home ----
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
                onClicked: model.refresh(true)
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

          // ---- plugin ----
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

            Text {
              width: parent.width
              text: "CUSTOMIZATIONS"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }

            Text {
              visible: root.selectedPlugin && (!root.selectedPlugin.customizations || root.selectedPlugin.customizations.length === 0)
              width: parent.width
              text: "No recorded customizations."
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
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

            Text {
              width: parent.width
              text: "CUSTOMIZE"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
            }
            TextField {
              id: customizeField
              width: parent.width
              foreground: root.foreground
              placeholderText: "Describe a change…"
              text: root.customizeText
              onTextChanged: root.customizeText = text
              onAccepted: {
                if (root.customizeText.trim() === "")
                  return
                model.launchCustomize(root.selectedPlugin.id, root.customizeText)
                root.customizeText = ""
                customizeField.text = ""
                root.close()
              }
              Keys.onEscapePressed: keyCatcher.forceActiveFocus()
            }
            Button {
              text: "Send to agent"
              enabled: root.customizeText.trim() !== "" && !model.acting
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: {
                model.launchCustomize(root.selectedPlugin.id, root.customizeText)
                root.customizeText = ""
                customizeField.text = ""
                root.close()
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
                text: root.resetArmed ? "Confirm reset?" : "Reset to upstream"
                enabled: !model.acting
                bordered: true
                foreground: root.resetArmed ? root.urgent : root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  if (!root.resetArmed) {
                    root.resetArmed = true
                    resetArmTimer.restart()
                    return
                  }
                  root.resetArmed = false
                  model.runAction("reset", root.selectedPlugin.id, false)
                }
              }
              Button {
                visible: root.hasRecords(root.selectedPlugin)
                text: root.reapplyArmed ? "Confirm re-apply?" : "Re-apply"
                enabled: !model.acting
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  if (!root.reapplyArmed) {
                    root.reapplyArmed = true
                    reapplyArmTimer.restart()
                    return
                  }
                  root.reapplyArmed = false
                  model.runAction("reset", root.selectedPlugin.id, true)
                }
              }
              Button {
                visible: root.selectedPlugin && root.selectedPlugin.behind
                text: {
                  if (!root.hasRecords(root.selectedPlugin))
                    return root.updateOpen ? "Confirm update?" : "Update"
                  return root.updateOpen ? "Cancel update" : "Update"
                }
                enabled: !model.acting
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  if (!root.hasRecords(root.selectedPlugin)) {
                    if (!root.updateOpen) {
                      root.updateOpen = true
                      return
                    }
                    root.updateOpen = false
                    model.runAction("update", root.selectedPlugin.id, false)
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
                enabled: !model.acting
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  root.updateOpen = false
                  model.runAction("update", root.selectedPlugin.id, false)
                }
              }
              Button {
                width: parent.width
                leftAlign: true
                text: "Upstream then re-apply"
                enabled: !model.acting
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  root.updateOpen = false
                  model.runAction("update", root.selectedPlugin.id, true)
                }
              }
            }
          }

          // ---- item ----
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
                  model.openRecord(root.selectedItem.path)
                  root.close()
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
                  model.launchItem({
                    pluginId: root.selectedPlugin.id,
                    customizationId: root.selectedItem.id,
                    status: root.selectedItem.status
                  })
                  root.close()
                }
              }
              Button {
                text: root.deleteArmed ? "Confirm delete?" : "Delete"
                enabled: !model.acting
                bordered: true
                foreground: root.deleteArmed ? root.urgent : root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  if (!root.deleteArmed) {
                    root.deleteArmed = true
                    deleteArmTimer.restart()
                    return
                  }
                  root.deleteArmed = false
                  model.deleteCustomization(root.selectedPlugin.id, root.selectedItem.id)
                }
              }
            }
          }
        }
      }
    }
  }

  Timer { id: resetArmTimer; interval: 4000; repeat: false; onTriggered: root.resetArmed = false }
  Timer { id: reapplyArmTimer; interval: 4000; repeat: false; onTriggered: root.reapplyArmed = false }
  Timer { id: deleteArmTimer; interval: 4000; repeat: false; onTriggered: root.deleteArmed = false }
}
