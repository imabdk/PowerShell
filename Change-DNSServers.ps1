<#
.SYNOPSIS
    Set or change configured DNS servers. Something I created as I needed to change DNS servers on a large scale of servers.
   
.DESCRIPTION
    Same as above

.NOTES
    Filename: 
    Version: 1.0
    Author: Martin Bengtsson
    Blog: www.imab.dk
    Twitter: @mwbengtsson

.LINK
    
#> 
begin {
    $global:primDNS = "8.8.8.8"
    $global:secDNS = "8.8.4.4"
    $global:addressFam = "IPv4"

    function Get-InterfaceIndex() {
        $netAdaptUp = Get-NetAdapter | Where-Object {$_.Status -eq "Up"}
        if (-NOT[string]::IsNullOrEmpty($netAdaptUp)) {
            Write-Output $netAdaptUp.ifIndex
            Write-Output $netAdaptUp.InterfaceDescription
        }
    }

    function Change-DNSServers($fIfIndex,$fAddressFam,$fPrimDNS,$fSecDNS) {
        $currentDNS = Get-DnsClientServerAddress -AddressFamily $fAddressFam -InterfaceIndex $fIfIndex | Where-Object {$_.ServerAddresses -notcontains $fPrimDNS}
        if (-NOT[string]::IsNullOrEmpty($currentDNS)) {
            try {
                Set-DnsClientServerAddress -InterfaceIndex $fIfIndex -ServerAddresses ("$fPrimDNS","$fSecDNS")
                Write-Verbose -Verbose -Message "successfully changed the DNS servers on $global:ifDescription"
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
process {
    $ifIndex = (Get-InterfaceIndex)[0]
    $global:ifDescription = (Get-InterfaceIndex)[1]
    Change-DNSServers -fIfIndex $ifIndex -fAddressFam $global:addressFam -fPrimDNS $global:primDNS -fSecDNS $global:secDNS
}
end { 
    #Nothing to see here
}