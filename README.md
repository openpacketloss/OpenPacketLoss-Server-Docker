# [PacketLossTest by OpenPacketLoss™](https://openpacketloss.com/) | Docker Image

OpenPacketLoss™ is a modern, open-source network diagnostic tool built to measure raw packet loss directly from any web browser.

Unlike throughput tests that hide packet drops behind TCP retransmission, or legacy CLI tools like ping and traceroute that rely on rate-limited ICMP, OpenPacketLoss uses WebRTC Data Channels configured with ordered: false and maxRetransmits: 0, delivering unreliable, unordered SCTP datagrams that behave like raw UDP. The result is a true, protocol-accurate measurement of network stability as experienced by latency-sensitive applications like Zoom, Discord, and online gaming.

![OpenPacketLoss Demo](https://github.com/openpacketloss/PacketLossTest/raw/main/assets/demo.gif)

## Deployment Guide
**Full self-hosting guide:**  
[https://openpacketloss.com/selfhosted-server](https://openpacketloss.com/selfhosted-server)

Deploy your own packet loss testing server with full control over infrastructure, performance, and privacy.


[![Docker Pulls](https://img.shields.io/docker/pulls/openpacketloss/openpacketloss-server)](https://hub.docker.com/r/openpacketloss/openpacketloss-server)
[![Multi-Arch](https://img.shields.io/badge/platform-linux%2Famd64%20%7C%20arm64%20%7C%20arm%2Fv7-blue)](https://hub.docker.com/r/openpacketloss/openpacketloss-server/tags)

---

## Quick Start (Host Networking)
For a quick deployment, use the following command:

> [!WARNING]
> **Host Networking**  
> Host networking (`--network host`) provides the best performance and simplified WebRTC setup, but it is primarily supported on Linux. It will not work as expected on Docker Desktop for Windows or macOS due to how the virtualization layer handles network stacks.

```bash
docker run -d \
  --name openpacketloss \
  --network host \
  --restart unless-stopped \
  openpacketloss/openpacketloss-server:latest
```

---

## Docker Compose (Recommended)
For structured deployments and easier management, use the following `docker-compose.yml` configuration:

### Option A: Host Networking (Best for Linux)
```yaml
services:
  openpacketloss:
    image: openpacketloss/openpacketloss-server:latest
    container_name: openpacketloss
    network_mode: host
    restart: unless-stopped
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```
**Deploy:** `docker compose up -d` | **Access:** `http://YOUR-SERVER-IP:80`

### Option B: Bridge Mode (Universal / Non-Host)
Use this configuration if you are running on Windows/macOS, or if you prefer to avoid host networking on Linux (e.g., for security or explicit port isolation). This mode works across all platforms.

> [!TIP]
> **Port Range Selection**  
> A range of 50 ports (e.g., 40000-40050) is typically enough for small-scale or personal use, supporting around 25–50 concurrent users. However, for production or public-facing servers, we recommend using a wider range (such as the standard ephemeral range 49152–65535) to avoid port exhaustion during peak usage.


```yaml
services:
  openpacketloss:
    image: openpacketloss/openpacketloss-server:latest
    container_name: openpacketloss
    restart: unless-stopped

    ports:
      # HTTP and API mapping
      - "9000:80"
      - "4000:4000/udp"

      # WebRTC ICE UDP port range
      - "40000-40050:40000-40050/udp"

    environment:
      # --- Networking (required) ---
      - STUN_PORT=4000
      - NAT_1TO1_IP=192.168.1.12

      # --- WebRTC ICE Port Range ---
      - ICE_PORT_MIN=40000
      - ICE_PORT_MAX=40050

    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```
**Deploy:** `docker compose up -d` | **Access:** `http://YOUR-SERVER-IP:9000`

> [!IMPORTANT]
> **Deployment Configuration:**
> - **Webapp:** Port `9000`
> - **STUN Server:** Port `4000` (UDP)
> - **WebRTC Media:** `40000-40050` (UDP)
> - **External IP:** Ensure `NAT_1TO1_IP` and the Host IP are updated in the configuration before deploying.

**Monitor Logs:** `docker logs -f openpacketloss`

---

## Network Configuration
When deploying in cloud environments (e.g., AWS, Azure, GCP, DigitalOcean), you must manually open these ports in your Security Group or Firewall. Host networking bypasses Docker's internal NAT, but it does not bypass your provider's external firewall.

> [!IMPORTANT]
> **Cloud Firewalls**  
> If you are using a Cloud Provider, the server will not be reachable until you explicitly permit incoming traffic on the ports listed below. Failure to open the UDP range will result in ICE Connection Failures.

### Required Ports
| Port / Range | Protocol | Purpose |
| :--- | :--- | :--- |
| 80 | TCP | Web Frontend & API Signaling |
| 3478 | UDP | Integrated STUN Server |
| 49152 - 65535 | UDP | WebRTC Data Stream (Standard Ephemeral Range). Recommended for production. |

Option B: If using Bridge Mode, ensure you open the specific ports mapped to your host (e.g., 9000, 4000, and 40000-40050 UDP) in your firewall instead of the default ports listed above.

---

## Environment Variables
Configure your server by passing these environment variables to the Docker container or setting them in your `.env` file.

### Server Configuration Options
| Variable | Default | Description |
| :--- | :--- | :--- |
| `PLATFORM_MODE` | `self` | 'web' (public service) or 'self' (self-hosted with flexible limits). |
| `PORT` | `8080` | HTTP server port for signaling. |
| `STUN_PORT` | `3478` | Built-in STUN server UDP port. |
| `STUN_URL` | `auto` | STUN URL (auto, explicit stun:ip:port, or none). |
| `NAT_1TO1_IP` | `-` | Public/External IP for NAT environments (SDP mangling). Auto-detects LAN IP if empty. |
| `MAX_CONNECTIONS` | `500` | Maximum total concurrent connections. |
| `MAX_CONNECTIONS_PER_IP` | `10` | Maximum concurrent connections per unique client IP. |
| `ICE_PORT_MIN` | `-` | Minimum UDP port for WebRTC ICE candidates (optional). |
| `ICE_PORT_MAX` | `-` | Maximum UDP port for WebRTC ICE candidates (optional). |
| `ICE_GATHERING_TIMEOUT_SECS` | `2` | Seconds to wait for ICE candidate gathering. |
| `OVERALL_REQUEST_TIMEOUT_SECS` | `30` | Maximum time for the entire SDP handshake process. |
| `STALE_CONNECTION_AGE_SECS` | `120` | Maximum age in seconds for inactive connections. |
| `PERIODIC_CLEANUP_INTERVAL_SECS` | `5` | Interval to scan and clean up stale connections. |
| `RUST_LOG` | `info` | Logging verbosity (trace, debug, info, warn, error). |

---

## Build from Source (Self-Contained)
This repository is designed to be self-contained. When you build the image, it automatically pulls the latest code from GitHub for both the backend (compiled from source) and frontend (served as-is).

```bash
git clone https://github.com/openpacketloss/OpenPacketLoss-Server-Docker.git
cd openpacketloss-server-docker
docker build -t openpacketloss-server:local .
```

---

## Related Repositories

- [OpenPacketLoss-Server](https://github.com/openpacketloss/OpenPacketLoss-Server): Core WebRTC server implementation.
- [OpenPacketLoss-Server-Docker](https://github.com/openpacketloss/OpenPacketLoss-Server-Docker): Containerized deployment for easy hosting (this repository).
- [PacketLossTest](https://github.com/openpacketloss/PacketLossTest): The web-based testing interface.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

Maintained by OpenPacketLoss.com
