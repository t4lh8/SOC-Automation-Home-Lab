# 7. Active Response (Automated Remediation)

The final step closes the loop: after the analyst approves, the malicious file is
removed from the endpoint automatically - no manual RDP session required.

## The chain

```
Shuffle (approved)
   │  PUT /active-response?agents_list=001   (Wazuh API, port 55000)
   ▼
Wazuh Manager
   │  relays the command to the agent
   ▼
Wazuh Agent (Windows 10)
   │  runs remove-threat.cmd → remove-threat.ps1
   ▼
Malicious file deleted, result written to active-responses.log
```

## The pieces

| Piece | File | What it does |
|---|---|---|
| Command definition | [`../wazuh/manager/ossec.conf.snippets.xml`](../wazuh/manager/ossec.conf.snippets.xml) | Registers `remove-threat` on the manager |
| Response script | [`../wazuh/agent/active-response/remove-threat.ps1`](../wazuh/agent/active-response/remove-threat.ps1) | Reads the alert, deletes `win.eventdata.image` |
| Wrapper | [`../wazuh/agent/active-response/remove-threat.cmd`](../wazuh/agent/active-response/remove-threat.cmd) | Lets Wazuh launch the PowerShell script |
| API call | [`../shuffle/workflow-nodes.md`](../shuffle/workflow-nodes.md) → node 8 | Triggers the command for the right agent |

## Why approval gates the delete

Automatically deleting files the instant an alert fires is risky: a false positive,
or an attacker deliberately triggering the rule against a legitimate file, could cause
the automation to damage the host. Gating step 8 behind the analyst's approval keeps a
human accountable for destructive actions - standard practice in a real SOC.

## Verify it worked

On the endpoint:

```powershell
Get-Content "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log" -Tail 10
# → ... remove-threat: Removed malicious file: C:\Users\...\update.exe
```

The deletion itself generates a new Sysmon/Wazuh event, so the response is auditable
in the dashboard alongside the original detection.

## Extending the response

The same mechanism can isolate the host (firewall-drop active response), disable the
compromised user, or kill the process instead of deleting the file - swap the script
and register a new command.
