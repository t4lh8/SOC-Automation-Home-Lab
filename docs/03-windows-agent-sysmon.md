# 3. Windows 10 Agent & Sysmon

The endpoint needs two things: **Sysmon** for deep process telemetry, and the
**Wazuh Agent** to ship that telemetry to the manager.

> ⚠️ Run this on an **isolated lab VM** only. Later steps execute Mimikatz to test
> the detection. Never do that on a machine with real credentials or network access
> you care about. Take a VM snapshot first.

## 1. Install Sysmon

Sysmon (Sysinternals) records process creation, LSASS access, network connections
and more. Use a well-known config such as SwiftOnSecurity's or Olaf Hartong's:

```powershell
# download Sysmon from https://learn.microsoft.com/sysinternals/downloads/sysmon
# and a config, e.g. sysmonconfig-export.xml
.\Sysmon64.exe -accepteula -i sysmonconfig-export.xml
```

Confirm it is logging:

```powershell
Get-WinEvent -LogName "Microsoft-Windows-Sysmon/Operational" -MaxEvents 5
```

## 2. Install the Wazuh Agent

Download the agent MSI from the Wazuh dashboard (*Agents → Deploy new agent*), which
generates the exact command with your manager IP and enrollment key. For example:

```powershell
# run in an elevated PowerShell
.\wazuh-agent-4.x.msi /q WAZUH_MANAGER="<MANAGER-IP>" WAZUH_AGENT_NAME="win10-endpoint"
Start-Service -Name WazuhSvc
```

## 3. Tell the agent to forward Sysmon

Merge the blocks from
[`../wazuh/agent/ossec.conf.snippets.xml`](../wazuh/agent/ossec.conf.snippets.xml)
into `C:\Program Files (x86)\ossec-agent\ossec.conf`, then restart:

```powershell
Restart-Service -Name WazuhSvc
```

## 4. Install the active-response script

Copy both files into the agent's active-response bin folder:

```
C:\Program Files (x86)\ossec-agent\active-response\bin\remove-threat.ps1
C:\Program Files (x86)\ossec-agent\active-response\bin\remove-threat.cmd
```

(from [`../wazuh/agent/active-response/`](../wazuh/agent/active-response/))

## 5. Confirm the agent is connected

In the Wazuh dashboard the endpoint should show as **Active**. You can also check:

```powershell
Get-Content "C:\Program Files (x86)\ossec-agent\ossec.log" -Tail 20
```

## Next

→ [4. Detecting Mimikatz](04-detection-mimikatz.md)
