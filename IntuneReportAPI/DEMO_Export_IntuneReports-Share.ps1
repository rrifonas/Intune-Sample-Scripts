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
This sample script extract several reports from Intune using the Intune Report API.

It contains examples on how the select specific columns and filter some reports.

Required Modules: Microsoft.Graph.Authentication
Required Graph API Permissions: DeviceManagementManagedDevices.Read.All

Reference:
    https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/reports-export-graph-apis
    https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/reports-export-graph-available-reports

#>
 
 Function Get-IntuneReport() {
    param
        (
            [parameter(Mandatory = $true)]
            $JSON,
            [parameter(Mandatory = $true)]
            $OutputPath

        )
    try {
        $ReportName = ($JSON | ConvertFrom-Json).reportName
        Write-Host "Running Report: $($ReportName)..."

        $WebResultApp = Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs" -Body $JSON

        # Check if report is ready
        $ReportStatusApp = ""
        $ReportQueryApp = "https://graph.microsoft.com/beta/deviceManagement/reports/exportJobs('$($WebResultApp.id)')"

        do{
            Start-Sleep -Seconds 5
            $ReportStatusApp = Invoke-MgGraphRequest -Method GET -Uri $ReportQueryApp
            if ($?) {
                Write-Host "Report Status: $($ReportStatusApp.status)..."
            }
            else {
                Write-Error "Error"
                break
            }
        } until ($ReportStatusApp.status -eq "completed" -or $ReportStatusApp.status -eq "failed")

    }
        catch {
        $exs = $Error.ErrorDetails
        $ex = $exs[0]
        Write-Host "Response content:`n$ex" -f Red
        Write-Host
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Message)"
        Write-Host
        break
    }
    # Extract Report and Rename it
    Remove-Item -Path "$outputpath\$($ReportName)*.csv" -Force
    $ZipPath = "$outputpath\$ReportName.zip"
    Invoke-WebRequest -Uri $ReportStatusApp.url -OutFile $ZipPath
    Expand-Archive -Path $ZipPath -DestinationPath $outputpath -Force
    Remove-Item -Path $ZipPath -Force
    Rename-Item -Path "$outputpath\$($ReportStatusApp.Id).csv" -NewName "$($ReportName).csv"
 }

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

$ExportOutput = "C:\TEMP"

#Configuration Profiles
$jsonstring = @"
{"reportName":"ConfigurationPolicyAggregate","filter":"","select":["PolicyName","UnifiedPolicyType","UnifiedPolicyPlatformType","NumberOfCompliantDevices","NumberOfNonCompliantOrErrorDevices","NumberOfConflictDevices"],"format":"csv","snapshotId":"ConfigurationPolicyAggregate_00000000-0000-0000-0000-000000000001","search":""}
"@
 Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Settings Compliance
$jsonstring = @"
{"reportName":"SettingComplianceAggReport","filter":"","select":[],"format":"csv","snapshotId":"SettingComplianceAggReport_00000000-0000-0000-0000-000000000001"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Device Compliance
$jsonstring = @"
{"reportName":"DeviceCompliance","filter":"","select":["DeviceName","UPN","ComplianceState","OS","OSVersion","OwnerType","LastContact"],"format":"csv","snapshotId":"DeviceCompliance_00000000-0000-0000-0000-000000000001","search":""}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Policy Compliance
$jsonstring = @"
{"reportName":"PolicyComplianceAggReport","filter":"","select":[],"format":"csv","snapshotId":"PolicyComplianceAggReport_00000000-0000-0000-0000-000000000001"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Devices Without Compliance
$jsonstring = @"
{"reportName":"DevicesWithoutCompliancePolicy","filter":"","select":["DeviceId","DeviceName","DeviceModel","DeviceType","OSDescription","OSVersion","OwnerType","ManagementAgents","UserId","PrimaryUser","UPN","UserEmail","UserName","AadDeviceId","OS"],"format":"csv","snapshotId":"DevicesWithoutCompliancePolicy_00000000-0000-0000-0000-000000000001"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Devices
$jsonstring = @"
{"reportName":"DevicesWithInventory","filter":"","select":[],"format":"csv","localizationType":"LocalizedValuesAsAdditionalColumn"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Application
$jsonstring = @"
{"reportName":"AppInvRawData","filter":"","select":["ApplicationName","ApplicationPublisher","ApplicationVersion","DeviceId","DeviceName","OSDescription","OSVersion","Platform","UserId","EmailAddress","UserName"],"format":"csv","localizationType":"LocalizedValuesAsAdditionalColumn"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Feature Update Report, replace "PolicyId" with the PolicyId from your feature update policy
$jsonstring = @"
{"reportName":"WindowsUpdatePerPolicyPerDeviceStatus","filter":"(OwnerType eq '1') and (PolicyId eq '5cd33c4d-9d67-438f-adfe-f69eccd29d70')","select":["DeviceName","UPN","DeviceId","AADDeviceId","CurrentDeviceUpdateStatusEventDateTimeUTC","CurrentDeviceUpdateStatus","CurrentDeviceUpdateSubstatus","AggregateState","LatestAlertMessage","LastWUScanTimeUTC","WindowsUpdateVersion"],"format":"csv","snapshotId":"WindowsUpdatePerPolicyPerDeviceStatus_00000000-0000-0000-0000-000000000001"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput

#Readiness Report, with only Corporate Devices and excluded upgraded devices. You will need to use Graph to find the "Group Tag" ID.
$jsonstring = @"
{"reportName":"MEMUpgradeReadinessDevice","filter":"(Ownership eq '1') and (ReadinessStatus eq '0' or ReadinessStatus eq '1' or ReadinessStatus eq '2' or ReadinessStatus eq '3' or ReadinessStatus eq '5') and (TargetOS eq 'NI23H2') and (DeviceScopesTag eq '00004')","select":["DeviceName","DeviceManufacturer","DeviceModel","OSVersion","ReadinessStatus","SystemRequirements","AppIssuesCount","DriverIssuesCount","AppOtherIssuesCount"],"format":"csv","snapshotId":"MEMUpgradeReadinessDevice_00000000-0000-0000-0000-000000000001"}
"@
Get-IntuneReport -JSON $jsonstring -OutputPath $ExportOutput
