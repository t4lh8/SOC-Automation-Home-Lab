@echo off
REM Wrapper so Wazuh can launch the PowerShell active-response script.
REM Place next to remove-threat.ps1 in:
REM   C:\Program Files (x86)\ossec-agent\active-response\bin\
REM Wazuh pipes the alert JSON to this wrapper on stdin; we pass it straight
REM through to PowerShell, which does the actual remediation.

PowerShell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0remove-threat.ps1"
exit /b %ERRORLEVEL%
