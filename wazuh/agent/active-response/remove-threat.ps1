<#
  Active-response script for the Windows 10 endpoint (STEP 8).

  Wazuh runs this when the "remove-threat" command is triggered from the API.
  The manager pipes the triggering alert to the script as JSON on stdin; we read
  the path of the offending process (win.eventdata.image) and delete that file,
  then write the outcome to the agent's active-responses.log.

  Install:
    1. Copy this file to:
         C:\Program Files (x86)\ossec-agent\active-response\bin\remove-threat.ps1
    2. Create a wrapper named remove-threat.cmd in the same folder (see remove-threat.cmd)
       so Wazuh can launch it, and register the command in the manager ossec.conf
       (see wazuh/manager/ossec.conf.snippets.xml).

  This is intentionally a manual, analyst-approved action: nothing is deleted
  until Shuffle calls the Wazuh API after the analyst clicks "approve".
#>

$ErrorActionPreference = "Stop"
$logPath = "C:\Program Files (x86)\ossec-agent\active-response\active-responses.log"

function Write-ARLog([string]$message) {
    $line = "{0} remove-threat: {1}" -f (Get-Date -Format "yyyy/MM/dd HH:mm:ss"), $message
    Add-Content -Path $logPath -Value $line
}

try {
    # Wazuh sends the alert as a single JSON line on stdin.
    $raw = [Console]::In.ReadToEnd()
    $input = $raw | ConvertFrom-Json

    $command = $input.command          # "add" to apply, "delete" to roll back
    $target  = $input.parameters.alert.data.win.eventdata.image

    if ([string]::IsNullOrWhiteSpace($target)) {
        Write-ARLog "No target image found in the alert - nothing to do."
        exit 0
    }

    if ($command -eq "add") {
        if (Test-Path -LiteralPath $target) {
            Remove-Item -LiteralPath $target -Force
            Write-ARLog "Removed malicious file: $target"
        } else {
            Write-ARLog "Target not found (already gone?): $target"
        }
    } else {
        Write-ARLog "Received '$command' - no rollback action for a deleted file."
    }

    exit 0
}
catch {
    Write-ARLog "ERROR: $($_.Exception.Message)"
    exit 1
}
