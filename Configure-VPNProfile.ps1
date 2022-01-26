<#
<#
.SYNOPSIS
    This scripts configures the relevant VPN profile, and sets the versioning in registry
   
.DESCRIPTION
    Currently when configuring the VPN profile via Intune and assign it to Windows 11 devices, Intune comes back with some random errors.
    Event logs comes back with event id 404, error CSP URI: (./User/Vendor/MSFT/VPNv2/W11-VPN-User-Tunnel), Result: (The specified quota list is internally inconsistent with its descriptor.

    This serves as an alternative to using Configuration Profiles in Intune and instead leverage Proactive Remediations.

.NOTES
    Filename: Configure-VPNProfile.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    https://imab.dk/deploy-your-always-on-vpn-profile-for-windows-11-using-proactive-remediations-in-microsoft-intune
    
#> 

$global:RegistryPath = "HKCU:\SOFTWARE\imab.dk\VPN Profile"
$global:RegistryName = "VPNProfileVersion"
$global:vpnProfileVersion  = "1"
$global:vpnProfileName = "imab.dk VPN"
$global:vpnGuid = "327EEAAC641DCE4A94093C7D90CD6341"
$global:currentDate = Get-Date -Format g
[String]$global:VPNProfile = @'
[imab.dk VPN]
Encoding=1
PBVersion=8
Type=2
AutoLogon=1
UseRasCredentials=1
LowDateTime=-1109293792
HighDateTime=30915201
DialParamsUID=1071859
Guid=327EEAAC641DCE4A94093C7D90CD6341
VpnStrategy=5
ExcludedProtocols=0
LcpExtensions=1
DataEncryption=256
SwCompression=0
NegotiateMultilinkAlways=1
SkipDoubleDialDialog=0
DialMode=0
OverridePref=15
RedialAttempts=0
RedialSeconds=0
IdleDisconnectSeconds=0
RedialOnLinkFailure=0
CallbackMode=0
CustomDialDll=
CustomDialFunc=
CustomRasDialDll=
ForceSecureCompartment=0
DisableIKENameEkuCheck=0
AuthenticateServer=0
ShareMsFilePrint=1
BindMsNetClient=1
SharedPhoneNumbers=0
GlobalDeviceSettings=0
PrerequisiteEntry=
PrerequisitePbk=
PreferredPort=VPN2-0
PreferredDevice=WAN Miniport (IKEv2)
PreferredBps=0
PreferredHwFlow=0
PreferredProtocol=0
PreferredCompression=0
PreferredSpeaker=0
PreferredMdmProtocol=0
PreviewUserPw=0
PreviewDomain=0
PreviewPhoneNumber=0
ShowDialingProgress=0
ShowMonitorIconInTaskBar=0
CustomAuthKey=25
CustomAuthData=3144424319000000FF00000001000000FF0000000100000001000000020000005800000031000000010000001400000082D033009F07557439D7FD2B379952D2
CustomAuthData=FC96B16141004E00540057004500520050002E0049004E005400450052004E0054004E00450054002E0044004B00000001000000950000000D00000002000000
CustomAuthData=86000000310000001400000082D033009F07557439D7FD2B379952D2FC96B16141004E00540057004500520050002E0049004E005400450052004E0054004E00
CustomAuthData=450054002E0044004B00000001000000FE0006000100FD002C0082D033009F07557439D7FD2B379952D2FC96B16182D033009F07557439D7FD2B379952D2FC96
CustomAuthData=B16100000000000000000000000000
AuthRestrictions=128
IpPrioritizeRemote=0
IpInterfaceMetric=0
IpHeaderCompression=0
IpAddress=0.0.0.0
IpDnsAddress=0.0.0.0
IpDns2Address=0.0.0.0
IpWinsAddress=0.0.0.0
IpWins2Address=0.0.0.0
IpAssign=1
IpNameAssign=1
IpDnsFlags=1
IpNBTFlags=1
TcpWindowSize=0
UseFlags=2
IpSecFlags=0
IpDnsSuffix=yourdomain
Ipv6Assign=1
Ipv6Address=::
Ipv6PrefixLength=0
Ipv6PrioritizeRemote=0
Ipv6InterfaceMetric=0
Ipv6NameAssign=1
Ipv6DnsAddress=::
Ipv6Dns2Address=::
Ipv6Prefix=0000000000000000
Ipv6InterfaceId=0000000000000000
DisableClassBasedDefaultRoute=0
DisableMobility=0
NetworkOutageTime=0
IDI=
IDR=
ImsConfig=0
IdiType=0
IdrType=0
ProvisionType=0
PreSharedKey=
CacheCredentials=0
NumCustomPolicy=0
NumEku=0
UseMachineRootCert=0
Disable_IKEv2_Fragmentation=0
PlumbIKEv2TSAsRoutes=0
NumServers=1
ServerListServerName=yourvpn.domain.com
ServerListFriendlyName=ajax
RouteVersion=1
NumRoutes=12
NumNrptRules=7
AutoTiggerCapable=1
NumAppIds=0
NumClassicAppIds=0
SecurityDescriptor=
ApnInfoProviderId=
ApnInfoUsername=
ApnInfoPassword=
ApnInfoAccessPoint=
ApnInfoAuthentication=1
ApnInfoCompression=0
DeviceComplianceEnabled=0
DeviceComplianceSsoEnabled=0
DeviceComplianceSsoEku=
DeviceComplianceSsoIssuer=
FlagsSet=8419
Options=2
DisableDefaultDnsSuffixes=1
NumTrustedNetworks=1
NumDnsSearchSuffixes=1
PowershellCreatedProfile=0
ProxyFlags=0
ProxySettingsModified=0
ProvisioningAuthority=
AuthTypeOTP=0
GREKeyDefined=0
NumPerAppTrafficFilters=0
AlwaysOnCapable=1
DeviceTunnel=0
PrivateNetwork=1
ManagementApp=

NETCOMPONENTS=
ms_msclient=1
ms_server=1

MEDIA=rastapi
Port=VPN2-0
Device=WAN Miniport (IKEv2)

DEVICE=vpn
PhoneNumber=yourvpn.domain.com
AreaCode=
CountryCode=0
CountryID=0
UseDialingRules=0
Comment=
FriendlyName=
LastSelectedPhone=0
PromoteAlternates=0
TryNextAlternateOnFail=1
'@

function Configure-VPNProfile() {
    $rasphoneFile = "$env:APPDATA\Microsoft\Network\Connections\Pbk\rasphone.pbk"
    $rasphoneFileTest = Test-Path -Path $rasphoneFile -ErrorAction SilentlyContinue
    if ($rasphoneFileTest -eq $true) {
        try {
            $rasFileContent = Get-Content -Path $rasphoneFile
        }
        catch {
            Write-Output "Could not get content of rasphone file: $rasphoneFile. Doing nothing."
            exit 1
        }
        if (-NOT[string]::IsNullOrEmpty($rasFileContent)) {
            if (($rasFileContent -contains "[$global:vpnProfileName]") -OR ($rasFileContent -contains "Guid=$global:vpnGuid")) {
                Write-Output "VPN profile is already present in rasphone.pbk file: $rasphoneFile. In this case, replacing the entire rasphone.pbk file"
                try {
                    $global:VPNProfile | Out-File -FilePath $rasphoneFile -Encoding ascii -Force
                    $rasphoneFileStatus = $true
                }
                catch {
                    Write-Output "Could not create new rasphone file: $rasphoneFile"
                    $rasphoneFileStatus = $false
                }
            }
            else {
                Write-Output "VPN profile was not found in rasphone.pbk file: $rasphoneFile. In this case, adding VPN profile to existing rasphone.pbk file"
                try {
                    Add-Content -Path $rasphoneFile -Value $global:VPNProfile
                    $rasphoneFileStatus = $true
                }
                catch {
                    Write-Output "Could not add-content to rasphone file: $rasphoneFile"
                    $rasphoneFileStatus = $false
                }
            }
        }
    }
    elseif ($rasphoneFileTest -eq $false) {
        Write-Output "rasphone.pbk file not found: $rasphoneFile. Creating new file from scratch"
        try {
            $global:VPNProfile | Out-File -FilePath $rasphoneFile -Encoding ascii -Force
            $rasphoneFileStatus = $true
        }
        catch {
            Write-Output "Could not create new rasphone file: $rasphoneFile"
            $rasphoneFileStatus = $false
        }
    }
}

function Set-VPNProfileVersion() {
    if (-NOT(Test-Path -Path $global:RegistryPath)) {
        New-Item -Path $global:RegistryPath -Force | Out-Null
    }
    if (Test-Path -Path $global:RegistryPath) {
        if (((Get-Item -Path $global:RegistryPath -ErrorAction SilentlyContinue).Property -contains $RegistryName) -ne $true) {
             New-ItemProperty -Path $global:RegistryPath -Name $global:RegistryName -Value "0" -PropertyType "String" -Force | Out-Null
        }
        if (((Get-Item -Path $global:RegistryPath -ErrorAction SilentlyContinue).Property -contains $RegistryName) -eq $true) {
            if ((Get-ItemProperty -Path $global:RegistryPath -Name $global:RegistryName -ErrorAction SilentlyContinue).$global:RegistryName -ine $global:vpnProfileVersion) {
                Write-Output "VPN profile version in registry is not equal to $global:vpnProfileVersion. Updating value in registry"
                New-ItemProperty -Path $global:RegistryPath -Name $global:RegistryName -Value $global:vpnProfileVersion -PropertyType "String" -Force | Out-Null
                New-ItemProperty -Path $global:RegistryPath -Name RunDateTime -Value $global:currentDate -PropertyType "String" -Force | Out-Null

            }
        }
    }
}

try {
    Configure-VPNProfile
    Set-VPNProfileVersion
}
catch { 
    Write-Output "Script failed to run"
    exit 1
}
finally { 
    if ($rasphoneFileStatus -eq $true) {
        Write-Output "rasphoneFileStatus equals True. Exiting with 0"
        exit 0
    }
    elseif ($rasphoneFileStatus -eq $false) {
        Write-Output "rasphoneFileStatus equals False. Exiting with 1"
        exit 1
    }
}