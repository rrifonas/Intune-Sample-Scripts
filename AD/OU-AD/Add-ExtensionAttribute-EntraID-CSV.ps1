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
Entra Hybrid-joined devices, and then add an extension attribute to the device objects based on the OU Name.

The extensionAttribute1 from devices can be used to create dynamic groups in Entra ID.

It will also output the included devices to a variable that can be easily exported to CSV.

Required Modules: Microsoft.Graph.Authentication, Microsoft.Graph.Groups, Microsoft.Graph.Identity.DirectoryManagement
Required Graph API Permissions: Devices.ReadWrite.All, Group.ReadWrite.All, GroupMember.ReadWrite.All

Reference:
    https://ourcloudnetwork.com/configure-device-extension-attributes-in-azure-ad-with-powershell/
    https://intunestuff.com/2023/11/28/how-to-add-extension-attributes-for-aad-devices/

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
        
        # Update the extensionAttribute1 attribute of the device
        $DeviceId = $entraDevice.Id
        $uri = $null
        $uri = "https://graph.microsoft.com/beta/devices/" + $DeviceId

        $json = @{
                    "extensionAttributes" = @{
                    "extensionAttribute1" = $OUName #Set to $null to remove the Attribute
                     }
                  } | ConvertTo-Json
  
        Invoke-MgGraphRequest -Uri $uri -Body $json -Method PATCH -ContentType "application/json"
                
        Write-Host "Updated extensionAttribute1 for device $($device.Computer) with OU $OUName"
                
        # Collect the information in the array
        $output += [pscustomobject]@{
                                        DeviceID = $entraDevice.Id
                                        Computer = $device.Computer
                                        DisplayName = $entraDevice.DisplayName
                                        OU = $OUName
                                        ExtensionAttribute1 = $OUName
                                    }
        }
        else{
            Write-Host "Device $($device.Computer) could not be found in Entra ID"
        }
}

# Output the result
$output | ft 