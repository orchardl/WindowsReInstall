# Define the start time (current date and time)
$StartTime = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")

# Define the end time (7 days from the start time)
$EndTime = (Get-Date).AddDays(7).ToString("yyyy-MM-ddTHH:mm:ssZ")

# Function to handle errors
function Handle-Error {
    $errorMessage = $error[0].ToString()
    Write-Host "The script completed with errors. Please check and verify these errors: $errorMessage. Depending on the errors, the Windows ISO may be running in the background now."
    exit 1
}

# Set the registry values
try {
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseFeatureUpdatesStartTime" -Value $StartTime
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseFeatureUpdatesEndTime" -Value $EndTime
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseQualityUpdatesStartTime" -Value $StartTime
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseQualityUpdatesEndTime" -Value $EndTime
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseUpdatesStartTime" -Value $StartTime
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseUpdatesExpiryTime" -Value $EndTime
}
catch {
    Handle-Error
}

# Stop and restart services
try {
    Stop-Service -Name wuauserv, cryptSvc, bits, msiserver -Force

    # Restart dependent services
    Restart-Service -Name "Smartlocker Filter Driver", "Application Identity"
}
catch {
    Handle-Error
}

# Function to enumerate folder names
function Enumerate-FolderName {
    param (
        [string]$path
    )

    $suffix = 0
    $newPath = $path
    while (Test-Path -Path $newPath) {
        $suffix++
        $newPath = "{0}{1}" -f $path, $suffix
    }
    $newPath
}

# Rename folders and start services
try {
    $softwareDistributionOld = Enumerate-FolderName "C:\Windows\SoftwareDistribution.old"
    $catroot2Old = Enumerate-FolderName "C:\Windows\System32\catroot2.old"

    Rename-Item -Path "C:\Windows\SoftwareDistribution" -NewName $softwareDistributionOld -Force
    Rename-Item -Path "C:\Windows\System32\catroot2" -NewName $catroot2Old -Force

    Start-Service -Name wuauserv, cryptSvc, bits, msiserver
}
catch {
    Handle-Error
}

# Mount iso and run it in the background
try {
    Mount-DiskImage -ImagePath (Join-Path -Path (Get-Location).Path -ChildPath "\windows.iso")
    & D:\setup.exe /Auto Upgrade /eula accept /Quiet
}
catch {
    Handle-Error
}

# Remove the registry values to unpause updates
try {
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseFeatureUpdatesEndTime" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseFeatureUpdatesStartTime" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseQualityUpdatesEndTime" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseQualityUpdatesStartTime" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseUpdatesExpiryTime" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings" -Name "PauseUpdatesStartTime" -ErrorAction SilentlyContinue
}
catch {
    Handle-Error
}

Write-Host "The script completed without errors. The Windows ISO will reinstall in the background and will restart in the next 15-30 minutes."
