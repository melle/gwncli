# gwncli - control Grandstream WiFi access points

A Swift command-line tool to programmatically manage bandwidth rules on Grandstream WiFi access points. Perfect for home automation, parental controls, or dynamic network management.

## Features

- ✅ **List bandwidth rules** - View all configured rules with their settings
- ✅ **Add/Update rules** - Create new rules or modify existing ones
- ✅ **Delete rules** - Remove rules by name or MAC address
- ✅ **Aliases support** - Use friendly names instead of MAC addresses
- ✅ **Configurable logging** - 5 log levels for debugging
- ✅ **Cross-platform** - Works on macOS and Linux
- ✅ **Modern Swift** - Built with Swift 6.2 and structured concurrency

## Use Case

I want to throttle the bandwidth of specific wifi devices using my home automation system. Therefore I need a cli tool to change bandwidth rules programmatically. Grandstream supports schedules, but I need to (un)throttle things on demand.

Why would anyone do that? Well, think of the Apple TV. It still works, but cannot stream movies at 96kb/s. Also iPads, smartphones etc. It works somehow, but YouTube, TikTok etc. become unusable at low bandwidths. Did you say 'bad parenting'? Well, I call it a challenge for my kids to learn some things about networking 😬

## Requirements

- **macOS**: macOS 13+ with Swift 6.2+ (Xcode 16+)
- **Linux**: Swift 6.2+ with FoundationNetworking
- **Access Point**: Grandstream GWN series AP

## Building

```bash
swift build
```

For release build:
```bash
swift build -c release
```

## Installation

```bash
# Build release version
swift build -c release

# Copy to a location in your PATH
cp .build/release/gwncli /usr/local/bin/
```

## Usage

### List all bandwidth rules

```bash
gwncli list \
  --url "https://gwn_c074ad7b2950.local" \
  --username admin \
  --password yourpassword
```

### Add or update a bandwidth rule

```bash
gwncli set \
  --url "https://gwn_c074ad7b2950.local" \
  --username admin \
  --password yourpassword \
  --mac AA:BB:CC:DD:EE:FF \
  --ssid ssid0 \
  --drate 96Kbps \
  --urate 96Kbps
```

**Note:** Upload/download rates must be expressed as `Mbps` or `Kbps` (case-sensitive).

### Delete a bandwidth rule

By rule name:
```bash
gwncli delete \
  --url "https://gwn_c074ad7b2950.local" \
  --username admin \
  --password yourpassword \
  --rule-name rule4
```

By MAC address (deletes all rules for that device):
```bash
gwncli delete \
  --url "https://gwn_c074ad7b2950.local" \
  --username admin \
  --password yourpassword \
  --mac AA:BB:CC:DD:EE:FF
```

### Using aliases

Create a file `~/.gwnaliases.txt` with MAC-to-name mappings:

```
AA:BB:CC:DD:EE:FF  Kids-iPad
11:22:33:44:55:66  AppleTV
```

Then use the `--aliases` flag:

```bash
gwncli list \
  --url "https://gwn_c074ad7b2950.local" \
  --username admin \
  --password yourpassword \
  --aliases ~/.gwnaliases.txt
```

Output will show friendly names:
```
rule0	[enabled] 	U: 96Kbps	D:96Kbps	mac: aa:bb:cc:dd:ee:ff (Kids-iPad)     	SSID: ssid0 "Main-WiFi"
```

### Log levels

Use `--log-level` to control verbosity (1=fatal, 5=debug):

```bash
gwncli list --url "..." --username admin --password pass --log-level 5
```

## Linux Support

Grandstream APs use self-signed certificates. On macOS, the tool ignores certificate warnings. On Linux, `URLCredential(trust:)` is unavailable.

**Workaround:** Set up nginx as a reverse proxy with `proxy_ssl_verify off;`:

```nginx
server {
    listen 443 ssl;
    server_name gwn-proxy.local;
    
    location / {
        proxy_pass https://gwn_c074ad7b2950.local;
        proxy_ssl_verify off;
    }
}
```

Then point gwncli to your proxy instead.

## Architecture

Built with modern Swift features:
- **Swift 6.2** with strict concurrency checking
- **Structured concurrency** using async/await
- **Sendable types** for thread-safe data sharing
- **Fluent API** for elegant async operation chaining
- **No external reactive frameworks** - uses native Swift concurrency

## Development

Run tests:
```bash
swift test
```

The test suite includes JSON parsing tests and integration test helpers.

## Contributing

This is a personal project for my own use, but I'm happy to receive feedback, bug reports, or suggestions! Feel free to open an issue if you find something that could be improved.

## License

MIT License - see LICENSE file for details.

## Disclaimer

⚠️ **Use at your own risk.** This tool interfaces with undocumented APIs of Grandstream devices. Always test changes in a non-production environment first. The author is not responsible for any issues that may arise from using this software.
