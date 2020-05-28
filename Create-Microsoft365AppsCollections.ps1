<#
.SYNOPSIS
    Create collections in Microsoft Endpoint Manager Configuration Manager for Microsoft 365 Apps
    
.DESCRIPTION
    Create collections in Microsoft Endpoint Manager Configuration Manager for Microsoft 365 Apps
    Specifically collections based on the new update channels as well as a general Pilot and Production collection. Everything used for deployment of updates for Microsoft 365 Apps

.NOTES
    Filename: Create-Microsoft365AppsCollections.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    https://www.imab.dk/create-device-collections-for-the-new-microsoft-365-apps-update-channels-in-a-jiffy-using-powershell

.CREDIT
    Credit to Benoit Lecours from www.systemcenterdudes.com. Creation of collections are kindly borrowed from his script: https://gallery.technet.microsoft.com/Set-of-Operational-SCCM-19fa8178
#>

begin {

    # Create the Connect-ConfigMgr function used to connecting to the CM environment using Powershell
    function Connect-ConfigMgr() {
        # Load Configuration Manager PowerShell Module
        if((Get-Module ConfigurationManager) -eq $null) {
            Write-Verbose -Verbose -Message "The Configuration Manager Powershell module is not loaded already. Loading it"
            try {
                Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
                Write-Verbose -Verbose -Message "Successfully loaded the Configuration Manager Powershell module"
            }
            catch {
                Write-Verbose -Verbose -Message "Failed to import Configuration Manager Powershell module"
                Write-Verbose -Verbose -Message "The Configuration Manager powershell module can be installed by installing the CM admin console"
                break
            }
        }

        # Connect to the CM site drive if it's not already present
        if((Get-PSDrive -Name $cmSiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
            Write-Verbose -Verbose -Message "Connecting to the CM site using $cmSiteCode and $cmProviderName"
            try {
                New-PSDrive -Name $cmSiteCode -PSProvider CMSite -Root $cmProviderName
                Write-Verbose -Verbose -Message "Successfully connected to the CM site"
            }
            catch {
                Write-Verbose -Verbose -Message "Failed to connect to the CM site using $cmSiteCode and $cmProviderName"
                break
            }
        }

        # Set the current location to be the site code
        if((Get-Location).Path -notmatch $cmSiteCode) {
            Write-Verbose -Verbose -Message "Setting current location to CM site code: $cmSiteCode"
            try {
                Set-Location "$($cmSiteCode):\"
                Write-Verbose -Verbose -Message "Successfully set the current location to the CM site code: $cmSiteCode"
            }
            catch {
                Write-Verbose -Verbose -Message "Failed to set the current location to CM site code: $cmSiteCode"
                break
            }
        }
    }

    ### VARIABLES
    ### EDIT HERE with your own details
    $cmSiteCode = "KR1"
    $cmProviderName = "florida.interntnet.dk"
    $cmCollectionFolderName = "Microsoft 365 Apps"
    $cmCollectionFolder = ($cmSiteCode + ":" + "\DeviceCollection" + "\$cmCollectionFolderName")
    $limitingCollection = "All Systems"
    $pilotLimitingCollection = "Software Updates - Pilots"

    $dummyObject = New-Object -TypeName PSObject
    $cmCollections = @()

    # Microsoft 365 Apps Production
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Production"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
        SMS_R_System inner join SMS_G_System_ADD_REMOVE_PROGRAMS_64 on SMS_G_System_ADD_REMOVE_PROGRAMS_64.ResourceID = SMS_R_System.ResourceId where 
         SMS_G_System_ADD_REMOVE_PROGRAMS_64.DisplayName like 'Microsoft Office 365 ProPlus%' or SMS_G_System_ADD_REMOVE_PROGRAMS_64.DisplayName like 'Microsoft 365 for enterprise%'"}},@{L="LimitingCollection"
    ; E={$LimitingCollection}},@{L="Comment"
    ; E={""}}

    # Microsoft 365 Apps Pilot
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Pilot"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
         SMS_R_System inner join SMS_G_System_ADD_REMOVE_PROGRAMS_64 on SMS_G_System_ADD_REMOVE_PROGRAMS_64.ResourceID = SMS_R_System.ResourceId where 
         SMS_G_System_ADD_REMOVE_PROGRAMS_64.DisplayName like 'Microsoft Office 365 ProPlus%' or SMS_G_System_ADD_REMOVE_PROGRAMS_64.DisplayName like 'Microsoft 365 for enterprise%'"}},@{L="LimitingCollection"
    ; E={$PilotLimitingCollection}},@{L="Comment"
    ; E={""}}

    # Beta Channel Production
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Beta Channel - Production"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
        SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = 
        SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 'BetaChannel' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 
        'InsiderFast' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/5440fd1f-7ecb-4221-8110-145efaa6372f'"}},@{L="LimitingCollection"
    ; E={$LimitingCollection}},@{L="Comment"
    ; E={""}}

    # Beta Channel Pilot
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Beta Channel - Pilot"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
        SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = 
        SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 'BetaChannel' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 
        'InsiderFast' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/5440fd1f-7ecb-4221-8110-145efaa6372f'"}},@{L="LimitingCollection"
    ; E={$PilotLimitingCollection}},@{L="Comment"
    ; E={""}}

    # Current Channel Production
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Current Channel - Production"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
         SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = 
         SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 'Current' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 
         'Monthly' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60'"}},@{L="LimitingCollection"
    ; E={$LimitingCollection}},@{L="Comment"
    ; E={""}}

    # Current Channel Pilot
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Current Channel - Pilot"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
         SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = 
         SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 'Current' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 
         'Monthly' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/492350f6-3a01-4f97-b9c0-c7c6ddf67d60'"}},@{L="LimitingCollection"
    ; E={$PilotLimitingCollection}},@{L="Comment"
    ; E={""}}

    # Current Channel (Preview) Production
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Current Channel (Preview) - Production"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
         SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = 
         SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 'CurrentPreview' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 
         'FirstReleaseCurrent' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be'"}},@{L="LimitingCollection"
    ; E={$LimitingCollection}},@{L="Comment"
    ; E={""}}

    # Current Channel (Preview) Pilot
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Current Channel (Preview) - Pilot"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
         SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = 
         SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 'CurrentPreview' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 
         'FirstReleaseCurrent' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/64256afe-f5d9-4f86-8936-8840a6a4f5be'"}},@{L="LimitingCollection"
    ; E={$PilotLimitingCollection}},@{L="Comment"
    ; E={""}}
    
    # Monthly Enterprise Channel Production
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Monthly Enterprise Channel - Production"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
         SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 
         'MonthlyEnterprise' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6'"}},@{L="LimitingCollection"
    ; E={$LimitingCollection}},@{L="Comment"
    ; E={""}}

    # Monthly Enterprise Channel Pilot
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Monthly Enterprise Channel - Pilot"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
        SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 
        'MonthlyEnterprise' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/55336b82-a18d-4dd6-b5f6-9e5095c314a6'"}},@{L="LimitingCollection"
    ; E={$PilotLimitingCollection}},@{L="Comment"
    ; E={""}}

    # Semi-Annual Enterprise Channel Production
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Semi-Annual Enterprise Channel - Production"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
        SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = 
        SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 'SemiAnnual' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 
        'Deferred' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114'"}},@{L="LimitingCollection"
    ; E={$LimitingCollection}},@{L="Comment"
    ; E={""}}

    # Semi-Annual Enterprise Channel Pilot
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Semi-Annual Enterprise Channel - Pilot"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
        SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = 
        SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 'SemiAnnual' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 
        'Deferred' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/7ffbc6bf-bc32-4f92-8982-f9dd17fd3114'"}},@{L="LimitingCollection"
    ; E={$PilotLimitingCollection}},@{L="Comment"
    ; E={""}}

    # Semi-Annual Enterprise Channel (Preview) Production
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Semi-Annual Enterprise Channel (Preview) - Production"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
        SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = 
        SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 'SemiAnnualPreview' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 
        'FirstReleaseDeferred' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf'"}},@{L="LimitingCollection"
    ; E={$LimitingCollection}},@{L="Comment"
    ; E={""}}

    # Semi-Annual Enterprise Channel (Preview) Pilot
    $cmCollections +=
    $dummyObject |
    Select-Object @{L="Name"
    ; E={"Microsoft 365 Apps - Semi-Annual Enterprise Channel (Preview) - Pilot"}},@{L="Query"
    ; E={"select SMS_R_SYSTEM.ResourceID,SMS_R_SYSTEM.ResourceType,SMS_R_SYSTEM.Name,SMS_R_SYSTEM.SMSUniqueIdentifier,SMS_R_SYSTEM.ResourceDomainORWorkgroup,SMS_R_SYSTEM.Client from 
        SMS_R_System inner join SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS on SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.ResourceID = 
        SMS_R_System.ResourceId where SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 'SemiAnnualPreview' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.GPOChannel = 
        'FirstReleaseDeferred' or SMS_G_System_OFFICE365PROPLUSCONFIGURATIONS.cfgUpdateChannel = 'http://officecdn.microsoft.com/pr/b8f9b850-328d-4355-9145-c59439a0c4cf'"}},@{L="LimitingCollection"
    ; E={$PilotLimitingCollection}},@{L="Comment"
    ; E={""}}
}
process {

    # Connecting to the Configuration Manager environment
    Connect-ConfigMgr

    # Continuing if indeed is connected to the CM site code
    if((Get-Location).Path -match $cmSiteCode) {
        
        # Configuring the refresh schedule post being connected to the CM site. This is needed in order to be able to use the CM cmdlet
        $refreshSchedule = New-CMSchedule –RecurInterval Days –RecurCount 7
        
        # Creating the configured device collection folder if it does not exist
        if ((Test-Path -Path $cmCollectionFolder) -eq $false) {
	        Write-Verbose -Verbose -Message "The folder $cmCollectionFolder does not exist in CM. Creating it"
            try {
                New-Item -Path $cmCollectionFolder
                Write-Verbose -Verbose -Message "Successfully created the folder: $cmCollectionFolder"
	        }
            catch {
                Write-Verbose -Verbose -Message "Failed to create the folder: $cmCollectionFolder"
            }
        }
        
        # Testing for the existence of configured device collections. They need to exist in order to successfully create the new collections
        $testLimitingCollection = Get-CMDeviceCollection -Name $limitingCollection
        $testPilotLimitingCollection = Get-CMDeviceCollection -Name $pilotLimitingCollection

        if (-NOT($testLimitingCollection) -OR (-NOT($testPilotLimitingCollection))) {
            Write-Verbose -Verbose -Message "Either of the configured limiting collections does not exist. This should be fixed before continuing"
            break
        }

        # Continue creating new collections, if the configured limiting collections do exist
        elseif (($testLimitingCollection) -AND ($testPilotLimitingCollection)) {
            foreach ($cmCollection in $($cmCollections | Sort-Object LimitingCollection)) {
                try {
                    New-CMDeviceCollection -Name $cmCollection.Name -Comment $cmCollection.Comment -LimitingCollectionName $cmCollection.LimitingCollection -RefreshSchedule $refreshSchedule -RefreshType 2 | Out-Null
                    Add-CMDeviceCollectionQueryMembershipRule -CollectionName $cmCollection.Name -QueryExpression $cmCollection.Query -RuleName $cmCollection.Name
                    Write-Verbose -Verbose -Message "*** Collection $($cmCollection.Name) created ***"
                }
                catch [System.Exception] {
                    Write-Warning -Message "An error occured while attempting to create the collection. Error message: $($_.Exception.Message)"
                }
                try {
                    Move-CMObject -FolderPath $cmCollectionFolder -InputObject $(Get-CMDeviceCollection -Name $cmCollection.Name)
                    Write-Verbose -Verbose -Message "*** Collection $($cmCollection.Name) moved to $cmCollectionFolderName folder ***"
                }
                catch [System.Exception] {
                    Write-Warning -Message "An error occured while attempting to move the collection. Error message: $($_.Exception.Message)"
                }
            }
        }
    }
}

end {
    # nothing to see here
}