# Sets up the Windows lab endpoint: Sysmon + Wazuh agent + active-response script.
# Run in an elevated PowerShell on the endpoint VM after cloning or copying this repo:
#
#   Set-ExecutionPolicy -Scope Process Bypass
#   .\deploy\azure\endpoint-setup.ps1 -Manager 10.20.1.10
#
# The agent version must not be newer than the manager (WAZUH_VERSION in deploy/.env).

param(
    [string]$Manager = "10.20.1.10",
    [string]$AgentVersion = "4.9.2-1",
    [string]$AgentName = "lab-win"
)

$ErrorActionPreference = "Stop"
$repo = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$work = Join-Path $env:TEMP "soc-lab-setup"
New-Item -ItemType Directory -Force $work | Out-Null

function Get-File($url, $dest) {
    Write-Host "Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing
}

# 1. Sysmon with a widely used community config.
Get-File "https://download.sysinternals.com/files/Sysmon.zip" "$work\Sysmon.zip"
Expand-Archive "$work\Sysmon.zip" -DestinationPath "$work\Sysmon" -Force
Get-File "https://raw.githubusercontent.com/olafhartong/sysmon-modular/master/sysmonconfig.xml" "$work\sysmonconfig.xml"
& "$work\Sysmon\Sysmon64.exe" -accepteula -i "$work\sysmonconfig.xml"

# 2. Wazuh agent pointed at the manager's private IP.
$msi = "$work\wazuh-agent.msi"
Get-File "https://packages.wazuh.com/4.x/windows/wazuh-agent-$AgentVersion.msi" $msi
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$msi`" /q WAZUH_MANAGER=`"$Manager`" WAZUH_AGENT_NAME=`"$AgentName`""

# 3. Forward the Sysmon channel (same block as wazuh/agent/ossec.conf.snippets.xml).
$conf = "${env:ProgramFiles(x86)}\ossec-agent\ossec.conf"
if (-not (Select-String -Path $conf -Pattern "Microsoft-Windows-Sysmon/Operational" -Quiet)) {
    $block = @"
<ossec_config>
  <localfile>
    <location>Microsoft-Windows-Sysmon/Operational</location>
    <log_format>eventchannel</log_format>
  </localfile>
</ossec_config>
"@
    Add-Content -Path $conf -Value $block
}

# 4. Active-response script used by the Shuffle workflow.
$arDir = "${env:ProgramFiles(x86)}\ossec-agent\active-response\bin"
Copy-Item "$repo\wazuh\agent\active-response\remove-threat.ps1", "$repo\wazuh\agent\active-response\remove-threat.cmd" $arDir -Force

Restart-Service -Name WazuhSvc
Start-Sleep -Seconds 5
Get-Service WazuhSvc, Sysmon64 | Format-Table Name, Status
Get-Content "${env:ProgramFiles(x86)}\ossec-agent\ossec.log" -Tail 10
