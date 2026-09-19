# Home Assistant App: Hexesoft Inim Bridge

Bridge tra centrali antifurto Inim Prime e Home Assistant via MQTT.

![Supports aarch64 Architecture][aarch64-shield]

## About

You can use this app (formerly known as add-on) to connect an **Inim Prime** intruder alarm panel (PR060 / PR120 / PR240 / PR500, firmware 3.x / 4.x) to Home Assistant. The bridge talks to the panel on the local network over the native PRIMELAN protocol (TCP port 6004, AES-128-CBC encrypted) and publishes every zone, area, scenario, output and diagnostic sensor to your MQTT broker using Home Assistant auto-discovery — no manual entity configuration required.

Once running, Home Assistant automatically shows:

- one `binary_sensor` per zone with sub-second responsiveness (motion, door contacts, tamper)
- one `alarm_control_panel` per area for arm/disarm in Away / Home / Disarm modes
- one `switch` for every On/Off scenario pair and every output/siren
- a "Last Event" sensor with a decoded history of the last events (who armed what, from which keypad, when)
- a full diagnostic device with mains/battery/bus voltages, tamper flags, radio jamming and communication faults
- global "Stop Sirens", "Reset Alarm Memory" and "Remove All" buttons

The bridge requires no configuration changes on the panel itself and no cloud services (SIA-IP / Nexus / Inim Cloud) — just LAN reachability of the SmartLAN interface on port 6004.

For installation and configuration details see [DOCS.md](DOCS.md).

[aarch64-shield]: https://img.shields.io/badge/aarch64-yes-green.svg
