# Shuffle Automation Workflow

Shuffle is the SOAR engine of the lab. It receives every high-severity Wazuh alert,
enriches it with open-source threat intelligence, opens a case, notifies the analyst,
and - after approval - triggers remediation on the endpoint.

This maps to **steps 3-8** of the [architecture diagram](../images/soc-architecture.png).

## Workflow at a glance

```
Webhook (from Wazuh)                      ← step 3: Send Alerts
   │
   ▼
Extract SHA256 from alert
   │
   ▼
VirusTotal: look up the hash              ← step 4: Enrich IOCs (OSINT)
   │
   ▼
Is it malicious? ──no──► Close as benign / low priority
   │ yes
   ▼
TheHive: create alert / case              ← step 5: Send Alerts (case management)
   │
   ▼
Email the SOC analyst with the details    ← step 6: Send Email
   │
   ▼
Wait for analyst decision                 ← step 7: Send & Receive
   │ approved
   ▼
Wazuh API: run "remove-threat"            ← step 8: Send Response Action
```

## Nodes

Each node below lists the app, the request it makes, and the body. Replace every
`YOUR-...` placeholder with your own lab values. API keys live in Shuffle's
**Authentication** vault, never in the workflow itself.

See [`workflow-nodes.md`](workflow-nodes.md) for the full request bodies.

## Why a human approves step 8

Deleting files on a live host is destructive. The workflow pauses at step 7 and
only runs the active response after the analyst approves, which mirrors how a real
SOC balances automation with human oversight (and avoids an attacker tricking the
automation into deleting the wrong thing).
