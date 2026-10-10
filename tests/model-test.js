#!/usr/bin/env node

"use strict"

const assert = require("node:assert/strict")
const Model = require("../Model.js")

const status = Model.parseStatus(JSON.stringify({
  schema: 1,
  selected: "naga",
  warning_threshold: 15,
  auto_switch: false,
  disable_supported: false,
  devices: [
    {
      id: "naga",
      name: "Razer Naga V3 Pro",
      connected: true,
      available: true,
      connection: "hyperspeed",
      battery: 14,
      charging: false,
      dpi: 1800,
      preferred_dpi: 1600,
      dpi_write: true
    },
    {
      id: "logitech",
      name: "Logitech PRO X Superlight",
      connected: true,
      available: true,
      connection: "lightspeed",
      battery: 60,
      charging: null,
      dpi: null,
      preferred_dpi: null,
      dpi_write: false,
      error: "DPI control requires libratbag"
    }
  ]
}))

assert.ok(status)
assert.equal(Model.selectedDevice(status).id, "naga")
assert.equal(status.warningThreshold, 15)
assert.equal(Model.dpiText(Model.selectedDevice(status)), "1800 DPI")
assert.equal(Model.batteryText(Model.selectedDevice(status)), "14%")
assert.equal(Model.lowBattery(Model.selectedDevice(status)), true)
assert.equal(Model.criticalBattery(Model.selectedDevice(status)), false)
assert.equal(Model.connectionText(Model.selectedDevice(status)), "Connected · HyperSpeed")
assert.match(
  Model.tooltipText(Model.selectedDevice(status)),
  /Razer Naga V3 Pro\n1800 DPI · 14%/
)
assert.equal(Model.deviceById(status, "logitech").dpi, null)
assert.equal(Model.dpiText(Model.deviceById(status, "logitech")), "DPI unavailable")
assert.equal(Model.lowBattery(Model.deviceById(status, "logitech")), false)
status.devices[0].battery = 10
assert.equal(Model.criticalBattery(Model.selectedDevice(status)), true)
status.devices[0].charging = true
assert.equal(Model.criticalBattery(Model.selectedDevice(status)), true)
status.devices[0].battery = 11
assert.equal(Model.criticalBattery(Model.selectedDevice(status)), false)
assert.equal(Model.parseStatus("not json"), null)

console.log("Mouse Control model tests: PASS")
