#!/usr/bin/env python3
"""Replay sample Sysmon events through a real Wazuh manager and check which rules fire.

Why not wazuh-logtest? logtest always feeds events in through the syslog queue,
so Windows events never reach the built-in windows_eventchannel decoder and no
Windows rule can match. This script does what a Windows agent does instead:
it sends the event XML on the Windows event queue ("f:EventChannel:...") and
then reads the resulting alerts from alerts.json.

Needs a running wazuh-manager and root:

    sudo python3 tests/detections/replay.py [--summary FILE]
"""

import argparse
import json
import socket
import sys
import time
from pathlib import Path
from xml.sax.saxutils import escape

QUEUE = "/var/ossec/queue/sockets/queue"
ALERTS = Path("/var/ossec/logs/alerts/alerts.json")
CASES = Path(__file__).with_name("cases.json")
FIRST_RECORD_ID = 90001


def sysmon_event(event_id: int, record_id: int, data: dict) -> str:
    """Build the message the Windows agent sends for one Sysmon event.

    The agent forwards the raw event XML (Event Viewer > Details > XML view)
    wrapped in JSON. The record ID is used to find the matching alerts later.
    """
    # Windows renders event XML with single-quoted attributes, and the manager's
    # decoder depends on it: double quotes get JSON-escaped and break the XML.
    fields = "".join(f"<Data Name='{_xml(k)}'>{_xml(v)}</Data>" for k, v in data.items())
    xml = (
        "<Event xmlns='http://schemas.microsoft.com/win/2004/08/events/event'><System>"
        "<Provider Name='Microsoft-Windows-Sysmon' Guid='{5770385f-c22a-43e0-bf4c-06f5698ffbd9}'/>"
        f"<EventID>{event_id}</EventID><Version>5</Version><Level>4</Level>"
        "<Task>1</Task><Opcode>0</Opcode><Keywords>0x8000000000000000</Keywords>"
        "<TimeCreated SystemTime='2026-10-09T10:15:42.1234567Z'/>"
        f"<EventRecordID>{record_id}</EventRecordID>"
        "<Execution ProcessID='3012' ThreadID='4120'/>"
        "<Channel>Microsoft-Windows-Sysmon/Operational</Channel>"
        "<Computer>LAB-WIN</Computer><Security UserID='S-1-5-18'/></System>"
        f"<EventData>{fields}</EventData></Event>"
    )
    return json.dumps({"Message": f"Sysmon event {event_id}", "Event": xml})


def _xml(value: str) -> str:
    return escape(value, {"'": "&apos;", '"': "&quot;"})


def send(message: str) -> None:
    with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as s:
        s.connect(QUEUE)
        s.send(f"f:EventChannel:{message}".encode())


def collect_alerts(offset: int, wanted: set[str], timeout: float = 20.0) -> dict[str, list[dict]]:
    """Read alerts written after `offset`, grouped by event record ID."""
    found: dict[str, list[dict]] = {}
    deadline = time.time() + timeout
    while time.time() < deadline:
        with ALERTS.open(encoding="utf-8") as fh:
            fh.seek(offset)
            found.clear()
            for line in fh:
                try:
                    alert = json.loads(line)
                except json.JSONDecodeError:
                    continue
                rid = alert.get("data", {}).get("win", {}).get("system", {}).get("eventRecordID")
                if rid in wanted:
                    found.setdefault(rid, []).append(alert["rule"])
        # Every positive case alerts; give the rest a moment in case they alert too.
        if wanted <= found.keys():
            break
        time.sleep(1)
    return found


def check(case: dict, rules: list[dict]) -> tuple[bool, str, str]:
    fired = {str(r["id"]): r for r in rules}
    got = ", ".join(f"{r['id']} (level {r['level']})" for r in rules) or "no alert"
    if "expect_rule" in case:
        rule = fired.get(case["expect_rule"])
        ok = rule is not None and rule["level"] == case["expect_level"]
        want = f"{case['expect_rule']} (level {case['expect_level']})"
    else:
        ok = not any(r in fired for r in case["expect_not"])
        want = "not " + ", ".join(case["expect_not"])
    return ok, want, got


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--summary", help="append a Markdown table here (e.g. $GITHUB_STEP_SUMMARY)")
    args = ap.parse_args()

    cases = json.loads(CASES.read_text(encoding="utf-8"))
    offset = ALERTS.stat().st_size if ALERTS.exists() else 0
    ids = {}
    for i, case in enumerate(cases):
        record_id = str(FIRST_RECORD_ID + i)
        ids[record_id] = case
        send(sysmon_event(case["event_id"], int(record_id), case["data"]))

    positive = {rid for rid, c in ids.items() if "expect_rule" in c}
    alerts = collect_alerts(offset, positive)
    time.sleep(2)  # let any late alerts for the negative cases land too
    alerts = collect_alerts(offset, set(ids), timeout=0.1)

    rows, failed = [], 0
    for rid, case in ids.items():
        rules = alerts.get(rid, [])
        ok, want, got = check(case, rules)
        desc = rules[-1]["description"] if rules else ""
        failed += not ok
        print(f"[{'PASS' if ok else 'FAIL'}] {case['name']}\n"
              f"       expected {want}, got {got}" + (f"\n       {desc}" if desc else ""))
        rows.append((ok, case["name"], want, got, desc))

    print(f"\n{len(rows) - failed}/{len(rows)} detection tests passed")
    if args.summary:
        with open(args.summary, "a", encoding="utf-8") as fh:
            fh.write("## Detection tests (real Wazuh manager)\n\n"
                     "| | Case | Expected | Alerts | Description |\n|---|---|---|---|---|\n")
            for ok, name, want, got, desc in rows:
                fh.write(f"| {'✅' if ok else '❌'} | {name} | {want} | {got} | {desc} |\n")
            fh.write(f"\n**{len(rows) - failed}/{len(rows)} passed**\n")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
