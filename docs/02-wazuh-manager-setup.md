# 2. Wazuh Manager Setup

The manager is the detection engine. These steps install it, load the custom rules
from this repo, and wire up the Shuffle integration.

## Install (Ubuntu 22.04)

```bash
curl -sO https://packages.wazuh.com/4.x/wazuh-install.sh
sudo bash ./wazuh-install.sh -a        # all-in-one: manager + indexer + dashboard
```

The installer prints the admin password for the dashboard at `https://<server-ip>`.

## Load the custom detection rules

Copy [`../wazuh/manager/local_rules.xml`](../wazuh/manager/local_rules.xml) onto the
manager and restart:

```bash
sudo cp local_rules.xml /var/ossec/etc/rules/local_rules.xml
sudo chown wazuh:wazuh /var/ossec/etc/rules/local_rules.xml
sudo systemctl restart wazuh-manager
```

Verify the rules loaded without syntax errors:

```bash
sudo /var/ossec/bin/wazuh-logtest
# paste a sample Sysmon event, or check the manager started cleanly:
sudo tail -f /var/ossec/logs/ossec.log
```

## Wire up Shuffle and active response

Merge the blocks from
[`../wazuh/manager/ossec.conf.snippets.xml`](../wazuh/manager/ossec.conf.snippets.xml)
into `/var/ossec/etc/ossec.conf`:

- the `<integration>` block forwards alerts to Shuffle (fill in your webhook URL),
- the `<command>` and `<active-response>` blocks register the `remove-threat` action.

Restart again:

```bash
sudo systemctl restart wazuh-manager
```

## Enable the API for active response

The Wazuh API (port `55000`) is installed with the manager. Create a dedicated user
for Shuffle rather than reusing the admin account:

```bash
# via the dashboard: Server management → Security → Users → add "shuffle-soar"
# grant it a role that allows the active-response endpoint
```

Shuffle authenticates as this user in step 8 of the workflow.

## Next

→ [3. Windows Agent & Sysmon](03-windows-agent-sysmon.md)
