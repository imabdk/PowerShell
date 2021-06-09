<#
.SYNOPSIS
    Remind users to update their iOS devices per e-mail and custom notification, if their devices is found to be running an iOS version less than the baseline
   
.DESCRIPTION
    The script looks up a baseline iOS version based on a known userPrincipalName. 
    The idea here is, that among the defined user's devices, the highest iOS version are considered the baseline iOS version for the environment
    If any other iOS device in the environment is not running the baseline version, each device and it's enrolled user, will receive an email and/or a custom notification in the Company Portal, reminding the user to update iOS.

    This is primary aimed at iOS devices enrolled as BYOD devices with the company portal

.NOTES
    Filename: Invoke-RemindUsersToUpdateiOS.ps1
    Version: 1.1
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

    Version history:

    1.0   -   Script created
    1.1   -   Added check for lastSyncDate making sure to only grab devices which have been syncing lately (within 2 days)
    1.1   -   Added $testMode for quickly turning testmode on and off

.LINKS
    https://www.imab.dk/automatically-remind-users-to-update-ios-with-e-mails-and-custom-notifications-using-microsoft-intune-powershell-sdk
#>
 
# Intune Admin account credentials details
$intunePSAdmUPN = Get-AutomationVariable -Name "IntunePSAdmUPN"
$intunePSAdmPW = Get-AutomationVariable -Name "IntunePSAdmPW"
$intunePSAdmSPW = ConvertTo-SecureString -String $intunePSAdmPW -AsPlainText -Force
$intuneCredentials = New-Object System.Management.Automation.PSCredential ($intunePSAdmUPN, $intunePSAdmSPW)

# Email account credentials details
$hlpUPN = Get-AutomationVariable -Name "hlpUPN"
$hlpPW = Get-AutomationVariable -Name "hlpPW"
$hlpSPW = ConvertTo-SecureString -String $hlpPW -AsPlainText -Force
$hlpCredentials = New-Object System.Management.Automation.PSCredential ($hlpUPN, $hlpSPW)

# Office 365 and email variables
$emailSmtp = "smtp.office365.com"
$emailPort = "587"
$emailFrom = "hlp@YourDomain.com"
$emailSubject = "Helpdesk kindly reminds you.."

# Getting device(s) referenced as the baseline iOS version. This version is considered the minimum in the environment
# Looking up a devices based on specific baseline UPN
$baselineUserUPN = "UPN@YourDomain.com"
$testUPN = "mab@imab.dk"

# Enable or disable sending either email and custom notification. Set either to $false to disable the option
$sendCustomNotification = $false
$sendEmail = $false

# Enable or disable testMode. Set to $true to enable testmode overriding baseline iOS version and to restrict the devices found to a testUPN
$testMode = $true

# Connect to Microsoft Graph using intuneCredentials
if (Get-Module -Name Microsoft.Graph.Intune -ListAvailable) {
    try {
        Write-Verbose -Verbose -Message "Connecting to Microsoft.Graph.Intune using $intunePSAdmUPN"
        Connect-MSGraph -PSCredential $intuneCredentials
    }
    catch {
        Write-Verbose -Verbose -Message "Failed to connect to MSGraph. Please check if credentials and permissions are correct. Breaking script"
        break
    }
}
elseif (-NOT(Get-Module -Name Microsoft.Graph.Intune -ListAvailable)) {
    Write-Verbose -Verbose -Message "The Microsoft.Graph.Intune module is not available. Breaking script"
    break  
}

# Getting all iOS devices for the specific baseline UPN
try {
    Write-Verbose -Verbose -Message "Getting all iOS devices belonging to the baseline UPN: $baselineUserUPN"
    $baselineVersion = Get-IntuneManagedDevice -Filter "contains(operatingSystem,'iOS')" | Where-Object {$_.userPrincipalName -eq $baselineUserUPN} | Select-Object deviceName,id,osVersion,model,emailAddress
}
catch {
    Write-Verbose -Verbose -Message "Failed to retrieve iOS devices for the selected UPN. Script is breaking"
    Write-Verbose -Verbose -Message "make sure that the account running the script has permissions to view content in Intune"
    break
}

# If baselineVersion returns multiple results, select the highest version number
if ($baselineVersion.GetType().IsArray) {

    Write-Verbose -Verbose -Message "BaselineVersion for iOS retrieved. Multiple devices found. Here's some details about them..."
    Write-Verbose -Verbose -Message "**********************************************************"
    foreach ($baseline in $baselineVersion) {
        Write-Verbose -Verbose -Message "deviceName: $($baseline.deviceName)"
        Write-Verbose -Verbose -Message "id: $($baseline.id)"
        Write-Verbose -Verbose -Message "osVersion: $($baseline.osVersion)"
        Write-Verbose -Verbose -Message "model: $($baseline.model)"
        Write-Verbose -Verbose -Message "emailAddress: $($baseline.emailAddress)"
        Write-Verbose -Verbose -Message "**********************************************************"
    }
    Write-Verbose -Verbose -Message "Getting baseline iOS version returned more than 1 result. Getting the highest value"
    $baselineVersion = $baselineVersion | Sort-Object -Property osVersion -Descending | Select-Object -First 1
    Write-Verbose -Verbose -Message "Baseline version is $($baselineVersion.osVersion)"
    $baselineVersion = $baselineVersion.osVersion
       
}
else {

    Write-Verbose -Verbose -Message "BaselineVersion for iOS retrieved. Here's some info about the device..."
    Write-Verbose -Verbose -Message "**********************************************************"
    Write-Verbose -Verbose -Message "deviceName: $($baselineVersion.deviceName)"
    Write-Verbose -Verbose -Message "id: $($baselineVersion.id)"
    Write-Verbose -Verbose -Message "osVersion: $($baselineVersion.osVersion)"
    Write-Verbose -Verbose -Message "model: $($baselineVersion.model)"
    Write-Verbose -Verbose -Message "emailAddress: $($baselineVersion.emailAddress)"
    Write-Verbose -Verbose -Message "**********************************************************"
    Write-Verbose -Verbose -Message "Baseline version is $($baselineVersion.osVersion)"
    $baselineVersion = $baselineVersion.osVersion
}

# Override devices and baselineversion for testing purposes
if ($testMode -eq $true) {
    
    Write-Verbose -Verbose -Message "Testing! testMode equals $testMode. Overriding baseline version and iOS devices found for testing purposes"
    
    # Override baseline version for testing purposes
    $baselineVersion = "13.4"

    try {
        $iOSDevices = Get-IntuneManagedDevice -Filter "contains(operatingSystem,'iOS')" | Where-Object {$_.userPrincipalName -eq $testUPN} | Select-Object deviceName,id,osVersion,emailAddress,model,lastSyncDateTime
    }
    catch {
        Write-Verbose -Verbose -Message "Failed to retrieve iOS devices for testMode. Script is breaking"
        break
    }
}
else {

    # Getting all iOS devices from Intune
    try {
        Write-Verbose -Verbose -Message "Now getting ALL iOS devices in the tenant"
        $iOSdevices = Get-IntuneManagedDevice -Filter "contains(operatingSystem,'iOS')" | Select-Object deviceName,id,osVersion,emailAddress,lastSyncDateTime,model
    }
    catch {
        Write-Verbose -Verbose -Message "Failed to retrieve all iOS devices. Script is breaking"
        break
    }
}

# Intune custom notification content
$JSON = @"
{
  "notificationTitle": "Helpdesk kindly reminds you..",
  "notificationBody": "Please make sure to keep iOS up to date!\n\nYou are receiving this notification because your device needs to be updated.\n\nPlease head into settings and update your iPhone/iPad as soon as possible.\n\nIf your device is not updated, access to corporate resources (e-mail, calendar, OneDrive etc.) will be blocked.\n\n** Please update iOS to version: $baselineVersion **\n\nRegards Helpdesk, www.imab.dk"
}
"@

# Loop through each iOS device
foreach ($device in $iOSDevices) {

    Write-Verbose -Verbose -Message "Looping through each iOS device found..."

    $deviceName = $device.devicename
    $id = $device.id
    $osVersion = $device.osVersion
    $email = $device.emailAddress
    $deviceModel = $device.model
    $lastSyncDate = $device.lastSyncDateTime

    # Formatting date and counting days since last sync with Intune
    $localCulture = Get-Culture
    $regionDateFormat = [System.Globalization.CultureInfo]::GetCultureInfo($LocalCulture.LCID).DateTimeFormat.LongDatePattern
    $lastSyncDate = Get-Date $lastSyncDate -f $regionDateFormat
    $Today = Get-Date -f $regionDateFormat
    $dateDiff = New-TimeSpan -Start $lastSyncDate -End $Today

    if ($dateDiff.Days -ge 0 –AND $dateDiff.Days –lt 2) {

        Write-Verbose -Verbose -Message "iOS device found: $deviceName belonging to: $email which have been syncing lately on: $lastSyncDate"

        # If the device is running an iOS version less than the baseline 
        if ($osVersion -lt $baselineVersion) {
        
            Write-Verbose -Verbose -Message "iOS device found: $deviceName belonging to $email which is running iOS version: $osVersion which is less than the baseline version: $baselineVersion"
        
            # Create the unique URL for each managed device
            $uri = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$id/sendCustomNotificationToCompanyPortal"
        
            # Create initial body area including stylesheet
            $emailBody = "
            <html>
            <head>
            <style type='text/css'>
            h1 {
            color: #002933;
            font-family: verdana;
            font-size: 20px;
            }

            h2 {
            color: ##002933;
            font-family: verdana;
            font-size: 15px;
            }

            body {
            color: #002933;
            font-family: verdana;
            font-size: 13px;
            }
            </style>
            </head>
            <h1>Attention: Your iPhone or iPad needs an update!</h1>
            <body>
            Please make sure to keep iOS up to date!<br><br>
            You are receiving this e-mail because your device needs to be updated.<br>
            On your iPhone or iPad, please head into settings and apply the latest update as soon as possible.<br>
            If your device is not updated, access to corporate resources (e-mail, calendar, OneDrive etc.) will be blocked.<br><br>
            <b>Current Device Name:</b> $deviceName<br>
            <b>Current Device Model:</b> $deviceModel<br>
            <b>Current iOS Version:</b> $osVersion<br><br>
            ** Please update iOS to version: <b>$baselineVersion</b> **<br><br>
            Best regards,<br>www.imab.dk<br/>
            </body>
            </html>
            "

            if ($sendCustomNotification -eq $true) {

                # Try to send a custom notification to each device
                try {
                    Write-Verbose -Verbose -Message "sendCustomnotification equals $sendCustomNotification. Trying to send custom notification to $deviceName"
                    Invoke-MSGraphRequest -HttpMethod POST -Url $uri -Content $JSON
                }
                catch { 
                    Write-Verbose -Verbose -Message "Failed to send custom notification to $deviceName"
                }
            }
            elseif ($sendCustomNotification -eq $false) {
                Write-Verbose -Verbose -Message "sendCustomnotification equals $sendCustomNotification. Not sending any custom notification to $deviceName"
            }
            else {
                Write-Verbose -Verbose -Message "Something seems broken. sendCustomnotification equals $sendCustomNotification. Not sending any custom notification to $deviceName"
            }

            if ($sendEmail -eq $true) {

                # Try to send an email to each user
                try {
                    Write-Verbose -Verbose -Message "SendEmail equals $sendEmail. Trying to send an e-mail to $email"
                    Send-MailMessage -To $email -From $emailFrom -Subject $emailSubject -Body $emailBody -Credential $hlpCredentials -SmtpServer $emailSmtp -Port $emailPort -UseSsl -BodyAsHtml 
                }
                catch {
                    Write-Verbose -Verbose -Message "Failed to send email to $email"
                }
            }
            elseif ($sendEmail -eq $false) {
                Write-Verbose -Verbose -Message "sendEmail equals $sendEmail. Not sending any e-mail to $email"
            }
            else {
                Write-Verbose -Verbose -Message "Something seems broken. sendEmail equals $sendEmail. Not sending any e-mail to $email"
            }
        }
    }
}