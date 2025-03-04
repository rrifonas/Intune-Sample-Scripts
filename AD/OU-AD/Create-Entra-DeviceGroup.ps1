# This Sample Code is provided for the purpose of illustration only and is not intended to be
# used in a production environment. THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED
# "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED
# TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE. We
# grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce
# and distribute the object code form of the Sample Code, provided that You agree: (i) to not use
# Our name, logo, or trademarks to market Your software product in which the Sample Code is
# embedded; (ii) to include a valid copyright notice on Your software product in which the Sample
# Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from
# and against any claims or lawsuits, including attorneys’ fees, that arise or result from the
# use or distribution of the Sample Code.

# Please note: None of the conditions outlined in the disclaimer above will supersede the terms
# and conditions contained within the Premier Customer Services Description.

<#
This sample script will read devices in Active Directory, looking all OUs under the Initial OU, compare the Computer name with 
Entra Hybrid-joined devices, and then add devices to a Device Group based on the OU Name (Intune - <OUName>).

It will also output the included devices to a variable that can be easily exported to CSV.

Modules: ActiveDirectory, Microsoft.Graph.Authentication, Microsoft.Graph.Groups, Microsoft.Graph.Identity.DirectoryManagement
GraphPermissions: Device.ReadWrite.All, Group.ReadWrite.All, GroupMembership.ReadWrite.All


#>

Import-Module ActiveDirectory
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Identity.DirectoryManagement
Import-Module Microsoft.Graph.Groups


#############################################################################
#Authentication with App Registration

# Populate with the App Registration details and Tenant ID
$ClientId          = ""
$ClientSecret      = "" 
$tenantid          = "" 

# Create ClientSecretCredential
$secret = ConvertTo-SecureString -String $ClientSecret -AsPlainText -Force
$ClientSecretCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $secret

# Authenticate to the Microsoft Graph
Connect-MgGraph  -TenantId $tenantid -ClientSecretCredential $ClientSecretCredential

#############################################################################
# Get Hybrid-joined and enabled devices from Microsoft Entra ID
$entraDevices = Get-MgDevice -Filter "TrustType eq 'ServerAD' and AccountEnabled eq true" 

# Specify the initial OU to search
$InitialOU = "OU=Workstations,OU=CMPFEBR Resources,DC=cmpfebr,DC=com"

# Get all OUs under the initial OU
$OUs = Get-ADOrganizationalUnit -Filter * -SearchBase $InitialOU
$OUInfo=@()

foreach ($OU in $OUs) {
    # Get the name of the OU
    $OUName = $OU.Name
    
    # Get all computer objects in the current OU
    $Computers = Get-ADComputer -Filter {Enabled -eq $true} -SearchBase $OU.DistinguishedName -SearchScope 1

    # Measure the number of computer objects
    $ComputerCount = $Computers | Measure-Object | Select-Object -ExpandProperty Count

    # Only proceed if there are computer objects in the OU
    if ($ComputerCount -gt 0) {
        # Check if the group already exists in Entra ID
        $GroupName = "Intune - $($OUName)"
        $Group = Get-MgGroup -Filter "displayName eq '$GroupName'" -ErrorAction SilentlyContinue
        if ($Group -eq $null) {
            # Create the new group with the OU name if it doesn't exist
            $GroupParams = @{
                DisplayName = $GroupName
                MailEnabled = $false
                mailNickname = "ABC"
                SecurityEnabled = $true
                Description = $OU.DistinguishedName
            }
            $Group = New-MgGroup @GroupParams
            Write-Host "Created new group: $GroupName"
        }
        
        foreach ($Computer in $Computers) {
            # Check if the device exists in Entra ID
            $entraDevice = $entraDevices | Where{ $_.displayName -eq $Computer.Name}
            if ($entraDevice) {
                # Add the computer to the group
                New-MgGroupMember -GroupId $Group.Id -DirectoryObjectId $entraDevice.Id -ErrorAction SilentlyContinue
                Write-Host "Adding device $($Computer.Name) to group $($Group.DisplayName)"
                
                # Collect the information in the array
                $OUInfo += [pscustomobject]@{
                    Computer = $Computer.Name
                    OU = $OUName
                    Group = $Group.DisplayName
                }
            } else {
                Write-Host "Device $($Computer.Name) does not exist in Entra ID"
            }
        }
    }
}

$OUInfo | Export-Csv -Path C:\TEMP\OUInfo.csv -NoTypeInformation
