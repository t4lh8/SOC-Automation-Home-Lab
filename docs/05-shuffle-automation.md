# 5. Shuffle Automation (SOAR)

Shuffle turns a raw Wazuh alert into an enriched, triaged, actionable case without the
analyst touching a terminal. Full node-by-node details, including every request body,
are in [`../shuffle/workflow-nodes.md`](../shuffle/workflow-nodes.md).

## Install Shuffle (Docker)

```bash
git clone https://github.com/Shuffle/Shuffle
cd Shuffle
docker compose up -d
# open https://<server-ip>:3443 and create the admin user
```

## Build the workflow

1. **Create a workflow** and drop a **Webhook** trigger onto the canvas. Copy its URL
   into the Wazuh manager `<integration>` block (step 2 doc) and restart the manager.
2. Add the nodes in order (see the node doc for each one's configuration):
   - Extract SHA256 (Regex)
   - VirusTotal lookup
   - Condition: malicious?
   - TheHive: create alert
   - Email the analyst
   - User Input: wait for approval
   - Wazuh API: authenticate + run `remove-threat`
3. **Store secrets in the Shuffle vault**, not in nodes: VirusTotal key, TheHive key,
   Wazuh API credentials. Reference them as `${VIRUSTOTAL_API_KEY}` etc.

## Test it end to end

1. Trigger the Mimikatz detection on the endpoint (step 4 doc).
2. Watch the Shuffle run: the webhook fires, VirusTotal confirms the hash, a case
   appears in TheHive, and the analyst gets an email.
3. Approve the User Input node → the Wazuh API call runs → the file is removed on the
   endpoint and logged in `active-responses.log`.

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Webhook never fires | Manager `<integration>` level too high, or wrong hook URL. Check `/var/ossec/logs/integrations.log`. |
| VirusTotal 404 | Hash not seen before by VT (expected for a freshly compiled sample). Handle in the Condition node. |
| TheHive 401 | Wrong/expired API key, or TheHive not reachable from Shuffle. |
| Active response does nothing | Wazuh API user lacks permission, or the command name doesn't match the manager `<command>` block. |

## Next

→ [6. TheHive case management](06-thehive-case-management.md)
