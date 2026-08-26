import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui

// Bar entry for a details panel. Quattro summons/hides this widget, not Panel.qml.
BarWidget {
  id: root
  moduleName: "djschnei21.plugin-maleability"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property bool attention: panelLoader.item ? panelLoader.item.attention === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.settings = root.settings
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "djschnei21.plugin-maleability"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string {
      if (panelLoader.item) panelLoader.item.refreshModel()
      return "ok"
    }
    function debug(): string {
      if (panelLoader.item) return panelLoader.item.debugState()
      return JSON.stringify({ v: "1.0.4", loaded: false })
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰠱"
    tooltipText: root.attention ? "Plugin Maleability needs attention" : "Plugin Maleability"
    active: root.attention
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton || buttonCode === Qt.MiddleButton) {
        if (panelLoader.item) panelLoader.item.refreshModel()
      } else {
        root.toggle()
      }
    }
  }
}
