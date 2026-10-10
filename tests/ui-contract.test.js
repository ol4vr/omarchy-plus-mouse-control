const test = require("node:test")
const assert = require("node:assert/strict")
const fs = require("node:fs")
const path = require("node:path")

const root = path.resolve(__dirname, "..")
const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"))
const bar = fs.readFileSync(path.join(root, "BarWidget.qml"), "utf8")
const panel = fs.readFileSync(path.join(root, "Panel.qml"), "utf8")
const helper = fs.readFileSync(path.join(root, "mouse-control"), "utf8")

test("manifest identifies the owned left-bar widget", () => {
  assert.equal(manifest.id, "io.github.ol4vr.mouse-control")
  assert.equal(manifest.barWidget.defaultSection, "left")
  assert.deepEqual(manifest.kinds, ["bar-widget"])
})

test("bar presents only the selected battery beside the mouse icon", () => {
  assert.match(bar, /activeDevice\.battery/)
  assert.doesNotMatch(bar, /var dpi|activeDevice\.dpi/)
  assert.match(bar, /leadingGap: Style\.spaceReal\(8\)/)
  assert.match(bar, /text: "󰍽"\s+color: button\.foreground/)
  assert.match(bar, /color: root\.batteryWarning \? Color\.urgent : button\.foreground/)
  assert.match(bar, /batteryWarning: Model\.batteryWarning\(activeDevice, warningThreshold\)/)
  assert.match(bar, /source: Qt\.resolvedUrl\("Panel\.qml"\)/)
  assert.match(bar, /interval: 5000/)
})

test("popup offers manual device selection and explicit DPI presets", () => {
  assert.match(panel, /\["naga", "logitech"\]/)
  assert.match(panel, /\[600, 800, 1000, 1200, 1400, 1600\]/)
  assert.match(panel, /columns: 3/)
  assert.match(panel, /selected: root\.activeDevice && root\.activeDevice\.dpi === modelData/)
  assert.match(panel, /\["set-dpi", activeDevice\.id/)
  assert.doesNotMatch(panel, /\bRGB\b|lighting|button mapping/i)
})

test("popup presents the persisted warning threshold as compact status", () => {
  assert.match(panel, /LOW-BATTERY WARNING/)
  assert.match(panel, /Notify once at or below/)
  assert.match(panel, /warningThreshold \+ "%"/)
  assert.doesNotMatch(panel, /\[15, 20, 25\]/)
  assert.doesNotMatch(panel, /Critical notification/)
})

test("popup keeps balanced content insets and selected-device emphasis", () => {
  assert.match(panel, /anchors\.leftMargin: Style\.space\(16\)/)
  assert.match(panel, /anchors\.rightMargin: Style\.space\(16\)/)
  assert.match(panel, /SELECTED DEVICE/)
  assert.match(panel, /height: selectedDeviceContent\.implicitHeight \+ Style\.space\(24\)/)
  assert.match(panel, /text: "SELECTED DEVICE"\s+color: root\.foreground/)
  assert.match(panel, /root\.activeDevice\.name : "Mouse unavailable"\s+color: Color\.accent/)
})

test("popup accents the selected DPI and presents explicit device telemetry", () => {
  assert.match(panel, /foreground: selected \? Color\.accent/)
  assert.match(panel, /bordered: selected/)
  assert.match(panel, /text: "󰍽"[\s\S]*id: selectedDpi[\s\S]*Model\.dpiText\(root\.activeDevice\)/)
  assert.match(panel, /text: "󰁹"[\s\S]*text: "Battery"[\s\S]*id: selectedBattery/)
  assert.match(panel, /id: selectedBattery[\s\S]*batteryWarning\(root\.activeDevice, root\.warningThreshold\)[\s\S]*\? Color\.urgent/)
  assert.match(panel, /id: selectedCharging[\s\S]*"Charging status unavailable"[\s\S]*"Charging" : "Not charging"/)
  assert.match(panel, /id: warningValue[\s\S]*color: root\.foreground/)
})

test("helper has no input monitor, RGB path, or mouse-disable operation", () => {
  assert.doesNotMatch(helper, /evdev|\/dev\/input|openrgb|set-led/i)
  assert.doesNotMatch(helper, /disable-device|device.*enabled/i)
  assert.match(helper, /ratbagctl/)
  assert.match(helper, /SetDpi/)
  assert.match(helper, /omarchy-notification-send/)
})
