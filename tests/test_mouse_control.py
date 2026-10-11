from __future__ import annotations

import importlib.machinery
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader(
    "mouse_control", str(ROOT / "mouse-control")
)
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC is not None
mouse_control = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(mouse_control)


def battery_device(
    device_id: str,
    battery: int | None,
    *,
    charging: bool | None = False,
    connected: bool = True,
) -> dict[str, object]:
    name = "Razer Naga V3 Pro" if device_id == "naga" else "Logitech PRO X Superlight"
    return {
        "id": device_id,
        "name": name,
        "connected": connected,
        "battery": battery,
        "charging": charging,
    }


class MouseControlTests(unittest.TestCase):
    def test_naga_snapshot_maps_only_observed_status(self) -> None:
        snapshot = {
            "status": "available",
            "transport": "hyperspeed",
            "error": None,
            "mode_error": None,
            "observed": {
                "dpi": [1800, 1800],
                "battery_percent": 48.0,
                "charging": False,
            },
        }
        response = repr((json.dumps(snapshot),))

        with patch.object(mouse_control, "gdbus_call", return_value=response):
            device = mouse_control.naga_status(1600)

        self.assertEqual(device["dpi"], 1800)
        self.assertEqual(device["battery"], 48)
        self.assertEqual(device["charging"], False)
        self.assertEqual(device["preferred_dpi"], 1600)
        self.assertTrue(device["dpi_write"])

    def test_logitech_battery_remains_real_when_dpi_backend_is_missing(self) -> None:
        with (
            patch.object(
                mouse_control, "power_supply_status", return_value=(True, 60, None)
            ),
            patch.object(mouse_control, "logitech_wired_connected", return_value=False),
            patch.object(mouse_control.shutil, "which", return_value=None),
        ):
            device = mouse_control.logitech_status()

        self.assertEqual(device["battery"], 60)
        self.assertIsNone(device["charging"])
        self.assertIsNone(device["dpi"])
        self.assertFalse(device["dpi_write"])
        self.assertEqual(
            device["error"], "Wireless DPI control unavailable (libratbag)"
        )

    def test_packaged_ratbag_device_exposes_wired_logitech_dpi(self) -> None:
        def ratbag_output(arguments: list[str]) -> str:
            if arguments == ["ratbagctl", "list"]:
                return "warbling-mara: Logitech PRO X Superlight"
            if arguments == [
                "ratbagctl",
                "warbling-mara",
                "profile",
                "0",
                "dpi",
                "get",
            ]:
                return "1600dpi"
            self.fail(f"unexpected ratbag command: {arguments}")

        with (
            patch.object(
                mouse_control, "power_supply_status", return_value=(True, 60, None)
            ),
            patch.object(mouse_control, "logitech_wired_connected", return_value=True),
            patch.object(
                mouse_control.shutil, "which", return_value="/usr/bin/ratbagctl"
            ),
            patch.object(mouse_control, "run", side_effect=ratbag_output),
        ):
            device = mouse_control.logitech_status()

        self.assertEqual(device["dpi"], 1600)
        self.assertTrue(device["dpi_write"])
        self.assertEqual(device["connection"], "wired")
        self.assertIsNone(device["error"])

    def test_wired_usb_identity_takes_precedence_over_receiver_telemetry(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            usb_devices = Path(directory)
            receiver = usb_devices / "1-2"
            receiver.mkdir()
            (receiver / "idVendor").write_text("046d\n", encoding="utf-8")
            (receiver / "idProduct").write_text("c547\n", encoding="utf-8")
            wired = usb_devices / "1-8"
            wired.mkdir()
            (wired / "idVendor").write_text("046d\n", encoding="utf-8")
            (wired / "idProduct").write_text("c094\n", encoding="utf-8")

            self.assertTrue(mouse_control.logitech_wired_connected(usb_devices))

    def test_receiver_without_wired_usb_remains_lightspeed(self) -> None:
        with (
            patch.object(
                mouse_control, "power_supply_status", return_value=(True, 60, None)
            ),
            patch.object(mouse_control, "logitech_wired_connected", return_value=False),
            patch.object(mouse_control, "ratbag_device", return_value=None),
        ):
            device = mouse_control.logitech_status()

        self.assertEqual(device["connection"], "lightspeed")
        self.assertFalse(device["dpi_write"])
        self.assertEqual(
            device["error"], "Wireless DPI control unavailable (libratbag)"
        )

    def test_explicit_naga_dpi_write_persists_only_after_verification(self) -> None:
        snapshot = {"status": "available", "observed": {"dpi": [1800, 1800]}}
        response = repr((json.dumps(snapshot),))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "preferences.json"
            with (
                patch.dict(os.environ, {"MOUSE_CONTROL_STATE_PATH": str(path)}),
                patch.object(
                    mouse_control, "gdbus_call", return_value=response
                ) as call,
                patch.object(
                    mouse_control, "status_document", return_value={"schema": 1}
                ),
            ):
                result = mouse_control.set_dpi("naga", "1800")

            self.assertEqual(result, {"schema": 1})
            call.assert_called_once_with("SetDpi", 1800, 1800)
            saved = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(saved["preferred_dpi"], {"naga": 1800})
            self.assertEqual(saved["selected"], "naga")

    def test_logitech_write_targets_only_the_selected_ratbag_device(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "preferences.json"
            with (
                patch.dict(os.environ, {"MOUSE_CONTROL_STATE_PATH": str(path)}),
                patch.object(
                    mouse_control, "ratbag_device", return_value="warbling-mara"
                ),
                patch.object(mouse_control, "ratbag_dpi", return_value=1200),
                patch.object(mouse_control, "run", return_value="") as run,
                patch.object(
                    mouse_control, "status_document", return_value={"schema": 1}
                ),
            ):
                mouse_control.set_dpi("logitech", "1200")

            run.assert_called_once_with(
                [
                    "ratbagctl",
                    "warbling-mara",
                    "profile",
                    "0",
                    "dpi",
                    "set",
                    "1200",
                ]
            )
            saved = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(saved["preferred_dpi"], {"logitech": 1200})

    def test_invalid_dpi_never_calls_a_backend(self) -> None:
        with (
            patch.object(mouse_control, "gdbus_call") as call,
            self.assertRaisesRegex(
                mouse_control.MouseControlError, "from 100 through 50000"
            ),
        ):
            mouse_control.set_dpi("naga", "99")
        call.assert_not_called()

    def test_warning_is_sent_once_at_fifteen_percent(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "preferences.json"
            with (
                patch.dict(os.environ, {"MOUSE_CONTROL_STATE_PATH": str(path)}),
                patch.object(
                    mouse_control, "send_battery_notification", return_value=True
                ) as send,
            ):
                preferences = mouse_control.default_preferences()
                mouse_control.evaluate_battery_notifications(
                    [battery_device("naga", 15)], preferences
                )
                mouse_control.evaluate_battery_notifications(
                    [battery_device("naga", 15)], preferences
                )
                mouse_control.evaluate_battery_notifications(
                    [battery_device("naga", 9)], preferences
                )

            send.assert_called_once_with("Razer Naga V3 Pro", 15)
            saved = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(saved["notification_levels"], {"logitech": 0, "naga": 1})

    def test_notification_state_is_independent_for_each_mouse(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "preferences.json"
            with (
                patch.dict(os.environ, {"MOUSE_CONTROL_STATE_PATH": str(path)}),
                patch.object(
                    mouse_control, "send_battery_notification", return_value=True
                ) as send,
            ):
                preferences = mouse_control.default_preferences()
                mouse_control.evaluate_battery_notifications(
                    [battery_device("naga", 15), battery_device("logitech", 15)],
                    preferences,
                )

            self.assertEqual(send.call_count, 2)
            saved = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(saved["notification_levels"], {"logitech": 1, "naga": 1})

    def test_charging_and_unavailable_batteries_do_not_notify(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "preferences.json"
            with (
                patch.dict(os.environ, {"MOUSE_CONTROL_STATE_PATH": str(path)}),
                patch.object(mouse_control, "send_battery_notification") as send,
            ):
                preferences = mouse_control.default_preferences()
                mouse_control.evaluate_battery_notifications(
                    [
                        battery_device("naga", 8, charging=True),
                        battery_device("logitech", None),
                    ],
                    preferences,
                )

            send.assert_not_called()
            self.assertFalse(path.exists())

    def test_recovery_above_warning_margin_rearms_notification(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "preferences.json"
            with (
                patch.dict(os.environ, {"MOUSE_CONTROL_STATE_PATH": str(path)}),
                patch.object(
                    mouse_control, "send_battery_notification", return_value=True
                ) as send,
            ):
                preferences = mouse_control.default_preferences()
                mouse_control.evaluate_battery_notifications(
                    [battery_device("naga", 15)], preferences
                )
                mouse_control.evaluate_battery_notifications(
                    [battery_device("naga", 20, charging=True)], preferences
                )
                mouse_control.evaluate_battery_notifications(
                    [battery_device("naga", 15)], preferences
                )

            self.assertEqual(send.call_count, 2)

    def test_notification_uses_omarchy_swaync_path_and_cable_reminder(self) -> None:
        with patch.object(mouse_control, "run", return_value="") as run:
            sent = mouse_control.send_battery_notification(
                "Logitech PRO X Superlight", 15
            )

        self.assertTrue(sent)
        arguments = run.call_args.args[0]
        self.assertEqual(arguments[0], "omarchy-notification-send")
        self.assertIn("normal", arguments)
        self.assertIn("Logitech PRO X Superlight battery low", arguments)
        self.assertIn(
            "Logitech PRO X Superlight is at 15%. Connect the USB charging cable.",
            arguments,
        )

    def test_legacy_twenty_percent_default_migrates_to_fifteen(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "preferences.json"
            path.write_text(
                json.dumps(
                    {
                        "schema": 1,
                        "selected": "logitech",
                        "preferred_dpi": {"naga": 1800},
                        "warning_threshold": 20,
                        "notification_levels": {"naga": 2, "logitech": 1},
                    }
                ),
                encoding="utf-8",
            )

            preferences = mouse_control.load_preferences(path)

            self.assertEqual(preferences["schema"], 2)
            self.assertEqual(preferences["selected"], "logitech")
            self.assertEqual(preferences["preferred_dpi"], {"naga": 1800})
            self.assertEqual(preferences["warning_threshold"], 15)
            self.assertEqual(
                preferences["notification_levels"], {"naga": 0, "logitech": 0}
            )
            self.assertEqual(json.loads(path.read_text(encoding="utf-8")), preferences)

    def test_warning_threshold_setting_persists_and_rearms_both_mice(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "preferences.json"
            preferences = mouse_control.default_preferences()
            preferences["notification_levels"] = {"naga": 1, "logitech": 1}
            mouse_control.save_preferences(preferences, path)
            with patch.dict(os.environ, {"MOUSE_CONTROL_STATE_PATH": str(path)}):
                mouse_control.set_warning_threshold("25")

            saved = json.loads(path.read_text(encoding="utf-8"))
            self.assertEqual(saved["warning_threshold"], 25)
            self.assertEqual(saved["notification_levels"], {"logitech": 0, "naga": 0})

            with self.assertRaisesRegex(
                mouse_control.MouseControlError, "from 1 through 50"
            ):
                mouse_control.set_warning_threshold("0")


if __name__ == "__main__":
    unittest.main()
