```bash
GH_TOKEN="REDACTED_GITHUB_PAT" \
curl -H "Authorization: token $GH_TOKEN" -sL \
https://raw.githubusercontent.com/atnplex/homelab/main/scripts/openwrt_flexible_backup.sh | bash
```

use the above cli command in terminal with any script

```bash
GH_TOKEN="REDACTED_GITHUB_PAT" curl -H "Authorization: token $GH_TOKEN" -sL https://raw.githubusercontent.com/atnplex/homelab/main/scripts/openwrt_flexible_backup.sh | bash
```
