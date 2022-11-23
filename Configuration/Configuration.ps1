configuration AddSessionHost
{
    param
    (    
        [Parameter(mandatory = $true)]
        [string]$HostPoolName,
        [Parameter(mandatory = $true)]
        [string]$ResourceGroup,
        [Parameter(mandatory = $true)]
        [string]$ApplicationGroupName,
        [Parameter(mandatory = $true)]
        [string]$AzTenantID,
        [Parameter(mandatory = $true)]
        [string]$DesktopName,
        [Parameter(mandatory = $true)]
        [string]$AppID,
        [Parameter(mandatory = $true)]
        [string]$AppSecret,
        [Parameter(mandatory = $true)]
        [string]$DefaultUsers,
        [Parameter(mandatory = $true)]
        [string]$vmPrefix
    )

    $rdshIsServer = $true
    $ScriptPath = [system.io.path]::GetDirectoryName($PSCommandPath)

    $OSVersionInfo = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    
    if ($OSVersionInfo -ne $null) {
        if ($OSVersionInfo.InstallationType -ne $null) {
            $rdshIsServer = @{$true = $true; $false = $false }[$OSVersionInfo.InstallationType -eq "Server"]
        }
    }

    Node localhost
    {
        LocalConfigurationManager {
            RebootNodeIfNeeded = $true
            ConfigurationMode  = "ApplyOnly"
        }

        if ($rdshIsServer) {
            "$(get-date) - rdshIsServer = true: $rdshIsServer" | out-file c:\windows\temp\rdshIsServerResult.txt -Append
            if ($env:computername -eq "$($vmPrefix)-0") {

                WindowsFeature RDS-RD-Server {
                    Ensure = "Present"
                    Name   = "RDS-RD-Server"
                }

                Script ExecuteRdAgentInstallServer {
                    DependsOn  = "[WindowsFeature]RDS-RD-Server"
                    GetScript  = {
                        return @{'Result' = '' }
                    }
                    SetScript  = {
                        & "$using:ScriptPath\Script-AddRdshServer.ps1" -HostPoolName $using:HostPoolName -ResourceGroupName $using:ResourceGroup -AzTenantID $using:AzTenantID -AppId $using:AppID -AppSecret $using:AppSecret
                        & "$using:ScriptPath\Script-RenameDesktop.ps1" -ResourceGroup $using:ResourceGroup -ApplicationGroupName $using:ApplicationGroupName -AzTenantID $using:AzTenantID -DesktopName $using:DesktopName -AppId $using:AppID -AppSecret $using:AppSecret -DefaultUsers $using:DefaultUsers -HostPoolName $using:HostPoolName
                    }
                    TestScript = {
                        return (Test-path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent")
                    }
                }
            }
            else {
                WindowsFeature RDS-RD-Server {
                    Ensure = "Present"
                    Name   = "RDS-RD-Server"
                }

                Script ExecuteRdAgentInstallServer {
                    DependsOn  = "[WindowsFeature]RDS-RD-Server"
                    GetScript  = {
                        return @{'Result' = '' }
                    }
                    SetScript  = {
                        & "$using:ScriptPath\Script-AddRdshServer.ps1" -HostPoolName $using:HostPoolName -ResourceGroupName $using:ResourceGroup -AzTenantID $using:AzTenantID -AppId $using:AppID -AppSecret $using:AppSecret
                    }
                    TestScript = {
                        return (Test-path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent")
                    }
                }
            }
        }
        else {
            "$(get-date) - rdshIsServer = false: $rdshIsServer" | out-file c:\windows\temp\rdshIsServerResult.txt -Append
            if ($env:computername -eq "$($vmPrefix)-0") {
                
                Script ExecuteRdAgentInstallClient {
                    GetScript  = {
                        return @{'Result' = '' }
                    }
                    SetScript  = {
                        & "$using:ScriptPath\Script-AddRdshServer.ps1" -HostPoolName $using:HostPoolName -ResourceGroupName $using:ResourceGroup -AzTenantID $using:AzTenantID -AppId $using:AppID -AppSecret $using:AppSecret
                        & "$using:ScriptPath\Script-RenameDesktop.ps1" -ResourceGroup $using:ResourceGroup -ApplicationGroupName $using:ApplicationGroupName -AzTenantID $using:AzTenantID -DesktopName $using:DesktopName -AppId $using:AppID -AppSecret $using:AppSecret -DefaultUsers $using:DefaultUsers -HostPoolName $using:HostPoolName
                    }
                    TestScript = {
                        return (Test-path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent")
                    }
                }
            }
            else {
                Script ExecuteRdAgentInstallClient {
                    GetScript  = {
                        return @{'Result' = '' }
                    }
                    SetScript  = {
                        & "$using:ScriptPath\Script-AddRdshServer.ps1" -HostPoolName $using:HostPoolName -ResourceGroupName $using:ResourceGroup -AzTenantID $using:AzTenantID -AppId $using:AppID -AppSecret $using:AppSecret
                    }
                    TestScript = {
                        return (Test-path "Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\RDInfraAgent")
                    }
                }

            }
        }
    }
}
