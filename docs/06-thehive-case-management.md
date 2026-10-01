# 6. TheHive Case Management

TheHive is where the human investigation happens. Shuffle creates an alert here for
every confirmed detection, so the analyst has one place to triage, add observables,
and track the response.

## Install (Docker)

TheHive needs a backing database (Cassandra) and index/storage. The simplest path is
the official docker-compose that bundles TheHive with its dependencies:

```bash
git clone https://github.com/StrangeBeeCorp/docker
cd docker/thehive
docker compose up -d
# open http://<server-ip>:9000 and finish the setup wizard
```

## Get an API key for Shuffle

1. Log in as an organisation admin.
2. Create a service account (e.g. `shuffle`) with the **analyst** profile.
3. Generate an API key for it and store it in the Shuffle vault as `THEHIVE_API_KEY`.

## What Shuffle sends

Step 5 of the workflow POSTs an alert to `/api/v1/alert` with:

- **title** — the Wazuh rule description (e.g. "Mimikatz credential-dumping tool executed…")
- **severity** — 3 (high)
- **tags** — `wazuh`, `mimikatz`, `T1003.001`
- **observables** — the file **SHA256** and the **hostname**, so the analyst can pivot

Exact body: [`../shuffle/workflow-nodes.md`](../shuffle/workflow-nodes.md) → node 5.

## Analyst workflow

1. Open the alert in TheHive, review the observables and the VirusTotal verdict.
2. Promote it to a **case** if it warrants investigation.
3. Decide on the response. Approving the Shuffle **User Input** step triggers the
   endpoint remediation (step 7 doc).

## Next

→ [7. Active Response](07-active-response.md)
