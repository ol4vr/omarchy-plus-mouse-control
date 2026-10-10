import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.ol4vr.mouse-control"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  readonly property var status: hostWidget ? hostWidget.status : null
  readonly property var activeDevice: Model.selectedDevice(status)
  readonly property int warningThreshold: status ? status.warningThreshold : 15
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property var presets: [600, 800, 1000, 1200, 1400, 1600]

  function open() {
    if (hostWidget) hostWidget.refresh()
    root.controller.show()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function closeForPopoutSwitch() {
    root.close()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function selectDevice(deviceId) {
    if (hostWidget) hostWidget.runAction(["select", deviceId])
  }

  function setDpi(value) {
    if (hostWidget && activeDevice)
      hostWidget.runAction(["set-dpi", activeDevice.id, String(value)])
  }

  function chargingText(device) {
    if (!device || device.charging === null) return "Unavailable"
    return device.charging ? "Charging" : "Not charging"
  }

  function connectionTypeText(device) {
    if (!device || !device.connected) return "Disconnected"
    if (!device.available) return "Control unavailable"
    if (device.connection === "hyperspeed") return "HyperSpeed"
    if (device.connection === "lightspeed") return "LIGHTSPEED"
    return device.connection !== "unavailable" ? device.connection : "Connected"
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: content
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Style.space(16)
        anchors.rightMargin: Style.space(16)
        spacing: Style.spacing.lg

        Row {
          width: parent.width
          spacing: Style.space(12)

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍽"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Mouse Control"
            color: Color.popups.text
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }
        }

        Row {
          width: parent.width
          spacing: Style.space(8)

          Repeater {
            model: ["naga", "logitech"]

            Button {
              required property string modelData
              width: (content.width - Style.space(8)) / 2
              text: modelData === "naga" ? "Naga V3 Pro" : "PRO X Superlight"
              fontFamily: root.fontFamily
              foreground: root.foreground
              accent: Color.accent
              selected: root.status && root.status.selected === modelData
              enabled: hostWidget && !hostWidget.busy
              onClicked: root.selectDevice(modelData)
            }
          }
        }

        PanelSeparator {
          foreground: root.foreground
        }

        Column {
          id: selectedDeviceSection
          width: parent.width
          spacing: Style.space(10)

          Row {
            spacing: Style.space(8)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "󰍽"
              color: Qt.rgba(root.foreground.r, root.foreground.g,
                root.foreground.b, 0.62)
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
            }

            Column {
              spacing: Style.space(2)

              Text {
                text: "SELECTED DEVICE"
                color: Qt.rgba(root.foreground.r, root.foreground.g,
                  root.foreground.b, 0.62)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.letterSpacing: 0.7
              }

              Text {
                text: root.activeDevice ? root.activeDevice.name : "Mouse unavailable"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
                font.bold: true
              }
            }
          }

          Row {
            id: deviceMetrics
            width: parent.width
            spacing: Style.space(8)

            Rectangle {
              id: dpiCard
              width: (deviceMetrics.width - deviceMetrics.spacing) / 2
              height: Style.space(72)
              radius: Math.min(8, Style.cornerRadius)
              color: Qt.rgba(root.foreground.r, root.foreground.g,
                root.foreground.b, 0.05)

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(3)

                Text {
                  text: "DPI"
                  color: Qt.rgba(root.foreground.r, root.foreground.g,
                    root.foreground.b, 0.62)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.7
                }

                Row {
                  spacing: Style.space(5)

                  Text {
                    id: selectedDpiValue
                    text: root.activeDevice && root.activeDevice.dpi !== null
                      ? String(root.activeDevice.dpi) : "—"
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.display
                    font.bold: true
                  }

                  Text {
                    anchors.baseline: selectedDpiValue.baseline
                    text: root.activeDevice && root.activeDevice.dpi !== null
                      ? "DPI" : "Unavailable"
                    color: Qt.rgba(root.foreground.r, root.foreground.g,
                      root.foreground.b, 0.62)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            Rectangle {
              id: batteryCard
              width: (deviceMetrics.width - deviceMetrics.spacing) / 2
              height: dpiCard.height
              radius: dpiCard.radius
              color: dpiCard.color

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(3)

                Text {
                  text: "BATTERY"
                  color: Qt.rgba(root.foreground.r, root.foreground.g,
                    root.foreground.b, 0.62)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.7
                }

                Text {
                  id: selectedBatteryValue
                  text: root.activeDevice && root.activeDevice.battery !== null
                    ? root.activeDevice.battery + "%" : "—"
                  color: Model.batteryWarning(root.activeDevice, root.warningThreshold)
                    ? Color.urgent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                  font.bold: true
                }
              }
            }
          }

          Row {
            id: deviceStatus
            spacing: Style.space(14)

            Row {
              spacing: Style.space(5)

              Text {
                text: "󰂄"
                color: Qt.rgba(root.foreground.r, root.foreground.g,
                  root.foreground.b, 0.62)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                id: chargingStatus
                text: root.chargingText(root.activeDevice)
                color: Qt.rgba(root.foreground.r, root.foreground.g,
                  root.foreground.b, 0.72)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Row {
              spacing: Style.space(5)

              Text {
                text: "󰌘"
                color: Qt.rgba(root.foreground.r, root.foreground.g,
                  root.foreground.b, 0.62)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                id: connectionStatus
                text: root.connectionTypeText(root.activeDevice)
                color: Qt.rgba(root.foreground.r, root.foreground.g,
                  root.foreground.b, 0.72)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.spacing.sm

          PanelSectionHeader {
            text: "DPI PRESETS"
            foreground: root.foreground
          }

          Grid {
            width: parent.width
            columns: 3
            columnSpacing: Style.space(8)
            rowSpacing: Style.space(8)

            Repeater {
              model: root.presets

              Button {
                required property int modelData
                width: (content.width - Style.space(16)) / 3
                text: String(modelData)
                fontFamily: root.fontFamily
                foreground: selected ? Color.accent
                  : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.72)
                accent: Color.accent
                selected: root.activeDevice && root.activeDevice.dpi === modelData
                bordered: selected
                enabled: root.activeDevice && root.activeDevice.dpiWrite
                  && hostWidget && !hostWidget.busy
                onClicked: root.setDpi(modelData)
              }
            }
          }
        }

        Column {
          width: parent.width
          spacing: Style.spacing.sm

          PanelSectionHeader {
            text: "LOW-BATTERY WARNING"
            foreground: root.foreground
          }

          Rectangle {
            width: parent.width
            height: Style.space(44)
            radius: Style.cornerRadius
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.05)
            border.width: 1
            border.color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.14)

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(12)
              anchors.rightMargin: Style.space(12)

              Text {
                id: warningLabel
                anchors.verticalCenter: parent.verticalCenter
                text: "Notify once at or below"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.bodySmall
              }

              Item {
                width: parent.width - warningLabel.implicitWidth - warningValue.implicitWidth
                height: 1
              }

              Text {
                id: warningValue
                anchors.verticalCenter: parent.verticalCenter
                text: root.warningThreshold + "%"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
            }
          }
        }

        Text {
          width: parent.width
          visible: hostWidget && (hostWidget.processError !== "" || hostWidget.actionRunning)
          text: hostWidget && hostWidget.actionRunning
            ? "Applying setting…"
            : hostWidget ? hostWidget.processError : ""
          color: hostWidget && hostWidget.processError !== "" ? Color.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }
      }
    }
  }
}
