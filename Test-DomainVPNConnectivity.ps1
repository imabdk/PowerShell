function Test-DomainVPNConnectivity {

    $computerName = $env:computername
    $domainName = $env:userDNSDomain

    if ($domainName) {
        Write-Verbose -Verbose -Message "Device: $computerName is domain joined to: $domainName"

        $domainConnection = Get-NetConnectionProfile | Where-Object {$_.Name -eq $domainName}
    
        if ($domainConnection) {
            Write-Verbose -Verbose -Message "$computerName has an active connection to domain: $domainName"

            $interfaceAlias = $domainConnection.InterfaceAlias
            $domainConnectionName = $domainConnection.Name
            $domainConnectionCategory = $DomainConnection.NetworkCategory

            if (($domainConnectionName -eq $domainName) -AND ($domainConnectionCategory -eq "DomainAuthenticated")) {

                if (($interfaceAlias -like "Wi-Fi*") -OR ($interfaceAlias -like "Ethernet*")) {
                    Write-Verbose -Verbose -Message "$computerName is connected to $domainName via local network"
                    Write-Output "LAN"
                }
                elseif ($interfaceAlias -like "*VPN*") {
                    Write-Verbose -Verbose -Message "$computerName is connected to $domainName via VPN"
                    Write-Output "VPN"
                }
            }
        }
        else {
            Write-Verbose -Verbose -Message "$computerName does not have an active connection to domain: $domainName"
            Write-Output "NODOMAIN"
        }
    }
    else {
        Write-Verbose -Verbose -Message "Looks like that $computerName is not domain joined"
        Write-Output "NOTDOMAINJOINED"
    }
}
