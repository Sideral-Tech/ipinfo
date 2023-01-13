# Description: Send IP information to an email address when the network changes
# Author: Alexandre Teles
# License: WTFPL
# Version: 1.0.0

# Settings

$scriptPath = "C:\scripts\"
$scriptName = "ipinfo.ps1"
$machineName = $env:COMPUTERNAME
$apiKey = "" # Your Mailgun API key
$mailgunUrl = "" # Your Mailgun API URL
$fromAddress = "" # Who is sending this email?
$toAddress = "" # Who should receive this email?
$subject = $machineName + ": " + "IP Information"
$taskName = "IP Information at Startup"

function Install {
    if (!(Test-Path -Path $scriptPath)) {
        New-Item -ItemType Directory -Path $scriptPath
    }

    $source = $PSCommandPath
    $destination = "$scriptPath$scriptName"
    
    if (!(Test-Path -Path $destination)) {
        Copy-Item -Path $source -Destination $destination
    }

    [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$scriptPath", "Machine")

    if(!(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)){
        $action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument "-File $scriptPath$scriptName"
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $settings = New-ScheduledTaskSettingsSet
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings
    }
}

function Uninstall {
    if(Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }

    if(Test-Path "$scriptPath$scriptName") {
        Remove-Item -Path "$scriptPath$scriptName" -Confirm:$false
    }
}

function Main {
    $ipinfo = Get-NetIPConfiguration -All
    $localIP = $ipinfo | Format-List | Out-String
    $remoteIP = Invoke-WebRequest -Uri "https://ifconfig.io/ip"
    $body = $localIP + "`n" + "External IP: " + $remoteIP.Content

    return Invoke-RestMethod -Uri $mailgunUrl -Method Post -Credential (
        New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "api", (
            ConvertTo-SecureString -String $apiKey -AsPlainText -Force)) -Body @{
                from=$fromAddress;
                to=$toAddress;
                subject=$subject;
                text=$body}
}

if ($args.Count -eq 0) {
    Main
} else {
    switch ($args[0]) {
        "--install" {
            Install
            break
        }
        "--uninstall" {
            Uninstall
            break
        }
        default {
            Write-Host "Invalid argument. Available options are: --install, --uninstall"
        }
    }
}
