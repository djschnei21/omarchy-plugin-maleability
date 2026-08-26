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
  property var selected: null

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function rowFromCustomization(plugin, item) {
    return {
      key: plugin.id + ":" + item.id,
      kind: "customization",
      status: item.status,
      pluginId: plugin.id,
      name: plugin.name,
      customizationId: item.id,
      title: item.title,
      path: item.path || "",
      goal: item.goal || "",
      why: item.why || "",
      files: item.files || [],
      appliedCommit: item.appliedCommit || "",
      head: plugin.head || "",
      detail: "applied " + String(item.appliedCommit || "").slice(0, 7) +
        (plugin.head ? " · HEAD " + String(plugin.head).slice(0, 7) : "")
    }
  }

  function rowsFor(kind) {
    var rows = []
    var plugins = model.plugins || []
    for (var i = 0; i < plugins.length; i++) {
      var plugin = plugins[i]
      var list = plugin.customizations || []
      for (var j = 0; j < list.length; j++) {
        if (list[j].status === kind)
          rows.push(root.rowFromCustomization(plugin, list[j]))
      }
      if (kind === "unrecorded" && (plugin.unrecordedFiles || []).length > 0) {
        var already = false
        for (var k = 0; k < list.length; k++)
          if (list[k].status === "unrecorded") already = true
        if (!already)
          rows.push({
            key: plugin.id + ":unrecorded",
            kind: "unrecorded",
            status: "unrecorded",
            pluginId: plugin.id,
            name: plugin.name,
            customizationId: "",
            title: plugin.unrecordedFiles.length + " unrecorded file" + (plugin.unrecordedFiles.length === 1 ? "" : "s"),
            path: "",
            goal: "These local edits are not in a customization record yet.",
            why: "",
            files: plugin.unrecordedFiles,
            appliedCommit: "",
            head: plugin.head || "",
            detail: plugin.unrecordedFiles.slice(0, 3).join(", ")
          })
      }
      if (kind === "behind" && plugin.behind)
        rows.push({
          key: plugin.id + ":behind",
          kind: "behind",
          status: "behind",
          pluginId: plugin.id,
          name: plugin.name,
          customizationId: "",
          title: "Upstream has new commits",
          path: "",
          goal: "This plugin can be updated. Customizations are listed separately — apply each one after the update.",
          why: "",
          files: [],
          appliedCommit: "",
          head: plugin.head || "",
          detail: "HEAD " + String(plugin.head || "").slice(0, 7) + " · origin " + String(plugin.origin || "").slice(0, 7)
        })
    }
    return rows
  }

  function actionLabel(item) {
    if (!item)
      return ""
    if (item.status === "draft")
      return "Refine"
    if (item.status === "unrecorded")
      return "Record"
    if (item.status === "behind")
      return ""
    return "Re-apply"
  }

  function selectRow(item) {
    selected = item || null
    if (panelFlick)
      panelFlick.contentY = 0
  }

  onOpenedChanged: if (opened) {
    uninstallArmed = false
    uninstallArmTimer.stop()
    selected = null
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
      onCloseRequested: {
        if (root.selected) {
          root.selectRow(null)
          return
        }
        root.close()
      }
      onActivateRequested: {
        if (root.selected && root.actionLabel(root.selected) !== "") {
          model.launchItem(root.selected)
          root.close()
        }
      }
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
            title: root.selected ? root.selected.title : "Plugin customizations"
            meta: {
              if (model.installing) return "Installing skill links…"
              if (model.loading) return "Scanning plugins…"
              if (root.selected) return root.selected.name + " · " + root.selected.status
              return model.message
            }
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
            visible: !root.selected
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

          Column {
            visible: root.selected !== null
            width: parent.width
            spacing: Style.space(12)

            Text {
              visible: root.selected && root.selected.goal !== ""
              width: parent.width
              text: root.selected ? root.selected.goal : ""
              textFormat: Text.PlainText
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              wrapMode: Text.WordWrap
            }
            Text {
              visible: root.selected && root.selected.why !== ""
              width: parent.width
              text: root.selected ? root.selected.why : ""
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }
            Text {
              visible: root.selected && root.selected.files && root.selected.files.length > 0
              width: parent.width
              text: root.selected ? "Files  " + root.selected.files.join(", ") : ""
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }
            Text {
              visible: root.selected && root.selected.detail !== ""
              width: parent.width
              text: root.selected ? root.selected.detail : ""
              textFormat: Text.PlainText
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Row {
              anchors.horizontalCenter: parent.horizontalCenter
              spacing: Style.space(12)
              Button {
                text: "Back"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: root.selectRow(null)
              }
              Button {
                visible: root.selected && root.selected.path !== ""
                text: "Open record"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  model.openRecord(root.selected.path)
                  root.close()
                }
              }
              Button {
                visible: root.actionLabel(root.selected) !== ""
                text: root.actionLabel(root.selected)
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                fontSize: Style.font.caption
                verticalPadding: Style.spacing.controlPaddingY
                onClicked: {
                  model.launchItem(root.selected)
                  root.close()
                }
              }
            }
          }

          StatusSection {
            title: "NEEDS RE-APPLY"
            model: root.rowsFor("stale")
          }
          StatusSection {
            title: "DRAFTS FROM INSTALL"
            model: root.rowsFor("draft")
          }
          StatusSection {
            title: "UNRECORDED EDITS"
            model: root.rowsFor("unrecorded")
          }
          StatusSection {
            title: "UPDATES AVAILABLE"
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
    visible: !root.selected && (model.length > 0 || (showWhenEmpty && emptyText !== ""))
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
      model: section.model ? section.model.length : 0
      MouseArea {
        id: row
        required property int index
        readonly property var item: section.model[index]
        width: section.width
        implicitHeight: Math.max(Style.space(44), labels.implicitHeight + Style.space(16))
        height: implicitHeight
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.selectRow(row.item)

        Rectangle {
          anchors.fill: parent
          radius: Style.cornerRadius
          color: row.containsMouse ? Style.hoverFillFor(root.foreground, Color.accent) : "transparent"
        }
        Column {
          id: labels
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          anchors.leftMargin: Style.space(9)
          anchors.rightMargin: Style.space(28)
          spacing: Style.space(1)
          Text {
            width: parent.width
            text: row.item ? (row.item.name || row.item.pluginId) : ""
            textFormat: Text.PlainText
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            text: row.item ? (row.item.title + (row.item.detail ? " · " + row.item.detail : "")) : ""
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }
        }
        Text {
          anchors.right: parent.right
          anchors.rightMargin: Style.space(9)
          anchors.verticalCenter: parent.verticalCenter
          text: "󰅂"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }
    }
  }
}
