# gwncli - control Grandstream WiFi access points

A Swift command-line tool to programmatically manage bandwidth rules on Grandstream WiFi access points. Perfect for home automation, parental controls, or dynamic network management.

## Features

- **List bandwidth rules** - View all configured rules with their settings
- **Add/Update rules** - Create new rules or modify existing ones
- **Delete rules** - Remove rules by name or MAC address
- **Throttle randomized MACs** - Automatically limit clients with random ("private") MAC addresses, cron-friendly
- **Aliases support** - Use friendly names instead of MAC addresses
- **Cross-platform** - Works on macOS and Linux

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

### Throttle clients with randomized MAC addresses

Devices using MAC randomization ("private WiFi address") have the *locally administered*
bit set in their MAC. The `throttle-locally-administered` subcommand fetches the AP's
client list and adds a bandwidth rule for every such client that does not have one yet:

```bash
gwncli throttle-locally-administered \
  --url "https://gwn_c074ad7b2950.local" \
  --username admin \
  --password yourpassword
```

- Default limits are `32Kbps` down / `1000Mbps` up; override with `--drate`/`--urate`.
- The SSID for new rules is resolved from the SSID the client is connected to; use
  `--ssid ssid0` to force one.
- `--dry-run` prints what would be throttled without changing anything.
- The command prints one line per newly created rule and **nothing at all** when there
  is nothing to do, so it is ideal for cron. Anyone joining with a random MAC gets
  full bandwidth for at most one cron interval:

```crontab
*/5 * * * * gwncli throttle-locally-administered --url "https://gwn_c074ad7b2950.local" --username admin --password yourpassword
```

To exempt a device permanently, disable "private WiFi address" for your network on the
device, or delete its rule and add a rule with better rates via `gwncli set` (existing
rules are never overwritten by `throttle-locally-administered`).

The reverse-engineered GWN API used by this tool is documented in [gwnapi.md](gwnapi.md).

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

**⚠️ Security:** Make sure to limit the proxy access to your local network only. You don't want someone else configuring your WiFi 🥴 Also provide a proper TLS certificate (Let's Encrypt, Zero SSL, or Buypass).

**Access control example** for network 192.168.1.0/24. This assumes your current public v4/v6 IP can be found in `/etc/nginx/snippets/ipv4-public-address.conf` and `/etc/nginx/snippets/ipv6-network.conf`:

```nginx
server {
    listen 443 ssl;
    server_name gwn-proxy.local;
    
    # SSL certificate configuration
    ssl_certificate /etc/letsencrypt/live/gwn-proxy.local/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/gwn-proxy.local/privkey.pem;
    
    location / {
        # Allow local network and your public IP only
        satisfy any;
        allow 192.168.1.0/24;
        allow fd00::/8;
        include /etc/nginx/snippets/ipv4-public-address.conf;
        include /etc/nginx/snippets/ipv6-network.conf;
        deny all;
        
        # Proxy to Grandstream AP
        proxy_pass https://gwn_c074ad7b2950.local;
        proxy_ssl_verify off;
    }
}
```


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
