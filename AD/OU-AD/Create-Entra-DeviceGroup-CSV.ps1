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
This sample script will read a CSV file with "ComputerName,OU,DistinguishedName", compare the Computer name with 
Entra Hybrid-joined devices, and then add devices to a Device Group based on the OU Name (Intune - <OUName>).

It will also output the included devices to a variable that can be easily exported to CSV.

Required Modules: Microsoft.Graph.Authentication, Microsoft.Graph.Groups, Microsoft.Graph.Identity.DirectoryManagement
Required Graph API Permissions: Devices.Read.All, Group.ReadWrite.All, GroupMember.ReadWrite.All
#>


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

# CSV Path
$CSVPath = "C:\TEMP\OUInfo.csv"
$csvData = Import-Csv -Path $CSVPath

# Get Hybrid-joined and enabled devices from Microsoft Entra ID
$EntraDevices = Get-MgDevice -Filter "TrustType eq 'ServerAD' and AccountEnabled eq true" 

$output = @()

foreach ($device in $csvData) {
    $entraDevice = $entraDevices | Where{ $_.displayName -eq $device.Computer}
    if ($entraDevice) {
        # Get the name of the OU
        $OUName = $Device.OU
    
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
                Description = $device.DistinguishedName
            }
            $Group = New-MgGroup @GroupParams
            Write-Host "Created new group: $GroupName"
            }
            else {
                Write-Host "Group $GroupName already exists"
            }
        
            # Add the computer to the group
            New-MgGroupMember -GroupId $Group.Id -DirectoryObjectId $EntraDevice.Id -ErrorAction SilentlyContinue
            Write-Host "Adding device $($Device.Computer) to group $($Group.DisplayName)"

            # Collect output
            $output += [pscustomobject]@{
                DeviceID = $entraDevice.Id
                ComputerName = $device.Computer
                DisplayName = $entraDevice.DisplayName
                OU = $device.OU
                DistinguishedName = $device.DistinguishedName
                }
        }
        else{
            $entraDevice
            Write-Host "Device $($device.Computer) could not be found in Entra ID"
        }
}

# Output the result
$output | ft 