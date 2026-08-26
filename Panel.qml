import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "djschnei21.plugin-customizations"
  ipcTarget: "djschnei21.plugin-customizations"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  property bool uninstallArmed: false

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function rowsFor(kind) {
    var rows = []
    var plugins = model.plugins || []
    for (var i = 0; i < plugins.length; i++) {
      var plugin = plugins[i]
      var list = plugin.customizations || []
      for (var j = 0; j < list.length; j++) {
        if (list[j].status !== kind)
          continue
        rows.push({
          key: plugin.id + ":" + list[j].id,
          pluginId: plugin.id,
          name: plugin.name,
          title: list[j].title,
          detail: "applied " + String(list[j].appliedCommit || "").slice(0, 7) +
            (plugin.head ? " · HEAD " + String(plugin.head).slice(0, 7) : "")
        })
      }
      if (kind === "unrecorded" && (plugin.unrecordedFiles || []).length > 0) {
        var already = false
        for (var k = 0; k < list.length; k++)
          if (list[k].status === "unrecorded") already = true
        if (!already)
          rows.push({
            key: plugin.id + ":unrecorded",
            pluginId: plugin.id,
            name: plugin.name,
            title: plugin.unrecordedFiles.length + " unrecorded file" + (plugin.unrecordedFiles.length === 1 ? "" : "s"),
            detail: plugin.unrecordedFiles.slice(0, 3).join(", ")
          })
      }
      if (kind === "behind" && plugin.behind)
        rows.push({
          key: plugin.id + ":behind",
          pluginId: plugin.id,
          name: plugin.name,
          title: "Upstream has new commits",
          detail: "HEAD " + String(plugin.head || "").slice(0, 7) + " · origin " + String(plugin.origin || "").slice(0, 7)
        })
    }
    return rows
  }

  onOpenedChanged: if (opened) {
    uninstallArmed = false
    uninstallArmTimer.stop()
    if (panelFlick) panelFlick.contentY = 0
    model.refresh(true)
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  Service { id: model; settings: root.settings }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { model.refresh(true); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰐕"
    tooltipText: model.attention ? "Plugin customizations need attention" : "Plugin customizations"
    active: model.attention
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton) model.refresh(true)
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onActivateRequested: model.launchReapply()
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
            title: "Plugin customizations"
            meta: model.installing ? "Installing skill links…" : (model.loading ? "Scanning plugins…" : model.message)
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: "󰐕"
                color: model.attention ? root.urgent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
              }
            }
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(12)
            Button {
              text: "Re-apply"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: {
                model.launchReapply()
                root.close()
              }
            }
            Button {
              text: "Refresh"
              bordered: true
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: model.refresh(true)
            }
            Button {
              text: root.uninstallArmed ? "Confirm uninstall?" : "Uninstall"
              bordered: true
              foreground: root.uninstallArmed ? root.urgent : root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.caption
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: {
                if (!root.uninstallArmed) {
                  root.uninstallArmed = true
                  uninstallArmTimer.restart()
                  return
                }
                root.uninstallArmed = false
                model.uninstall()
                root.close()
              }
            }
          }

          StatusSection {
            title: "NEEDS RE-APPLY"
            emptyText: ""
            model: root.rowsFor("stale")
          }
          StatusSection {
            title: "DRAFTS FROM INSTALL"
            emptyText: ""
            model: root.rowsFor("draft")
          }
          StatusSection {
            title: "UNRECORDED EDITS"
            emptyText: ""
            model: root.rowsFor("unrecorded")
          }
          StatusSection {
            title: "UPDATES AVAILABLE"
            emptyText: ""
            model: root.rowsFor("behind")
          }
          StatusSection {
            title: "APPLIED"
            emptyText: "No recorded customizations yet."
            model: root.rowsFor("applied")
            showWhenEmpty: root.rowsFor("stale").length === 0 &&
              root.rowsFor("draft").length === 0 &&
              root.rowsFor("unrecorded").length === 0
          }
        }
      }
    }
  }

  Timer {
    id: uninstallArmTimer
    interval: 4000
    repeat: false
    onTriggered: root.uninstallArmed = false
  }

  component StatusSection: Column {
    id: section
    property string title: ""
    property var model: []
    property string emptyText: ""
    property bool showWhenEmpty: false
    visible: model.length > 0 || (showWhenEmpty && emptyText !== "")
    width: parent ? parent.width : 0
    spacing: Style.space(8)

    PanelSeparator { foreground: root.foreground }
    PanelSectionHeader {
      width: parent.width
      text: section.title + (section.model.length > 0 ? "  " + section.model.length : "")
      foreground: root.foreground
      fontFamily: root.fontFamily
    }
    Text {
      visible: section.model.length === 0
      width: parent.width
      text: section.emptyText
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
    }
    Repeater {
      model: section.model
      Column {
        required property var modelData
        width: parent.width
        spacing: Style.space(1)
        Text {
          width: parent.width
          text: modelData.name || modelData.pluginId
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideRight
        }
        Text {
          width: parent.width
          text: modelData.title + (modelData.detail ? " · " + modelData.detail : "")
          textFormat: Text.PlainText
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
