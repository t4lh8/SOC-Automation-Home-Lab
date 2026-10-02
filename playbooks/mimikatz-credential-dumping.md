# Incident Response Playbook - Mimikatz Credential Dumping

**Alert:** Wazuh rule 100002 / 100003 / 100004 (level 12-15)
**MITRE ATT&CK:** [T1003.001 - OS Credential Dumping: LSASS Memory](https://attack.mitre.org/techniques/T1003/001/)
**Severity:** High

This playbook follows the SANS incident-handling phases and matches what the lab's
automation does (and where the analyst steps in).

## 1. Preparation
- Detection rules deployed on the manager, Sysmon logging on the endpoint.
- Shuffle workflow live; TheHive reachable; analyst email configured.
- VM snapshots taken so the endpoint can be restored after containment.

## 2. Identification
**Automated (Shuffle):**
- Webhook receives the alert; SHA256 is extracted and checked against VirusTotal.
- If ≥ 3 engines flag the hash, a case is opened in TheHive and the analyst is emailed.

**Analyst checks:**
- Is the process path expected? (`C:\Users\…\update.exe` running Mimikatz args is not.)
- Who is the parent process? Was there a preceding suspicious login or download?
- Which account ran it, and does that account normally use this host?
- Pivot on the SHA256 and hostname observables in TheHive.

**Triage question:** true positive (real tooling) or authorised red-team / test?

## 3. Containment
- **Short term:** approve the Shuffle **User Input** step → `remove-threat` deletes the
  binary on the endpoint. For a live intrusion, also isolate the host (network
  containment) and disable the affected account.
- Preserve evidence first if this is a real incident: capture memory / relevant logs
  before deleting, because credential dumping means other hosts may already be affected.

## 4. Eradication
- Remove any persistence the attacker established (scheduled tasks, services, run keys).
- Confirm no other copies of the tool remain (hunt the SHA256 fleet-wide in Wazuh).

## 5. Recovery
- **Assume the dumped credentials are compromised.** Force-reset the passwords of every
  account that was logged on to the host, and rotate any service / machine accounts.
- Restore the endpoint from a known-good image if integrity is in doubt.
- Re-enable the account and host once clean.

## 6. Lessons Learned
- Why did Mimikatz run - initial access vector? patch / hardening gap?
- Tune the rules if there were false positives; add detections for the delivery method.
- Consider LSASS protection (Credential Guard, RunAsPPL) to raise the cost of the attack.

### Response times (lab target)
| Phase | Target |
|---|---|
| Detection → alert in TheHive | < 1 min (automated) |
| Analyst acknowledgement | < 15 min |
| Containment (file removed / host isolated) | < 30 min |
