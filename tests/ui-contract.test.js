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
  assert.match(bar, /return "󰍽\\u2002" \+ battery/)
  assert.doesNotMatch(bar, /var dpi|activeDevice\.dpi/)
  assert.match(bar, /active: Model\.criticalBattery\(root\.activeDevice\)/)
  assert.match(bar, /criticalBattery\(root\.activeDevice\) \? Color\.urgent : Color\.accent/)
  assert.match(bar, /source: Qt\.resolvedUrl\("Panel\.qml"\)/)
  assert.match(bar, /interval: 5000/)
})

test("popup offers manual device selection and explicit DPI presets", () => {
  assert.match(panel, /\["naga", "logitech"\]/)
  assert.match(panel, /\[800, 1200, 1600, 1800, 2400, 3200\]/)
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
  assert.match(panel, /text: "󰍽"/)
  assert.match(panel, /height: selectedDeviceContent\.implicitHeight \+ Style\.space\(24\)/)
})

test("popup accents the selected DPI and reserves urgent red for critical battery", () => {
  assert.match(panel, /foreground: selected \? Color\.accent/)
  assert.match(panel, /bordered: selected/)
  assert.match(panel, /criticalBattery\(root\.activeDevice\) \? Color\.urgent/)
})

test("helper has no input monitor, RGB path, or mouse-disable operation", () => {
  assert.doesNotMatch(helper, /evdev|\/dev\/input|openrgb|set-led/i)
  assert.doesNotMatch(helper, /disable-device|device.*enabled/i)
  assert.match(helper, /ratbagctl/)
  assert.match(helper, /SetDpi/)
  assert.match(helper, /omarchy-notification-send/)
})
