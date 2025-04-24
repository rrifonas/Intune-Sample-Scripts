####################################################
# API Permissions Required: DeviceManagementManagedDevices.ReadWrite.All, User.Read.All
# Modules Required: Microsoft.Graph.Authentication, Microsoft.Graph.Beta.DeviceManagement, Microsoft.Graph.Users
# Reference: https://github.com/microsoft/mggraph-intune-samples/tree/main/ManagedDevices
####################################################

# Get Intune Primary User
function Get-IntuneDevicePrimaryUser {

    [CmdletBinding()]
    param (
        [parameter(Mandatory)][string] $DeviceID   
    )

     
    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices"
    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)" + "/" + $deviceId + "/users"

    try {
        
        $primaryUser = Invoke-MgGraphRequest -Uri $uri -Method Get

        return $primaryUser.value."id"
        
    }
    catch {
        $ex = $_.Exception
        $errorResponse = $ex.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($errorResponse)
        $reader.BaseStream.Position = 0
        $reader.DiscardBufferedData()
        $responseBody = $reader.ReadToEND();
        Write-Host "Response content:`n$responseBody" -f Red
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Response.StatusCode) $($ex.Response.StatusDescription)"
        throw "Get-IntuneDevicePrimaryUser error"
    }
}   

####################################################
# Set the Intune primary user
function Set-IntuneDevicePrimaryUser {
    [cmdletbinding()]
    param

    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $DeviceId,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $userId
    )

    $graphApiVersion = "beta"
    $Resource = "deviceManagement/managedDevices('$DeviceId')/users/`$ref"     

    $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
    $userUri = "https://graph.microsoft.com/$graphApiVersion/users/" + $userId
        

    $JSON = @"

{"@odata.id":"$userUri"}

"@
     

    Invoke-MgGraphRequest -Method POST -Uri $uri -Body $JSON  
}

####################################################
# Remove the Intune primary user
function Remove-IntuneDevicePrimaryUser {

	#Build the URI for Graph request
	$URI = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices('$DeviceId')/users/`$ref"

	#Remove the primary user
	try {
		Invoke-MgGraphRequest -Method DELETE -Uri $URI
	}
	catch {
		Write-Output "$($_.Exception.Message)"
	}
}



####################################################

# Set the primary user of the device to the last logged on user if it they are not already the same user
function Set-LastLogon {    
        
    #Check if there is a Primary user set on the device already
    $IntuneDevicePrimaryUser = Get-IntuneDevicePrimaryUser -deviceId $DeviceID
    if (!($IntuneDevicePrimaryUser)) {
        Write-Host "No Intune Primary User Id set for Intune Managed Device" $Device.deviceName
    }
    else {
        #  A primary user is there already. Find out who it is. 
        $PrimaryUser = Get-MgUser -UserId $IntuneDevicePrimaryUser
        Write-Host $Device.deviceName "Device has a primary user. Current primary user:" $PrimaryUser.displayName
    }
   
    # Using the objectID of the last logged on user, get the user info from Microsoft Graph for logging purposes
    $LastLoggedOnAdUser = Get-MgUser -UserId $LastLoggedOnUser
    Write-Host "Matched the last logged on user id:" $LastLoggedOnUser "to the Entra ID user info:" $LastLoggedOnAdUser.displayName 
    Write-Host "Last logged on user name is:"  $LastLoggedOnAdUser.UserPrincipalName

    #Check if the current primary user of the device is the same as the last logged in user
    if ($IntuneDevicePrimaryUser -ne $LastLoggedOnUser) {
        #If the user does not match, then set the last logged in user as the new Primary User
        Write-Host $Device.deviceName "Device has a primary user but not the last logged on user. Current primary user:" $PrimaryUser.displayName "Last logged on user:"  $LastLoggedOnAdUser.displayName
        Set-IntuneDevicePrimaryUser -DeviceId $DeviceID -userId $LastLoggedOnUser

        # Get the primary user to see if that worked.
        $Result = Get-IntuneDevicePrimaryUser -deviceId $DeviceID
        if ($Result -eq $LastLoggedOnUser) {
            Write-Host "User" $LastLoggedOnAdUser.displayName "successfully set as primary user for device" $Device.deviceName
        }
        else {
            #If the result does not match the expecation something did not work right
            Write-Host "Failed to set as Primary User for device" $Device.deviceName
        
        }
    }
    else {
        write-host "Last logged on uer:" $LastLoggedOnAdUser.displayName "and the primary user:" $PrimaryUser.displayName "already match."  "Nothing to do on:" $Device.deviceName
    }

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

$DeviceName = "CLI01"

$Action = "Update" # Action can be Update or Remove

$Devices = Get-MgBetaDeviceManagementManagedDevice -Filter "DeviceName eq '$DeviceName'"

ForEach ($Device in $Devices){
    $Name = $Device.deviceName
    Write-Host "Found $Name in Intune"
    # Make sure we have a last logged on user
    if ($Action -eq "Update") {
		$LastLoggedOnUser = ($Device.usersLoggedOn[-1]).userId
		if ($LastLoggedOnUser) {
			#We have a last logged on user!
			Write-Host "Found last logged on user: $LastLoggedOnUser"
			# Go run the function to set the primary user if it needs to be set.
			Write-host "Checking to see if primary user match last logged on user. If not we will set:" $Name "to" $LastLoggedOnUser
			$DeviceID = $Device.id                                              
			Set-LastLogon   
			Write-host "*** END *** - settting user for $Name"
		}
	} 
    Else {
		Write-host "Removing the Primary User from device:" $Name
		$DeviceID = $Device.id
		Remove-IntuneDevicePrimaryUser
	}
}

Disconnect-MgGraph | Out-Null