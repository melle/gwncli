# Grandstream GWN ubus API

Notes on the undocumented JSON-RPC API of Grandstream GWN access points (standalone /
master mode), as used by the web UI and reverse engineered from a browser capture of a
GWN76xx master (firmware ~1.0.25.x, January 2025 web assets).

All calls are `POST` requests against the master AP, with a JSON-RPC 2.0 body:

```
POST https://<ap>/ubus/<object>.<method>
Content-Type: application/json
```

```json
{
  "id": 1,
  "jsonrpc": "2.0",
  "method": "call",
  "params": ["<session token>", "<object>", "<method>", { ...arguments... }]
}
```

- The URL path repeats the `object.method` pair from `params`.
- Responses have the shape `{"jsonrpc": "2.0", "id": n, "result": [<status>, {<payload>}]}`.
  Status `0` means success.
- The web UI sometimes batches several requests into one POST by sending a JSON *array*
  of request objects (the response is then an array as well). Single requests work fine.
- The AP uses a self-signed TLS certificate.

## Authentication

### `session.login`

Path: `/ubus/session.login`. Use the all-zero token when not yet logged in.

```json
{
  "id": 1,
  "jsonrpc": "2.0",
  "method": "call",
  "params": [
    "00000000000000000000000000000000",
    "session", "login",
    { "username": "admin", "password": "<password>" }
  ]
}
```

The response payload contains the session token (32 hex chars) that must be passed as
`params[0]` in all subsequent calls:

```json
{ "jsonrpc": "2.0", "id": 1, "result": [0, { "session": "5d483ae04ed45bf22f0149cb367..." }] }
```

## Configuration (UCI)

The whole AP configuration lives in the UCI namespace `grandstream` and is manipulated
with generic `uci` calls, followed by an apply/confirm handshake.

### `uci.get` — read the configuration

Path: `/ubus/uci.get`, arguments `{ "config": "grandstream" }`.

The response payload is `{ "values": { "<section-name>": { ... } } }`. Every section
carries the meta keys `.type`, `.name`, `.index`, `.anonymous`. Interesting section
types:

| `.type`           | meaning                                                        |
|-------------------|----------------------------------------------------------------|
| `additional_ssid` | an SSID definition; `id`/`.name` (i.e. `ssid0`) is the ssid-id referenced elsewhere, `ssid` is the human readable network name |
| `bwctrl-rule`     | a bandwidth rule (see below)                                   |
| `ap`              | one section per access point, named by its bare MAC            |
| `client`          | known client devices, named by their bare lowercase MAC        |
| `zone`, `radio`, `mesh`, ... | further settings, not needed by gwncli             |

A bandwidth rule section looks like:

```json
"rule1": {
  ".anonymous": false, ".type": "bwctrl-rule", ".name": "rule1", ".index": 30,
  "enabled": "1",
  "type": "mac",
  "id": "F8:34:41:41:E6:05",
  "ssid_id": "ssid0",
  "urate": "1000Mbps",
  "drate": "32Kbps"
}
```

- `id` is the MAC address, uppercased and colon-separated.
- `ssid_id` references an `additional_ssid` section by its `id` (i.e. `ssid0`).
- `urate`/`drate` (upload/download limit) only accept the exact units `Kbps`/`Mbps`,
  case-sensitive, i.e. `32Kbps`, `1000Mbps`.
- Rule sections are conventionally named `rule<n>`.

### `uci.add` — create a section

Path: `/ubus/uci.add`, i.e. a new bandwidth rule:

```json
{ "config": "grandstream", "type": "bwctrl-rule", "name": "rule11",
  "values": { "id": "AA:BB:CC:DD:EE:FF", "enabled": 1, "type": "mac",
              "urate": "512Kbps", "drate": "1Mbps", "ssid_id": "ssid0" } }
```

### `uci.set` — modify a section

Path: `/ubus/uci.set`, arguments `{ "config": "grandstream", "section": "rule11", "values": { ... } }`.

### `uci.delete` — remove a section

Path: `/ubus/uci.delete`, arguments `{ "config": "grandstream", "section": "rule11" }`.

### `uci.apply` / `uci.confirm` — commit changes

Changes only become active after `uci.apply` (path `/ubus/uci.apply`, arguments
`{ "timeout": 10, "rollback": true }`) and must then be acknowledged with `uci.confirm`
(path `/ubus/uci.confirm`, arguments `{}`) — otherwise the AP rolls the change back
after the timeout, like OpenWrt does.

## Clients

### `controller.core.get_clients_count`

Path: `/ubus/controller.core.get_clients_count`, arguments `{}`.

```json
{ "jsonrpc": "2.0", "id": 2, "result": [0, {
  "count": 28, "online": 22,
  "online_wired": 0, "online_2g4": 12, "online_5g": 10,
  "clients_wired": 0, "clients_2g4": 16, "clients_5g": 12 } ] }
```

`count` includes clients that are currently offline but still known to the AP.

### `controller.core.get_clients_range`

Path: `/ubus/controller.core.get_clients_range`. This is what the web UI's *Clients*
page calls (paginated). Arguments as observed:

```json
{ "start": 0, "end": 10, "wireless": 2, "radio": 0, "associated_ap": "" }
```

- `start`/`end`: pagination window; fetch `get_clients_count` first and use
  `end = count` to get everything in one call.
- `wireless: 2`, `radio: 0`, `associated_ap: ""`: constant filter values sent by the
  web UI ("all clients on all radios of all APs").

Response payload: `{ "clients": [ ... ], "count": <total>, "online": <online> }`, one
object per client:

```json
{
  "wired": 0,
  "online": 1,
  "associated_ap": "c074ad000001",
  "client_mac": "7235cf2ab237",
  "zone": "Default",
  "ssid": "MyWifi",
  "client_ipv4": "192.168.7.55",
  "client_ipv6": "fd47:41f5:ba72::4dd:ea99:7e3d:c209",
  "client_host": "iPhone",
  "assoctime": "00:08:52",
  "channel": 1,
  "channel_class": 2,
  "rssi": -52,
  "tx_rate": 114,
  "rx_rate": 114,
  "sta_mode": "11AXG_HE20",
  "last_seen": 1784490717,
  "manufacture": "",
  "hostname": "iPhone",
  "os": "",
  "release": 0,
  "throughput": { "tx_bps": 1857, "rx_bps": 1939, "tx_pps": 11, "rx_pps": 11 },
  "aggregate": { "tx_bytes": "33940301", "tx_packets": "80352",
                 "rx_bytes": "75687343", "rx_packets": "65287" }
}
```

Pitfalls:

- `client_mac` and `associated_ap` are bare lowercase hex **without separators** —
  unlike the `id` field of bandwidth rules (`AA:BB:CC:DD:EE:FF`).
- `ssid` is the network *name*; to reference the SSID in a bandwidth rule it must be
  mapped to the `additional_ssid` section id (`ssid0`, ...) via `uci.get`.
- `last_seen` is a unix timestamp; `online: 0` entries are recently seen but currently
  disconnected clients.

## Other observed endpoints (not used by gwncli)

The web UI also calls, among others: `switch_role.get_role`, `luci2.ui.menu`,
`session.access`, `system.info`, `service.status`, `firmware_check.check`,
`controller.core.get_ap_count`, `controller.core.status_channel`,
`controller.core.get_bridges`, `stats.get_top_aps`, `stats.get_top_ssids`,
`stats.get_top_clients`, `uns.get_priority_count`, `uci.changes`.
