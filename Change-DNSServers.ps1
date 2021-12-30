<#
.SYNOPSIS
    Set or change configured DNS servers. Something I created as I needed to change DNS servers on a large scale of servers.
   
.DESCRIPTION
    Same as above

.NOTES
    Filename: Change-DNSServers.ps1
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    
#>

param(
	[Parameter(Mandatory=$true)]
	[string]$primDNS,
	[Parameter(Mandatory=$true)]
	[string]$secDNS,
	[Parameter(Mandatory=$false)]
    [string]$addressFam = "IPv4"
)
begin {
    function Get-InterfaceIndex() {
        # Finding net adapters which is Up and ConnectorPresent is TRUE 
        $netAdaptUp = Get-NetAdapter | Where-Object {$_.Status -eq "Up" -AND $_.ConnectorPresent -eq $True}
        if (-NOT[string]::IsNullOrEmpty($netAdaptUp)) {
            Write-Output $netAdaptUp.ifIndex
            Write-Output $netAdaptUp.InterfaceDescription
        }
    }
    function Change-DNSServers($fIfIndex,$fAddressFam,$fPrimDNS,$fSecDNS) {
        # Setting the primDNS and secDNS to 0 will result in a reset to default DNS server addresses
        if (($primDNS -eq 0) -OR ($secDNS -eq 0)) {
            Write-Verbose -Verbose -Message "priDNS and secDNS is null. Resetting DNS server addresses to default on $global:ifDescription"
            try {
                Set-DnsClientServerAddress -InterfaceIndex $fIfIndex -ResetServerAddresses            
            }
            catch {
                Write-Verbose -Verbose -Message "Failed to run -ResetServerAddresses"
            }
        }
        else {
            $currentDNS = Get-DnsClientServerAddress -AddressFamily $fAddressFam -InterfaceIndex $fIfIndex | Where-Object {$_.ServerAddresses -notcontains $fPrimDNS}
            if (-NOT[string]::IsNullOrEmpty($currentDNS)) {
                try {
                    Set-DnsClientServerAddress -InterfaceIndex $fIfIndex -ServerAddresses ("$fPrimDNS","$fSecDNS")
                    Write-Verbose -Verbose -Message "successfully changed the DNS servers on $global:ifDescription to primDNS: $primDNS and secDNS: $secDNS"
                }
                catch {
                    Write-Verbose -Verbose -Message "Failed to change the DNS servers on $global:ifDescription"
                }
            }
            else {
                Write-Verbose -Verbose -Message "No changes to DNS on $global:ifDescription required. Doing nothing."
            }
        }
    }
}
process {
    $ifIndex = (Get-InterfaceIndex)[0]
    $global:ifDescription = (Get-InterfaceIndex)[1]
    Change-DNSServers -fIfIndex $ifIndex -fAddressFam $addressFam -fPrimDNS $primDNS -fSecDNS $secDNS
}
end { 
    #Nothing to see here
}