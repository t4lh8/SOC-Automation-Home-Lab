# Shuffle Workflow - Node Details

Concrete configuration for every node in the workflow. Shuffle uses `$variable`
Liquid-style references to pull fields out of previous nodes; the exact names
depend on your node labels, so treat the ones below as the lab's convention.

## 1. Webhook (trigger) - step 3

- **Trigger type:** Webhook
- Copy the generated URL into the Wazuh manager `<integration><hook_url>` block
  (see [`../wazuh/manager/ossec.conf.snippets.xml`](../wazuh/manager/ossec.conf.snippets.xml)).
- The incoming body is the full Wazuh alert JSON. Key fields used downstream:

```
$exec.text.all_fields.rule.description          # e.g. "Mimikatz credential-dumping tool executed..."
$exec.text.all_fields.rule.level                # 15
$exec.text.all_fields.rule.mitre.id             # ["T1003.001"]
$exec.text.all_fields.agent.name                # Windows 10 host name
$exec.text.all_fields.agent.id                  # 001  (needed for active response)
$exec.text.all_fields.data.win.eventdata.image  # path of the malicious process
$exec.text.all_fields.data.win.eventdata.hashes # "MD5=...,SHA256=...,IMPHASH=..."
```

## 2. Extract SHA256 (Shuffle Tools - Regex)

The Sysmon `hashes` field packs several hashes into one string. Pull out the SHA256:

- **App:** Shuffle Tools → *Regex capture group*
- **Input:** `$exec.text.all_fields.data.win.eventdata.hashes`
- **Regex:** `SHA256=([A-Fa-f0-9]{64})`
- **Output variable:** `sha256`

## 3. VirusTotal - enrich IOC - step 4

- **App:** VirusTotal (or an HTTP node)
- **Method:** `GET`
- **URL:** `https://www.virustotal.com/api/v3/files/$sha256`
- **Headers:** `x-apikey: ${VIRUSTOTAL_API_KEY}`  *(from the Shuffle vault)*
- **Read from the response:**

```
$virustotal.body.data.attributes.last_analysis_stats.malicious   # number of engines flagging it
$virustotal.body.data.attributes.meaningful_name
```

## 4. Condition - is it malicious?

- **App:** Shuffle Tools → *Condition*
- **Rule:** `$virustotal.body.data.attributes.last_analysis_stats.malicious` **greater than** `2`
- **True →** continue to TheHive. **False →** stop (log as benign / low priority).

## 5. TheHive - create alert - step 5

- **App:** TheHive (or HTTP)
- **Method:** `POST`
- **URL:** `https://YOUR-THEHIVE-HOST:9000/api/v1/alert`
- **Headers:** `Authorization: Bearer ${THEHIVE_API_KEY}`, `Content-Type: application/json`
- **Body:**

```json
{
  "type": "wazuh-alert",
  "source": "wazuh",
  "sourceRef": "$exec.text.all_fields.id",
  "title": "$exec.text.all_fields.rule.description",
  "description": "Host: $exec.text.all_fields.agent.name\nProcess: $exec.text.all_fields.data.win.eventdata.image\nVirusTotal detections: $virustotal.body.data.attributes.last_analysis_stats.malicious\nMITRE: $exec.text.all_fields.rule.mitre.id",
  "severity": 3,
  "tags": ["wazuh", "mimikatz", "T1003.001"],
  "observables": [
    { "dataType": "hash",     "data": "$sha256" },
    { "dataType": "hostname", "data": "$exec.text.all_fields.agent.name" }
  ]
}
```

## 6. Email the analyst - step 6

- **App:** Email (SMTP) or Shuffle Tools → *Send email*
- **To:** `soc-analyst@your-lab.local`
- **Subject:** `[SOC] $exec.text.all_fields.rule.description on $exec.text.all_fields.agent.name`
- **Body:**

```
A high-severity alert was raised and confirmed malicious by VirusTotal.

Host:        $exec.text.all_fields.agent.name  (agent $exec.text.all_fields.agent.id)
Rule:        $exec.text.all_fields.rule.description  (level $exec.text.all_fields.rule.level)
Process:     $exec.text.all_fields.data.win.eventdata.image
SHA256:      $sha256
VirusTotal:  $virustotal.body.data.attributes.last_analysis_stats.malicious engines flagged this file
MITRE:       $exec.text.all_fields.rule.mitre.id

A case has been created in TheHive. Approve remediation to remove the file from the host.
```

## 7. Wait for analyst decision - step 7

- **App:** Shuffle → *User Input* node
- Sends an approval request (email / Shuffle UI). The workflow pauses until the
  analyst clicks **Approve** or **Decline**. Only *Approve* continues to step 8.

## 8. Wazuh API - remove the threat - step 8

Two calls: authenticate, then trigger the active response on the right agent.

**8a. Get a token**
- **Method:** `POST`
- **URL:** `https://YOUR-WAZUH-HOST:55000/security/user/authenticate`
- **Auth:** Basic (Wazuh API user/password from the vault)
- **Read:** `$wazuh_auth.body.data.token`

**8b. Run the active response**
- **Method:** `PUT`
- **URL:** `https://YOUR-WAZUH-HOST:55000/active-response?agents_list=$exec.text.all_fields.agent.id`
- **Headers:** `Authorization: Bearer $wazuh_auth.body.data.token`
- **Body:**

```json
{
  "command": "remove-threat",
  "arguments": [],
  "alert": {
    "data": {
      "win": { "eventdata": { "image": "$exec.text.all_fields.data.win.eventdata.image" } }
    }
  }
}
```

The manager relays this to the agent, which runs `remove-threat.ps1` and deletes the
file. The result is written to the agent's `active-responses.log` and shows up as a
new Wazuh event, closing the loop.
