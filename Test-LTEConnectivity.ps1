function Test-LTEConnectivity {

    $lteInterface = "Cellular"

    $lteDetails = Get-NetConnectionProfile | Where-Object {$_.InterfaceAlias -eq $LTEInterface}
    
    if ($lteDetails) {
        
        if ($lteDetails.IPv4Connectivity -ne "Internet") {
            Write-Verbose -Verbose -Message "LTE connection found, but NO access to the Internet"
            Write-Output "LTE"
        }
        elseif ($lteDetails.IPv4Connectivity -eq "Internet") {
            Write-Verbose -Verbose -Message "LTE connection found with active connection to the Internet"
            Write-Output "LTE"
        }
    }
    else {
        Write-Verbose -Verbose -Message "No LTE connection was found"
        Write-Output "NOLTE"
    }
}
