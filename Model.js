// Pure Mouse Control presentation model, kept Qt-free for Node tests.

function isObject(value) {
  return typeof value === "object" && value !== null && !Array.isArray(value)
}

function normalizeDevice(value) {
  if (!isObject(value) || (value.id !== "naga" && value.id !== "logitech")) return null
  return {
    id: value.id,
    name: String(value.name || "Unknown mouse"),
    connected: value.connected === true,
    available: value.available === true,
    connection: String(value.connection || "unavailable"),
    battery: finiteInteger(value.battery),
    charging: typeof value.charging === "boolean" ? value.charging : null,
    dpi: finiteInteger(value.dpi),
    preferredDpi: finiteInteger(value.preferred_dpi),
    dpiWrite: value.dpi_write === true,
    error: value.error ? String(value.error) : ""
  }
}

function parseStatus(raw) {
  var document
  try {
    document = JSON.parse(String(raw))
  } catch (error) {
    return null
  }
  if (!isObject(document) || document.schema !== 1 || !Array.isArray(document.devices))
    return null
  var devices = []
  for (var i = 0; i < document.devices.length; i++) {
    var device = normalizeDevice(document.devices[i])
    if (device) devices.push(device)
  }
  if (devices.length !== 2) return null
  return {
    selected: document.selected === "logitech" ? "logitech" : "naga",
    warningThreshold: finiteInteger(document.warning_threshold) || 20,
    criticalThreshold: finiteInteger(document.critical_threshold) || 10,
    devices: devices
  }
}

function deviceById(status, deviceId) {
  if (!status || !Array.isArray(status.devices)) return null
  for (var i = 0; i < status.devices.length; i++)
    if (status.devices[i].id === deviceId) return status.devices[i]
  return null
}

function selectedDevice(status) {
  return status ? deviceById(status, status.selected) : null
}

function dpiText(device) {
  return device && device.dpi !== null ? device.dpi + " DPI" : "DPI unavailable"
}

function batteryText(device) {
  return device && device.battery !== null ? device.battery + "%" : "Battery unavailable"
}

function lowBattery(device) {
  return !!device && device.battery !== null && device.battery <= 20 && device.charging !== true
}

function connectionText(device) {
  if (!device || !device.connected) return "Disconnected"
  if (!device.available) return "Connected · control unavailable"
  var value = device.connection === "hyperspeed" ? "HyperSpeed" :
    device.connection === "lightspeed" ? "LIGHTSPEED" : device.connection
  return "Connected · " + value
}

function tooltipText(device) {
  if (!device) return "Mouse Control · loading"
  return device.name + "\n" + dpiText(device) + " · " + batteryText(device) +
    "\nClick for mouse controls"
}

function finiteInteger(value) {
  if (value === null || value === undefined || value === "") return null
  var number = Number(value)
  return isFinite(number) ? Math.round(number) : null
}

if (typeof module !== "undefined") {
  module.exports = {
    parseStatus: parseStatus,
    deviceById: deviceById,
    selectedDevice: selectedDevice,
    dpiText: dpiText,
    batteryText: batteryText,
    lowBattery: lowBattery,
    connectionText: connectionText,
    tooltipText: tooltipText
  }
}
