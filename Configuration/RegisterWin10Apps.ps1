#Script to register any Windows 10 apps that have stuck in Staging.



Try {
    Get-AppXPackage -Allusers | ?{$_.PackageUserInformation -match "Staged"} | Foreach { Add-AppXPackage -DisableDevelopmentMode -Register "$($_.InstallLocation)\AppXManifest.xml"} -ErrorAction Stop | Out-File C:\Windows\Temp\Win10Apps.txt -Append
    
} catch {
    $_.Exception.Message
    "Failed to register Win 10 Apps." | Out-File C:\Windows\Temp\Win10Apps.txt -Append
    $_.Exception.Message | Out-File C:\Windows\Temp\Win10Apps.txt -Append
}
