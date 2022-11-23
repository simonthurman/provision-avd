<#
.SYNOPSIS
Renames the existing Application Group Desktop to a friendly name and add Default Users.
This is only run on the first Session Host.

.DESCRIPTION
This script will connect to Azure and rename the SessionHost desktop for the required Application Group to the required name.
It will also set the default users based on the required list.

This script requires a Service Principal for connection to Azure.
#>

param(
    [Parameter(mandatory = $true)]
    [string]$ResourceGroup,
    [Parameter(mandatory = $true)]
    [string]$ApplicationGroupName,
    [Parameter(mandatory = $true)]
    [string]$DesktopName,
    [Parameter(mandatory = $true)]
    [string]$AzTenantID,
    [Parameter(mandatory = $true)]
    [string]$AppID,
    [Parameter(mandatory = $true)]
    [string]$AppSecret,
    [Parameter(Mandatory = $true)]
    [string]$HostPoolName,
    [Parameter(mandatory = $false)]
    [string]$DefaultUsers
)

$ScriptPath = [system.IO.path]::GetDirectoryName($PSCommandPath)
. (Join-Path $ScriptPath "Functions.ps1")

ImportPSMod

Write-Log -Message "Starting Script. Renaming Desktop name."
#Create credential object to connect to Azure
$Creds = New-Object System.Management.Automation.PSCredential($AppID, (ConvertTo-SecureString $AppSecret -AsPlainText -Force))

Write-Log -Message "Connecting to Azure."
#Connect to Azure
Connect-AzAccount -ServicePrincipal -Credential $Creds -TenantID $AzTenantID

Write-Log -Message "Checking that Host Pool does not already exist in Tenant"
$HostPool = Get-AzWVDHostPool 
if (!$HostPool.name -contains $HostPoolName) {
    Write-Log -Error "Host Pool does not exist"
    throw "Host Pool: $HostPoolName does not exist"
}

Write-Log -Message "Host Pool: $HostPoolName exists"

#Update the Application Group Desktop FriendlyName
Write-Log -Message "Attempting to rename Desktop name."
try {
    Update-AzWVDDesktop -ResourceGroupName $ResourceGroup -ApplicationGroupName $ApplicationGroupName -Name $DesktopName -FriendlyName $DesktopName -ErrorAction Stop
    Write-Log -Message "Successfully renamed Desktop."

}
catch {
    Write-Log -Error "Failed to rename Desktop"
    Write-Log -Error "Error Details: $_"
}

[array]$cloud = @()
[array]$users = @()
if ($defaultUsers) {
    $userlist = $DefaultUsers.Split(",")


    foreach ($user in $userlist) {
        if ($user -match "@") { 
            $users += $user
        }
        else {
            $cloud += $user
        } 
        
    }
    
    if ($cloud.count -gt 0) {
        Write-Log -Message "Adding Cloud Groups"
        foreach ($clouduser in $cloud) {
            try {
                Write-Log -Message "Adding user/group: $clouduser to App Group $ApplicationGroupName"
                New-AzRoleAssignment -ObjectId "$($clouduser)" -RoleDefinitionName "Desktop Virtualization User" -ResourceName $ApplicationGroupName -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.DesktopVirtualization/applicationGroups' -ErrorAction Stop
            }
            catch {
                Write-Log -Error "Error adding user/group: $clouduser to App Group: $ApplicationGroupName"
                Write-Log -Error "Error Details: $_"
            }
        }
    }
    if ($users.count -gt 0) {
        Write-Log -Message "Adding On-Premise Users/Groups"
        foreach ($premUser in $users) {
            try {
                $UserId = (Get-AzADUser -UserPrincipalName $premuser).id
                Write-Log -Message "User: $premuser"
                New-AzRoleAssignment -ObjectID "$($UserId)" -RoleDefinitionName "Desktop Virtualization User" -ResourceName $ApplicationGroupName -ResourceGroupName $ResourceGroup -ResourceType 'Microsoft.DesktopVirtualization/applicationGroups' -ErrorAction Stop
                Write-Log -Message "Default User Group successfully added to App Group: $ApplicationGroupName"
            }
            catch {
                Write-Log -Error "Error adding user: $premUser to App Group: $ApplicationGroupName"
                Write-Log -Error "Error details: $_"
            }
        }
    }
} 