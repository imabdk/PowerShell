try {
    # Company Name. This is a part of the paths which are referenced in the precaching task sequence.
    $companyName = "KromannReumert"
    # Windows version. This is a part of the paths which are referenced in the precaching task sequence.
    $waasVersion = "v2004"
    # The content path for this In-Place Upgrade
    $ipuContentPath = "$env:ProgramData\$companyName\IPUContent\$waasVersion"
    # The path where the drivers (WIM file) are precached to by the task sequence
    $driversContentPath = "$env:ProgramData\$companyName\IPUContent\$waasVersion\Drivers"
    # Get the computer version/model. This is used to grab the correct WIM file dynamically. 
    # This requires, that the WIM file is named accordingly
    # The output of this on a Lenovo ThinkPad T480s is 'ThinkPad T480s', why the WIM file is also named 'ThinkPad T480s.wim'
    $computerModel = (Get-CimInstance Win32_ComputerSystemProduct).Version
    if (-NOT[string]::IsNullOrEmpty($computerModel)) {
        $compuderModel = (Get-CimInstance -Class Win32_ComputerSystem).Model  
    }
    # Find the WIM file containing the drivers. This is where the computer model needs to match the precached WIM file
    $findDrivers = (Get-ChildItem -Path $driversContentPath -Recurse | Where-Object {$_.FullName -match $computerModel}).FullName
    # Mount drivers if a matching WIM file was found
    if (-NOT[string]::IsNullOrEmpty($findDrivers)) {
        if (-NOT(Test-Path -Path $ipuContentPath\MountDrivers)) { New-Item -Path $ipuContentPath -Name MountDrivers -ItemType Directory }
        dism.exe /mount-wim /wimfile:$findDrivers /index:1 /mountdir:$ipuContentPath\MountDrivers
    }
}
catch {
    Write-Verbose -Verbose -Message "Failed to mount WIM containing drivers"
    exit 1
}