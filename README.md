# 🛡️ SOC Automation Home Lab

![Wazuh](https://img.shields.io/badge/SIEM-Wazuh-00A9E0)
![Shuffle](https://img.shields.io/badge/SOAR-Shuffle-FF6600)
![TheHive](https://img.shields.io/badge/Case%20Mgmt-TheHive-FFB300)
![Sysmon](https://img.shields.io/badge/Telemetry-Sysmon-512BD4)
![MITRE ATT&CK](https://img.shields.io/badge/ATT%26CK-T1003.001-red)
![Terraform](https://img.shields.io/badge/IaC-Terraform-7B42BC?logo=terraform)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)

A hands-on **Security Operations Centre** built from open-source tools, wiring
**detection → automation → enrichment → case management → response** into a single
end-to-end workflow. The lab detects a real attack (Mimikatz credential dumping) on a
Windows endpoint and automatically triages, enriches, documents and remediates it -
with a human analyst approving the destructive step.

## Architecture

The architecture was designed up front (in draw.io) so each component's role and the
event flow were clear before building.

![SOC Automation Architecture](images/soc-architecture.png)

Events flow through eight steps, from endpoint telemetry to automated response:

![SOC Automation Workflow](images/soc-workflow.png)

| # | Step | Component |
|---|---|---|
| 1 | Send events | Windows 10 + Wazuh Agent + Sysmon |
| 2 | Receive & detect | Wazuh Manager + custom rules |
| 3 | Forward alerts | Wazuh → Shuffle webhook |
| 4 | Enrich IOCs | Shuffle → VirusTotal (OSINT) |
| 5 | Create case | Shuffle → TheHive |
| 6 | Notify analyst | Shuffle → Email |
| 7 | Review & decide | SOC analyst |
| 8 | Respond | Shuffle → Wazuh API → remove threat on endpoint |

## Tech stack

| Layer | Tool |
|---|---|
| Endpoint telemetry | **Sysmon** |
| SIEM / detection | **Wazuh** (manager, indexer, dashboard) |
| SOAR / automation | **Shuffle** |
| Threat intel | **VirusTotal** API |
| Case management | **TheHive** |
| Response | **Wazuh Active Response** (PowerShell) |

## Detection use case: Mimikatz (T1003.001)

The reference detection is **Mimikatz credential dumping**, a technique in a large
share of real intrusions. The custom Wazuh rules
([`wazuh/manager/local_rules.xml`](wazuh/manager/local_rules.xml)) catch it three ways:

- **OriginalFileName** from the PE header (Sysmon Event ID 1) - fires even if the
  attacker renames `mimikatz.exe`,
- **command-line keywords** (`sekurlsa::logonpasswords`, `lsadump::sam`, …),
- **suspicious LSASS memory access** (Sysmon Event ID 10) - catches renamed / in-memory variants.

A level-15 alert triggers the whole automation chain.

## What's in this repo

```
├── images/              architecture & workflow diagrams (draw.io)
├── docs/                step-by-step build guide
│   ├── 01-architecture.md
│   ├── 02-wazuh-manager-setup.md
│   ├── 03-windows-agent-sysmon.md
│   ├── 04-detection-mimikatz.md
│   ├── 05-shuffle-automation.md
│   ├── 06-thehive-case-management.md
│   └── 07-active-response.md
├── wazuh/
│   ├── manager/         custom detection rules + ossec.conf integration snippets
│   └── agent/           agent config + the remove-threat active-response script
├── shuffle/             the SOAR workflow, node by node, with request bodies
├── playbooks/           incident-response playbook for the detection
└── deploy/              infrastructure as code: Terraform + one-command setup.sh
```

## Deploy it

**Automated (recommended)** - infrastructure as code brings the whole server stack up
on a cloud VM. See **[deploy/README.md](deploy/README.md)**:

```bash
cd deploy/terraform && terraform apply      # provision the VM + firewall
ssh root@<server-ip>
cd /opt/SOC-Automation-Home-Lab/deploy && sudo ./setup.sh   # Wazuh + Shuffle + TheHive
terraform destroy                           # when done, to stop cloud charges
```

The stack needs ~16 GB RAM, so it runs on a cloud VM; the spin-up → test → destroy
pattern keeps the cost to a few dollars.

**Manual** - follow the guides in order, starting with
**[docs/01-architecture.md](docs/01-architecture.md)**. In short:

1. Stand up the **Wazuh Manager** and load the custom rules.
2. Install **Sysmon** + the **Wazuh Agent** on an isolated Windows 10 VM.
3. Confirm the **Mimikatz detection** fires.
4. Build the **Shuffle** workflow (webhook → VirusTotal → TheHive → email → approval → response).
5. Stand up **TheHive** for case management.
6. Trigger the attack and watch it get detected, enriched, cased, and remediated.

> ⚠️ The detection test runs real credential-dumping tooling. Do it **only** on an
> isolated lab VM with a snapshot to restore - never on a production or personal machine.

## Design decisions

- **Detection-as-code** - the rules live in version control, not clicked into a UI, so
  they're reviewable and reproducible.
- **OriginalFileName over image name** - renaming the binary is the most common, laziest
  evasion; matching PE metadata defeats it.
- **Human-in-the-loop response** - step 8 deletes files, so it waits for analyst approval.
  Fully automatic destructive actions are how automation causes its own incidents.
- **Enrich before escalating** - VirusTotal filters out noise so the analyst only sees
  confirmed-malicious hashes.

## What I learned

- Building a virtual detection lab from scratch with open-source tools
- Writing custom Wazuh rules mapped to MITRE ATT&CK
- Using Sysmon logs (Event ID 1 and 10) to detect credential dumping
- Analyzing security logs to investigate suspicious activity
- Automating alert enrichment and case creation in Shuffle and TheHive
- Keeping a human approval step before any automated response
- Responding to realistic incidents and writing reports based on the SANS IR phases
- Deploying the lab with Terraform and Docker

## Inspiration

The lab architecture was inspired by [MyDFIR](https://www.youtube.com/@MyDFIR)'s
["SOC Automation Project"](https://www.youtube.com/watch?v=ahrSFdiWzis) series. I used it
as a starting point, then built out the detection rules, Shuffle workflow, playbook and the
Terraform/Docker deployment myself.

## Credits

- [Wazuh](https://wazuh.com/) · [Shuffle](https://shuffler.io/) · [TheHive](https://thehive-project.org/) · [Sysmon](https://learn.microsoft.com/sysinternals/downloads/sysmon) · [MITRE ATT&CK](https://attack.mitre.org/)

Made by **Talha Aker**.
