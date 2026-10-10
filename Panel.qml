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
  readonly property var presets: [800, 1200, 1600, 1800, 2400, 3200]

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
            color: Model.criticalBattery(root.activeDevice) ? Color.urgent : Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              text: "Mouse Control"
              color: Color.popups.text
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            Text {
              text: root.activeDevice ? Model.connectionText(root.activeDevice) : "Loading…"
              color: root.activeDevice && root.activeDevice.connected
                ? root.foreground : Color.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
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

        Rectangle {
          width: parent.width
          height: selectedDeviceContent.implicitHeight + Style.space(24)
          radius: Style.cornerRadius
          color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.06)
          border.width: 1
          border.color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.24)

          Row {
            id: selectedDeviceContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(12)

            Rectangle {
              width: Style.space(42)
              height: width
              anchors.verticalCenter: parent.verticalCenter
              radius: width / 2
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.12)

              Text {
                anchors.centerIn: parent
                text: "󰍽"
                color: Model.criticalBattery(root.activeDevice)
                  ? Color.urgent : Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.heading
              }
            }

            Column {
              width: parent.width - Style.space(54)
              spacing: Style.space(3)

              Text {
                text: "SELECTED DEVICE"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              Text {
                width: parent.width
                text: root.activeDevice ? root.activeDevice.name : "Mouse unavailable"
                color: Color.popups.text
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
                elide: Text.ElideRight
              }

              Row {
                width: parent.width

                Text {
                  id: selectedDpi
                  anchors.verticalCenter: parent.verticalCenter
                  text: Model.dpiText(root.activeDevice)
                  color: Color.popups.text
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.title
                  font.bold: true
                }

                Item {
                  width: parent.width - selectedDpi.implicitWidth
                    - selectedBattery.implicitWidth
                  height: 1
                }

                Text {
                  id: selectedBattery
                  anchors.verticalCenter: parent.verticalCenter
                  text: Model.batteryText(root.activeDevice)
                    + (root.activeDevice && root.activeDevice.charging === true
                      ? " · Charging" : "")
                  color: Model.criticalBattery(root.activeDevice) ? Color.urgent
                    : Model.lowBattery(root.activeDevice, root.warningThreshold)
                      ? Color.accent : root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  font.bold: Model.criticalBattery(root.activeDevice)
                }
              }

              Text {
                visible: root.activeDevice && root.activeDevice.preferredDpi !== null
                text: "Preferred: "
                  + (root.activeDevice ? root.activeDevice.preferredDpi : "—") + " DPI"
                color: Qt.rgba(root.foreground.r, root.foreground.g,
                  root.foreground.b, 0.62)
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
                color: Color.accent
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
