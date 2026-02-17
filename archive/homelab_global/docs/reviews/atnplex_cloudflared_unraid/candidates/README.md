# cloudflared-unraid (vNext)

Unraid plugin to run Cloudflare Tunnel (cloudflared) without Docker, starting boot-early and working even when array/cache are unavailable.

Key goals:
- Boot-early start (immediately after /boot/config/go finishes).
- Token stored on flash at /boot/config/plugins/cloudflared/config/token (0600) and passed via token-file so it never appears in `ps`.
- RAM-first logging at /var/log/cloudflared with optional non-blocking persistence.
