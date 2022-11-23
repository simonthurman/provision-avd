<#

.SYNOPSIS
Functions/Common variables file to be used by both Script-FirstRdsh.ps1 and Script-AdditionalRdshServers.ps1

#>

# Variables

# Setting to Tls12 due to Azure web app security requirements
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Log { 
    [CmdletBinding()] 
    param
    ( 
        [Parameter(Mandatory = $false)] 
        [string]$Message,
        [Parameter(Mandatory = $false)] 
        [switch]$Err 
    ) 
     
    try { 
        $DateTime = Get-Date -Format "MM-dd-yy HH:mm:ss"
        $Invocation = "$($MyInvocation.MyCommand.Source):$($MyInvocation.ScriptLineNumber)" 
        
        if ($err) {
            $message = "[ERROR] $message"
        }

        Add-Content -Value "$DateTime - $Invocation - $Message" -Path "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))\ScriptLog.log" 
        
    } 
    catch { 
        throw [System.Exception]::new("Some error occurred while writing to log file with message: $Message", $PSItem.Exception)
    } 
}

function Is1809OrLater {
    $OSVersionInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    if ($OSVersionInfo -ne $null) {
        if ($OSVersionInfo.ReleaseId -ne $null) {
            Write-Log -Message "Build: $($OSVersionInfo.ReleaseId)"
            $rdshIs1809OrLaterBool = @{$true = $true; $false = $false }[$OSVersionInfo.ReleaseId -ge 1809]
        }
    }
    return $rdshIs1809OrLaterBool
}

function ExtractDeploymentAgentZipFile {
    param
    ( 
        [Parameter(Mandatory = $true)] 
        [string]$ScriptPath,
        [Parameter(Mandatory = $true)] 
        [string]$DeployAgentLocation
    ) 

    if (Test-Path $DeployAgentLocation) {
        Remove-Item -Path $DeployAgentLocation -Force -Confirm:$false -Recurse
    }
    
    New-Item -Path "$DeployAgentLocation" -ItemType directory -Force 
    
    # Locating and extracting DeployAgent.zip
    Write-Log -Message "Locating DeployAgent.zip within Custom Script Extension folder structure: $ScriptPath"
    $DeployAgentFromRepo = (Get-ChildItem $ScriptPath\ -Filter DeployAgent.zip -Recurse | Select-Object).FullName
    if ((-not $DeployAgentFromRepo) -or (-not (Test-Path $DeployAgentFromRepo))) {
        throw "DeployAgent.zip file not found at $ScriptPath"
    }
    
    Write-Log -Message "Extracting 'Deployagent.zip' file into '$DeployAgentLocation' folder inside VM"
    Expand-Archive $DeployAgentFromRepo -DestinationPath "$DeployAgentLocation" 
    
}

function isRdshServer {
    $rdshIsServer = $true

    $OSVersionInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    
    if ($null -ne $OSVersionInfo) {
        if ($null -ne $OSVersionInfo.InstallationType) {
            $rdshIsServer = @{$true = $true; $false = $false }[$OSVersionInfo.InstallationType -eq "Server"]
        }
    }

    return $rdshIsServer
}

function ImportPSMod {
    
    $PackageProviderName = "NuGet"
    $PackageProvider = (Get-PackageProvider $PackageProviderName)
    if (!$PackageProvider) {
        Install-packageProvider -Name NuGet -MinimumVErsion 2.8.5.201 -force
    }
    
    $AVDModName = 'Az.DesktopVirtualization'
    $AVDMod = (get-module $AVDModName)
    if (!$AVDMod) {
        Install-Module -Name Az.DesktopVirtualization -AllowClobber -Force    
    }
    $AccountsModName = 'Az.Accounts'
    $AccountsMod = (Get-Module $AccountsModName)
    if (!$AccountsMod) {
        Install-Module -Name Az.Accounts -AllowClobber -Force
    }

    $ResourcesModName = 'Az.Resources'
    $ResourcesMod = (Get-Module $ResourcesModName)
    if (!$ResourcesMod) {
        Install-Module -Name Az.Resources -AllowClobber -Force
    }
    
    Import-Module -Name Az.DesktopVirtualization
}

function LocateFile {
    param (
        [Parameter(mandatory = $true)]
        [string]$Name,
        [string]$SearchPath = '.',
        [switch]$Recurse
    )
    
    Write-Log -Message "Locating '$Name' within: '$SearchPath'"
    $Path = (Get-ChildItem "$SearchPath\" -Filter $Name -Recurse:$Recurse).FullName
    if ((-not $Path) -or (-not (Test-Path $Path))) {
        throw "'$Name' file not found at '$SearchPath'"
    }
    if (@($Path).Length -ne 1) {
        throw "Multiple '$Name' files found at '$SearchPath': [`n$Path`n]"
    }

    return $Path
}

function RunMsiWithRetry {
    param(
        [Parameter(mandatory = $true)]
        [string]$programDisplayName,

        [Parameter(mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String[]]$argumentList, #Must have at least 1 value

        [Parameter(mandatory = $true)]
        [string]$msiOutputLogPath,

        [Parameter(mandatory = $false)]
        [switch]$isUninstall,

        [Parameter(mandatory = $false)]
        [switch]$msiLogVerboseOutput
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    if ($msiLogVerboseOutput) {
        $argumentList += "/l*vx+ ""$msiOutputLogPath""" 
    }
    else {
        $argumentList += "/l*+ ""$msiOutputLogPath"""
    }

    $retryTimeToSleepInSec = 30
    $retryCount = 0
    $sts = $null
    do {
        $modeAndDisplayName = ($(if ($isUninstall) { "Uninstalling" } else { "Installing" }) + " $programDisplayName")

        if ($retryCount -gt 0) {
            Write-Log -Message "Retrying $modeAndDisplayName in $retryTimeToSleepInSec seconds because it failed with Exit code=$sts This will be retry number $retryCount"
            Start-Sleep -Seconds $retryTimeToSleepInSec
        }

        Write-Log -Message ( "$modeAndDisplayName" + $(if ($msiLogVerboseOutput) { " with verbose msi logging" } else { "" }))


        $processResult = Start-Process -FilePath "msiexec.exe" -ArgumentList $argumentList -Wait -Passthru
        $sts = $processResult.ExitCode

        $retryCount++
    } 
    while ($sts -eq 1618 -and $retryCount -lt 20) # Error code 1618 is ERROR_INSTALL_ALREADY_RUNNING see https://docs.microsoft.com/en-us/windows/win32/msi/-msiexecute-mutex .

    if ($sts -eq 1618) {
        Write-Log -Err "Stopping retries for $modeAndDisplayName. The last attempt failed with Exit code=$sts which is ERROR_INSTALL_ALREADY_RUNNING"
        throw "Stopping because $modeAndDisplayName finished with Exit code=$sts"
    }
    else {
        Write-Log -Message "$modeAndDisplayName finished with Exit code=$sts"
    }

    return $sts
} 


<#
.DESCRIPTION
Uninstalls any existing RDAgent BootLoader and RD Infra Agent installations and then installs the RDAgent BootLoader and RD Infra Agent using the specified registration token.

.PARAMETER AgentInstallerFolder
Required path to MSI installer file

.PARAMETER AgentBootServiceInstallerFolder
Required path to MSI installer file

[CalledByARMTemplate]
#>
function InstallRDAgents {
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentInstallerFolder,
        
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$AgentBootServiceInstallerFolder,
    
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RegistrationToken,
    
        [Parameter(mandatory = $false)]
        [switch]$EnableVerboseMsiLogging
    )

    $ErrorActionPreference = "Stop"

    Write-Log -Message "Boot loader folder is $AgentBootServiceInstallerFolder"
    $AgentBootServiceInstaller = LocateFile -SearchPath $AgentBootServiceInstallerFolder -Name "*.msi"

    Write-Log -Message "Agent folder is $AgentInstallerFolder"
    $AgentInstaller = LocateFile -SearchPath $AgentInstallerFolder -Name "*.msi"

    if (!$RegistrationToken) {
        throw "No registration token specified"
    }

    $msiNamesToUninstall = @(
        @{ msiName = "Remote Desktop Services Infrastructure Agent"; displayName = "RD Infra Agent"; logPath = "C:\Users\AgentUninstall.txt" }, 
        @{ msiName = "Remote Desktop Agent Boot Loader"; displayName = "RDAgentBootLoader"; logPath = "C:\Users\AgentBootLoaderUnInstall.txt" }
    )
    
    foreach ($u in $msiNamesToUninstall) {
        while ($true) {
            try {
                $installedMsi = Get-Package -ProviderName msi -Name $u.msiName
            }
            catch {
                #Ignore the error if it was due to no packages being found.
                if ($PSItem.FullyQualifiedErrorId -eq "NoMatchFound,Microsoft.PowerShell.PackageManagement.Cmdlets.GetPackage") {
                    break
                }
    
                throw;
            }
    
            $oldVersion = $installedMsi.Version
            $productCodeParameter = $installedMsi.FastPackageReference
    
            RunMsiWithRetry -programDisplayName "$($u.displayName) $oldVersion" -isUninstall -argumentList @("/x $productCodeParameter", "/quiet", "/qn", "/norestart", "/passive") -msiOutputLogPath $u.logPath -msiLogVerboseOutput:$EnableVerboseMsiLogging
        }
    }

    Write-Log -Message "Installing RD Infra Agent on VM $AgentInstaller"
    RunMsiWithRetry -programDisplayName "RD Infra Agent" -argumentList @("/i $AgentInstaller", "/quiet", "/qn", "/norestart", "/passive", "REGISTRATIONTOKEN=$RegistrationToken") -msiOutputLogPath "C:\Users\AgentInstall.txt" -msiLogVerboseOutput:$EnableVerboseMsiLogging

    Write-Log -Message "Installing RDAgent BootLoader on VM $AgentBootServiceInstaller"
    RunMsiWithRetry -programDisplayName "RDAgent BootLoader" -argumentList @("/i $AgentBootServiceInstaller", "/quiet", "/qn", "/norestart", "/passive") -msiOutputLogPath "C:\Users\AgentBootLoaderInstall.txt" -msiLogVerboseOutput:$EnableVerboseMsiLogging

    $bootloaderServiceName = "RDAgentBootLoader"
    $startBootloaderRetryCount = 0
    while ( -not (Get-Service $bootloaderServiceName -ErrorAction SilentlyContinue)) {
        $retry = ($startBootloaderRetryCount -lt 6)
        $msgToWrite = "Service $bootloaderServiceName was not found. "
        if ($retry) { 
            $msgToWrite += "Retrying again in 30 seconds, this will be retry $startBootloaderRetryCount" 
            Write-Log -Message $msgToWrite
        } 
        else {
            $msgToWrite += "Retry limit exceeded" 
            Write-Log -Err $msgToWrite
            throw $msgToWrite
        }
            
        $startBootloaderRetryCount++
        Start-Sleep -Seconds 30
    }

    Write-Log -Message "Starting service $bootloaderServiceName"
    Start-Service $bootloaderServiceName
}