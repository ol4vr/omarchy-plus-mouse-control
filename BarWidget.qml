import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "io.github.ol4vr.mouse-control"

  readonly property string helperPath: Quickshell.env("HOME")
    + "/.config/omarchy/plugins/io.github.ol4vr.mouse-control/mouse-control"
  property var status: null
  property string processOutput: ""
  property string processError: ""
  property var pendingCommand: []
  property bool loaded: false
  property color successColor: Color.foreground
  readonly property bool actionRunning: actionProc.running
  readonly property bool busy: statusProc.running || actionProc.running

  readonly property var activeDevice: Model.selectedDevice(status)
  readonly property int warningThreshold: status ? status.warningThreshold : 15
  readonly property color primaryColor: bar ? bar.barForeground : Color.foreground
  readonly property color themeRevision: Color.accent
  readonly property string themeColorsPath: Quickshell.env("HOME")
    + "/.local/state/omarchy/current/theme/colors.toml"
  readonly property real leadingGap: Style.spaceReal(8)
  readonly property string batteryLabel: !activeDevice ? "…"
    : activeDevice.battery === null ? "—" : activeDevice.battery + "%"
  readonly property bool batteryWarning: Model.batteryWarning(activeDevice, warningThreshold)
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item
    ? panelLoader.item.popoutSwitchClosing === true : false

  function refresh() {
    if (!statusProc.running && !actionProc.running) statusProc.running = true
  }

  function acceptStatus(raw) {
    var parsed = Model.parseStatus(raw)
    if (!parsed) {
      processError = "Mouse status could not be read"
      return
    }
    status = parsed
    loaded = true
    processError = ""
  }

  function acceptThemeColors(raw) {
    var match = String(raw || "").match(/^\s*green\s*=\s*["']?(#[0-9A-Fa-f]{6})["']?\s*$/m)
    successColor = match ? match[1] : Color.foreground
  }

  function runAction(arguments) {
    if (actionProc.running || statusProc.running) return
    pendingCommand = [helperPath].concat(arguments)
    processOutput = ""
    processError = ""
    actionProc.command = pendingCommand
    actionProc.running = true
  }

  function open() {
    refresh()
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
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  implicitWidth: button.implicitWidth + leadingGap
  implicitHeight: button.implicitHeight
  onBarChanged: injectPanel()
  onThemeRevisionChanged: themeColorsFile.reload()

  FileView {
    id: themeColorsFile
    path: root.themeColorsPath
    watchChanges: true
    printErrors: false
    onLoaded: root.acceptThemeColors(text())
    onFileChanged: reload()
    onLoadFailed: root.successColor = Color.foreground
  }

  Process {
    id: statusProc
    command: [root.helperPath, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.processOutput = text.trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.processError = text.trim()
    }
    onExited: function(exitCode) {
      if (exitCode === 0) root.acceptStatus(root.processOutput)
      else if (root.processError === "") root.processError = "Mouse service unavailable"
    }
  }

  Process {
    id: actionProc
    command: []
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.processOutput = text.trim()
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.processError = text.trim()
    }
    onExited: function(exitCode) {
      if (exitCode === 0) root.acceptStatus(root.processOutput)
      else if (root.processError === "") root.processError = "Mouse action failed"
      root.pendingCommand = []
    }
  }

  Timer {
    interval: 5000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

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

  WidgetButton {
    id: button
    anchors.top: parent.top
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    width: implicitWidth
    bar: root.bar
    horizontalMargin: 3
    text: ""
    hasVisualContent: true
    labelVisible: false
    fixedWidth: barContent.implicitWidth + scaledHorizontalMargin * 2
    tooltipText: Model.tooltipText(root.activeDevice)

    Row {
      id: barContent
      anchors.centerIn: parent
      spacing: Style.space(4)

      Row {
        spacing: Style.space(1)

        Text {
          text: "󰍽"
          color: button.foreground
          font.family: button.fontFamily
          font.pixelSize: button.fontSize
          renderType: Text.NativeRendering
        }

        Text {
          id: chargingIndicator
          visible: Model.chargingIndicatorVisible(root.activeDevice)
          text: ""
          color: root.successColor
          font.family: button.fontFamily
          font.pixelSize: Style.font.iconSmall
          renderType: Text.NativeRendering
        }
      }

      Text {
        text: root.batteryLabel
        color: root.batteryWarning ? Color.urgent : button.foreground
        font.family: button.fontFamily
        font.pixelSize: button.fontSize
        renderType: Text.NativeRendering

        Behavior on color {
          enabled: !root.bar || root.bar.foregroundAnimationEnabled
          ColorAnimation { duration: 160 }
        }
      }
    }

    foreground: root.primaryColor
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
    }
  }
}
