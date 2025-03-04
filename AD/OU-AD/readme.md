Scripts to read device and OU information from AD and perform actions in Entra ID:
+ **Export-AD-DeviceInfoToCSV.ps1**: Export device and OU information to a CSV File.
+ **Create-Entra-DeviceGroup-CSV.ps1**: Read the CSV file and create Static groups based on the OU and devices in a OU.
+ **Add-ExtensionAttribute-EntraID-CSV.ps1**: Read the CSV file and add an extensionAttribute1 with the OU to the device objects in Entra ID matching their on-prem counterpart.
+ **Create-Entra-DeviceGroup.ps1** and **Add-ExtensionAttribute-EntraID.ps1**: Read the device and OU information and create the Device Group or the extensionAttribute1 in a single step.
+ **OUInfo.csv**: Sample CSV File.

These scripts require and App Registration in Entra. You can use Certificate Authentication or Client Secret. The scripts are ready to accept Client Secret.
The App Registration must have Application permissions to the Microsoft Graph under API Permissions.
Specific permissions are listed in each script.
