# 4. Detecting Mimikatz

This is the heart of the lab: proving that an attack on the endpoint produces a
high-severity Wazuh alert, which is what drives the whole automation workflow.

## The technique

**Mimikatz** dumps plaintext passwords, hashes and Kerberos tickets from the memory
of the `lsass.exe` process. It is the classic tool for
[OS Credential Dumping: LSASS Memory (T1003.001)](https://attack.mitre.org/techniques/T1003/001/)
and shows up in a huge share of real intrusions.

## How the detection works

When a process starts, Sysmon writes **Event ID 1 (Process Creation)**. Crucially,
Sysmon reads the `OriginalFileName` from the binary's PE header, which Mimikatz keeps
as `mimikatz.exe` even after an attacker renames the file on disk. Our rule
[`100002`](../wazuh/manager/local_rules.xml) matches on that field, so renaming the
executable does not evade it.

Two backstops widen the coverage:

- **Rule 100003** matches Mimikatz command-line keywords (`sekurlsa::logonpasswords`,
  `lsadump::sam`, …) in case the PE metadata was stripped.
- **Rules 100004 and 100005** cover Sysmon **Event ID 10 (ProcessAccess)** on `lsass.exe`,
  which also catches in-memory variants that never write `mimikatz.exe` to disk.
  Wazuh's built-in rule 92900 already handles the common read mask `0x1010` and runs
  first, so a custom rule for the same mask is never reached. 100005 therefore sits on
  top of 92900, and 100004 only covers the masks 92900 misses (`0x1410`, `0x1438`,
  `0x143a`, `0x1fffff`). The detection tests below found this.

## Testing the rules without a Windows VM

[`tests/detections/replay.py`](../tests/detections/replay.py) sends Sysmon events
(the same XML Windows writes) into a real Wazuh manager the way an agent does, then
reads `alerts.json` and checks which rule fired. The cases, including two that must
*not* alert, are in [`tests/detections/cases.json`](../tests/detections/cases.json).

```bash
sudo install -o wazuh -g wazuh -m 660 wazuh/manager/local_rules.xml /var/ossec/etc/rules/
sudo /var/ossec/bin/wazuh-control restart
sudo python3 tests/detections/replay.py
```

`wazuh-logtest` cannot be used for this: it always feeds events in through the syslog
queue, so Windows events never reach the eventchannel decoder and no Windows rule matches.
The same test runs in GitHub Actions on every change to the rules.

## Testing the detection (isolated VM only)

> Take a snapshot first. You will run real credential-dumping tooling.

1. On the Windows 10 VM, download Mimikatz from its official source
   (gentilkiwi/mimikatz). Windows Defender will try to quarantine it; for the test,
   exclude the lab folder in a disposable VM.
2. Run a credential-dumping command:

   ```cmd
   mimikatz.exe "privilege::debug" "sekurlsa::logonpasswords" exit
   ```

3. Rename and retry to prove the `OriginalFileName` detection:

   ```cmd
   copy mimikatz.exe update.exe
   update.exe "privilege::debug" "sekurlsa::logonpasswords" exit
   ```

## Expected result

In the Wazuh dashboard (*Threat Hunting / Security events*) you should see an alert:

```
Rule 100002 (level 15): Mimikatz credential-dumping tool executed: C:\Users\...\update.exe
MITRE: T1003.001
```

Because the level is ≥ 12, the manager forwards it to Shuffle, kicking off
[5. Shuffle automation](05-shuffle-automation.md).

## Restore

Revert the VM to the clean snapshot when you are done.
