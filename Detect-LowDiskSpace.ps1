$os = Get-CimInstance Win32_OperatingSystem
$systemDrive = Get-CimInstance Win32_LogicalDisk -Filter "deviceid='$($os.SystemDrive)'"
if (($systemDrive.FreeSpace/$systemDrive.Size) -le '0.70') {
    Write-Output "Disk space is considered low. Script is exiting with 1 indicating error"
    exit 1
}
else {
    Write-Output "Disk space is OK."
    exit 0
}