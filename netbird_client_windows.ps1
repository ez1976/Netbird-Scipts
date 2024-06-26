

# Define the required version
$requiredVersion = "0.28.3"
$minimalVersion = [version]"0.28.1"
$netbird_domain = "your netbird domain"
$netbird_device_port = "33073"
$netbird_web_port = "443"

# Disable ipv6
Disable-NetAdapterBinding -Name "*" -ComponentID ms_tcpip6

# Define the installation function
function InstallNetbird {
    # Add installation logic here
    echo Installing/Upgrading netbird
    tskill netbird-ui > $null 2>&1
    Stop-Service -Name "NetBird" > $null 2>&1
    # Get the ProductCode of Netbird
    $ProductCode = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object { $_.DisplayName -eq "Netbird" }).PSChildName

    if ($ProductCode) {
        # Run the uninstaller
        Write-Host "Uninstalling Netbird..."
        Start-Process -FilePath "msiexec.exe" -ArgumentList "/x $ProductCode /qn" -Wait > $null 2>&1
        Write-Host "Netbird has been uninstalled."
    } else {
        Write-Host "Netbird is not installed on this system."
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    (New-Object System.Net.WebClient).DownloadFile("https://github.com/netbirdio/netbird/releases/download/v${requiredVersion}/netbird_installer_${requiredVersion}_windows_amd64.msi", "$env:TEMP/Netbird.msi")

    cd $env:TEMP
    Start-Process msiexec.exe -NoNewWindow -ArgumentList "-i Netbird.msi /quiet"
    Start-Sleep -Seconds 20
    Stop-Service -Name "NetBird" > $null 2>&1
    sleep 3
    tskill netbird-ui > $null 2>&1

 
        Start-Service -Name "NetBird" > $null 2>&1
}


function configure_start_script { 
    Remove-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\Environment' -Name NB_ICE_RELAY_ACCEPTANCE_MIN_WAIT_SEC   > $null 2>&1

    # Display a message
    echo "Updating config file"

    # Define the new values
    $newManagementURL = "${netbird_domain}:${netbird_device_port}"
    $newWebURL = "${netbird_domain}:${netbird_web_port}"

    # Path to the config.json file
    $configFilePath = "C:\ProgramData\Netbird\config.json"

    # Read the contents of the file
    $configContent = Get-Content -Path $configFilePath -Raw

    # Replace the strings in the configuration file
    $newConfigContent = $configContent  -replace 'app.netbird.io:443', $newWebURL -replace 'api.netbird.io:443', $newManagementURL

    # Generate a random number between 20000 and 30000
    $randomWgPort = Get-Random -Minimum 20000 -Maximum 30001

    # Create the replacement string
    $replacementString = '"WgPort": ' + $randomWgPort + ','

    # Replace the WgPort line with the new random number
    $newConfigContent = $newConfigContent -replace '"WgPort": \d+,', $replacementString

    # Write the updated content back to the config file
    Set-Content -Path $configFilePath -Value $newConfigContent

    echo "Config file updated successfully"
    Select-String -Path "C:\ProgramData\Netbird\config.json" -Pattern "33073"

    #create the custom script to run
    @'
@echo off
netbird status > "%temp%\netbird_status.txt" 2>&1

REM Check if the word "error" appears in the output file
findstr /C:"error" "%temp%\netbird_status.txt" > NUL
if "%ERRORLEVEL%"=="0" (
    REM If error is found, restart NetBird service
    tskill netbird-ui   > NUL 2>&1
    netbird service restart  > NUL 2>&1
    netbird service start  > NUL 2>&1
)
REM Define the path to the Netbird executable
set "programPath=C:\Program Files\Netbird\netbird-ui.exe"
    REM If the program is not running, start it
    start "" "%programPath%"
    :startNetbird
    tskill netbird-ui
    start netbird-ui
'@ | Set-Content -Path "C:\ProgramData\Netbird\netbird-ui-qwilt.bat" -Encoding UTF8

#creating ssh script
$userName = $env:USERNAME

    #create net netbird shortcut file
            # Define the path to the shortcut file
    $shortcutPath = "C:\ProgramData\Microsoft\Windows\Start Menu\NetBird.lnk"

    # Define the target path and arguments
    $targetPath = "C:\ProgramData\Netbird\netbird-ui-qwilt.bat"

    # Define the start-in directory
    $startIn = "C:\Program Files\Netbird"

    # Define the icon path
    $iconPath = "C:\Program Files\Netbird\netbird-ui.exe"

    # Create a WScript Shell object
    $shell = New-Object -ComObject WScript.Shell

    # Create a shortcut object
    $shortcut = $shell.CreateShortcut($shortcutPath)

    # Set shortcut properties
    $shortcut.TargetPath = $targetPath
    $shortcut.Arguments = $arguments
    $shortcut.WorkingDirectory = $startIn
    $shortcut.IconLocation = $iconPath
    $shortcut.WindowStyle = 7  # 7 corresponds to "Minimized"

    # Save the shortcut
    $shortcut.Save()

    # set netbird shortcut to run as administrator
    $bytes = [System.IO.File]::ReadAllBytes("C:\ProgramData\Microsoft\Windows\Start Menu\NetBird.lnk")
    $bytes[0x15] = $bytes[0x15] -bor 0x20 #set byte 21 (0x15) bit 6 (0x20) ON
    [System.IO.File]::WriteAllBytes("C:\ProgramData\Microsoft\Windows\Start Menu\NetBird.lnk", $bytes)
    Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\NetBird.lnk" -Destination "C:\Users\Public\Desktop"

    # Define the registry path
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"

    # Define the item properties
    $itemName = "netbird"
    $itemType = "String"  # For REG_EXPAND_SZ, we use "String"
    $itemData = "C:\Program Files\Netbird\netbird-ui.exe"

    # Remove the existing registry item if it exists
    if (Get-ItemProperty -Path $registryPath -Name $itemName -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $registryPath -Name $itemName -ErrorAction SilentlyContinue
        #Write-Output "Existing registry entry '$itemName' removed."
    }

    # Add the new registry item
    New-ItemProperty -Path $registryPath -Name $itemName -PropertyType $itemType -Value $itemData  > $null 2>&1

    #showing all icons in the traybar
    Set-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer EnableAutoTray 0

    # Step 1: Get the active user that is currently logged in
    $currentUser = Invoke-Expression -Command "whoami"

    # Step 2: Get the path to the user's desktop using environment variables
    $desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::DesktopDirectory)

    # Step 3: Check if the user's desktop folder exists
    if (Test-Path -Path $desktopPath -PathType Container) {
        Set-Location -Path $desktopPath
        Start-Process -FilePath "C:\ProgramData\Microsoft\Windows\Start Menu\NetBird.lnk"
    } else {
        Write-Host "Desktop folder not found for user: $currentUser"
    }

    # Unregister the scheduled task
    Unregister-ScheduledTask -TaskName "Run netbird on Resume" -Confirm:$false -ErrorAction SilentlyContinue  > $null 2>&1
    Unregister-ScheduledTask -TaskName "Run netbird on login" -Confirm:$false -ErrorAction SilentlyContinue  > $null 2>&1

}

#[Environment]::SetEnvironmentVariable("NB_ICE_RELAY_ACCEPTANCE_MIN_WAIT_SEC", "5", "Machine")
Start-Service -Name "NetBird" > $null 2>&1

# Check if Netbird is installed
if (-not (Get-Command netbird -ErrorAction SilentlyContinue)) {
    Write-Host "Netbird is not installed, installing now..."
    
    # Call the installation function
    InstallNetbird
    sleep 10
    configure_start_script

} else {
    # Capture the output of the netbird status command
    $netbirdStatus = Invoke-Expression "netbird status -d"
    $netbirdVersionString = Invoke-Expression "netbird version"
    $netbirdVersion = [version]"$netbirdVersionString"

        # Check if the installed version is below the minimal version
    if ($netbirdVersion -lt $minimalVersion) {
        Write-Host "Netbird version is below the minimal version, stopping service and notifying user."
        # Send notification to all logged-in users
        msg * "Netbird version is too old. Forcing Upgrade of Netbird. Please wait."
        & 'C:\Program Files\Netbird\netbird.exe' down
        & 'C:\Program Files\Netbird\netbird.exe' service stop
        # Run the installation and configuration functions
        InstallNetbird
        Start-Sleep -Seconds 5
        Configure-StartScript
        & 'C:\Program Files\Netbird\netbird.exe' service restart
    }

    # Check if the output contains "Management: Disconnected" or "YOUR_MANAGEMENT_URL"
    if ($netbirdStatus -match "Management: Disconnected" -or $netbirdStatus -match "YOUR_MANAGEMENT_URL") {
        Write-Host "Netbird is installed but not connected, verifying version and connecting..."
        
        # Check if the output matches the required version
        if ($netbirdVersion -eq $requiredVersion) {
            Write-Host "Netbird version is $requiredVersion, Ignoring"
            configure_start_script
           & 'C:\Program Files\Netbird\netbird.exe' service restart 
        } else {
            Write-Host "Netbird Current Version is:" $netbirdVersion
            Write-Host "Netbird version is not $requiredVersion - Upgrading/Downgrading"
            # Call the installation function
            InstallNetbird
            sleep 5
            configure_start_script
            & 'C:\Program Files\Netbird\netbird.exe' service restart
        }
        
    } else {
        Write-Host "Netbird is connected at the moment, ignoring"
        configure_start_script

    }
}
