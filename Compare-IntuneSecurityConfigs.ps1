<#
.SYNOPSIS
    Compare Security Configurations in Microsoft Endpoint Manager Intune   
   
.DESCRIPTION
    Compare Security Baselines or any other configuration made in the Endpoint security node of Microsoft Endpoint Manager Intune

.NOTES
    Filename: Compare-IntuneSecurityConfigs.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    https://www.imab.dk/comparing-security-baselines-in-endpoint-manager-using-powershell-and-microsoft-graph/    
#> 

$originalProfileName = "Security Baseline - Windows 10 1903"
$modifiedProfileName = "Security Baseline - Windows 10 - August 2020 - Default Values"

function Compare-IntuneSecurityConfigs() {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$originalProfileName,
        [ValidateNotNullOrEmpty()]
        [Parameter(Mandatory=$true)]
        [string]$modifiedProfileName
    )
    begin {
        $uri = "https://graph.microsoft.com/beta/deviceManagement/intents"
        $securityConfigs = (Invoke-MSGraphRequest -Url $uri -HttpMethod GET).Value 
        $returnReport = @()
        $differentiatingSettings = @()
    }
    process {
        foreach ($config in $securityConfigs) {
            Write-Host -ForegroundColor Red $config.displayName
            if ($config.displayName -eq $originalProfileName) {
                Write-Host -ForegroundColor Green $config.displayName
                Write-Host -ForegroundColor Green $config.Id
                $originalConfigSettings = Invoke-MSGraphRequest -Url "https://graph.microsoft.com/beta/deviceManagement/intents/$($config.id)/settings"
                $originalSettings = @()
                foreach ($originalConfigSetting in $originalConfigSettings.value) {
                    $originalConfigSettingDisplayName = $originalConfigSetting.definitionId -replace "deviceConfiguration--","" -replace "admx--",""  -replace "_"," "
                    $originalConfigSetting = [PSCustomObject]@{ SettingName = $originalConfigSettingDisplayName; Value = $originalConfigSetting.value; Id = $originalConfigSetting.id }
                    $originalSettings += $originalConfigSetting
                }
                $originalSettingsCount = $originalSettings.count
                $returnReport += "Original Security Configuration Name: $($config.displayName)"
                $returnReport += "Original Settings Count: $originalSettingsCount"
            }
            if ($config.displayName -eq $modifiedProfileName) {
                Write-Host -ForegroundColor Green $config.displayName
                Write-Host -ForegroundColor Green $config.Id
                $modifiedConfigSettings = Invoke-MSGraphRequest -Url "https://graph.microsoft.com/beta/deviceManagement/intents/$($config.id)/settings"
                $modifiedSettings = @()
                foreach ($modifiedConfigSetting in $modifiedConfigSettings.value) {
                    $modifiedConfigSettingDisplayName = $modifiedConfigSetting.definitionId -replace "deviceConfiguration--","" -replace "admx--",""  -replace "_"," "
                    $modifiedConfigSetting = [PSCustomObject]@{ SettingName = $modifiedConfigSettingDisplayName; Value = $modifiedConfigSetting.value; Id = $modifiedConfigSetting.id }
                    $modifiedSettings += $modifiedConfigSetting
                }
                $modifiedSettingsCount = $modifiedSettings.Count
                $returnReport += "Modified Security Configuration Name: $($config.displayName)"
                $returnReport += "Modified Settings Count: $modifiedSettingsCount"
            }
        }
        if (-NOT[string]::IsNullOrEmpty($originalSettings) -AND (-NOT[string]::IsNullOrEmpty($modifiedSettings))) {
            try {
                $compare = Compare-Object -ReferenceObject $originalSettings.SettingName -DifferenceObject $modifiedSettings.SettingName
            }
            catch {
                Write-Verbose -Verbose -Message "Comparison of profiles failed" ; break
            }
        }
        if (-NOT[string]::IsNullOrEmpty($compare)) {
            $returnReport += "***********************************************"
            $returnReport += "TOTAL CHANGES($($compare.count)):"
            foreach ($change in $compare) {
                if ($change.SideIndicator -eq "=>") {
                    $returnReport += "ADDED IN $modifiedProfileName : $($change.InputObject)"
                }
                if ($change.SideIndicator -eq "<=") {
                    $returnReport += "REMOVED IN $modifiedProfileName : $($change.InputObject)"
                }
            }
        }
        else {
            # nothing
        }
        foreach ($origSetting in $originalSettings) {
            foreach ($modSetting in $modifiedSettings) {
                if ($origSetting.SettingName -eq $modSetting.SettingName) {
                    if ($origSetting.Value -ne $modSetting.Value) {
                        $differentiatingValues = $true
                        $differentiatingSettings += $origSetting.SettingName
                        $returnReport += "***********************************************"
                        $returnReport += "SETTING: $($origSetting.SettingName) has differentiating values!!"
                        $compareValue = Compare-Object -ReferenceObject $origSetting.Value -DifferenceObject $modSetting.Value
                        if (-NOT[string]::IsNullOrEmpty($compareValue)) {
                            foreach ($change in $compareValue) {
                                if ($change.SideIndicator -eq "=>") {
                                    $returnReport += "CONFIGURED IN $modifiedProfileName : $($change.InputObject)"
                                }
                                if ($change.SideIndicator -eq "<=") {
                                    $returnReport += "CONFIGURED IN $originalProfileName : $($change.InputObject)"
                                }
                            }
                            # Tried something, didn't work. Keeping for future reference.
                            #$originalResult = $compareValue.inputobject[0]
                            #$modifiedResult = $compareValue.inputobject[1]
                            #$returnReport += $compareValue
                            #$returnReport += "PROFILE NAME: $originalProfileName has SETTING: $($origSetting.SettingName) configured to $originalResult"
                            #$returnReport += "PROFILE NAME: $modifiedProfileName has SETTING: $($modSetting.SettingName) configured to $modifiedResult"
                        }
                    }
                }
            }
        }
    }
    end { 
        if (-NOT[string]::IsNullOrEmpty($returnReport)) {
            Write-Output $returnReport
            try {
                $returnReport | Out-File -FilePath $env:TEMP\Compare-IntuneSecurityConfigs.txt -Force -Encoding UTF8
            }
            catch {
                Write-Verbose -Verbose -Message "Failed to create report as .txt file"
            }
            if (Test-Path -Path $env:TEMP\Compare-IntuneSecurityConfigs.txt) {
                Invoke-Item -Path $env:TEMP\Compare-IntuneSecurityConfigs.txt
            }
        }
    }
}

Compare-IntuneSecurityConfigs -originalProfileName $originalProfileName -modifiedProfileName $modifiedProfileName

