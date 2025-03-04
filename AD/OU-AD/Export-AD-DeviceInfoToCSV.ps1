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
Required Modules: ActiveDirectory
This sample script will read devices in Active Directory, looking all OUs under the Initial OU and export the results to a CSV File.
CSV File will have the Computer Name, OU Name and "Distinguished Name" (Path).
This CSV File can be consumed by other scripts.
#>

Import-Module ActiveDirectory

# Set the CSV output path
$CSVPath = "C:\TEMP\OUInfo.csv"

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
        foreach ($Computer in $Computers) {
            # Collect the information in the array
            $OUInfo += [pscustomobject]@{
            Computer = $Computer.Name
            OU = $OUName
            DistinguishedName = $OU.DistinguishedName}
        }
    }
}

$OUInfo | Export-CSV -Path $CSVPath -Force -NoTypeInformation
