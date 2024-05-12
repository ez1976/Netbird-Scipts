#!/bin/bash
install=
requiredVersion="0.27.4"
netbird_domain="your.netbird.domain"
netbird_device_port="33073"
netbird_web_port="443"


# Define the installation function
function InstallNetbird {
    # Add installation logic here
    echo uninstalling netbird
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

        echo Updating config file
        # Define the new values
        $newManagementURL = "${netbird_domain}:${netbird_device_port}"
        $newWebURL = "${netbird_domain}:${netbird_web_port}"


        # Path to the config.json file
        $configFilePath = "C:\ProgramData\Netbird\config.json"

        # Read the contents of the file
        $configContent = Get-Content -Path $configFilePath -Raw
        # Replace the strings in the configuration file
        $newConfigContent = $configContent -replace 'app.netbird.io:443', $newWebURL -replace 'api.netbird.io:443', $newManagementURL -replace 'api.wiretrustee.com:443', $newManagementURL

        $newConfigContent | Set-Content -Path $configFilePath
        Start-Service -Name "NetBird" > $null 2>&1

        # Write the updated content back to the file
        $newConfigContent | Set-Content -Path $configFilePath


        # Path to the config.json file
        $configFilePath = "C:\ProgramData\Netbird\config.json"

        # Read the contents of the file
        $configContent = Get-Content -Path $configFilePath -Raw

        # Replace the strings
        # Replace the strings in the configuration file
        $newConfigContent = $configContent -replace 'api.wiretrustee.com:443', "${netbird_domain}:${netbird_device_port}" -replace 'app.netbird.io:443', "${netbird_domain}:443" -replace 'api.netbird.io:443', "${netbird_domain}:${netbird_web_port}"

        #create the custom script to run
        @'
@echo off
REM Define the path to the Netbird executable
set "programPath=C:\Program Files\Netbird\netbird-ui.exe"

REM Check if the program is already running
tasklist /FI "IMAGENAME eq netbird-ui.exe" 2>NUL | find /I /N "netbird-ui.exe">NUL
if "%ERRORLEVEL%"=="0" (
    REM If the program is already running, display a message
    echo Netbird is already running
    goto :startNetbird
) else (
    REM If the program is not running, start it
    start "" "%programPath%"
    :startNetbird
    netbird up
)
'@ | Set-Content -Path "C:\ProgramData\Netbird\netbird-ui-qwilt.bat" -Encoding UTF8
Remove-Item -Path "C:\ProgramData\Netbird\*.ps1" -Force -ErrorAction SilentlyContinue

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

        # Copy the shortcut to the Startup folder on each remote computer
        Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\NetBird.lnk" -Destination "C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\StartUp" -Force
        Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\NetBird.lnk" -Destination "C:\ProgramData\Microsoft\Windows\Start Menu\Programs" -Force
        Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\NetBird.lnk" -Destination "C:\Users\Public\Desktop" -Force

        #showing all icons in the traybar
        Set-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer EnableAutoTray 0
        # Get the currently logged-in user session
        $currentUserSession = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

        # Extract the username from the session information
        $username = $currentUserSession -replace ".*\\"

        # Check if the user is currently logged in
        if ($username) {
            Write-Host "User $username is currently logged in."

            # Start the software as the logged-in user
            $softwarePath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\NetBird.lnk"  # Replace with the actual path to netbird-ui.exe
            Start-Process -FilePath $softwarePath -Verb RunAs $username > $null 2>&1
            Write-Host "Software started for user $username on their desktop."
        } else {
            Write-Host "No user is currently logged in."
        }

}

Start-Service -Name "NetBird" > $null 2>&1

# Check if Netbird is installed
if (-not (Get-Command netbird -ErrorAction SilentlyContinue)) {
    Write-Host "Netbird is not installed, installing now..."
    
    # Call the installation function
    InstallNetbird
    
} else {
    # Capture the output of the netbird status command
    $netbirdStatus = Invoke-Expression "netbird status -d"

    # Check if the output contains "Management: Disconnected" or "YOUR_MANAGEMENT_URL"
    if ($netbirdStatus -match "Management: Disconnected" -or $netbirdStatus -match "YOUR_MANAGEMENT_URL") {
        Write-Host "Netbird is installed but not connected, verifying version and connecting..."
        $netbirdVersion = Invoke-Expression "netbird version"
        
        # Check if the output matches the required version
        if ($netbirdVersion -eq $requiredVersion) {
            Write-Host "Netbird version is $requiredVersion, Ignoring"
        } else {
            Write-Host "Netbird version is not $requiredVersion, reinstalling"
            Write-Host "Netbird Current Version is:" $netbirdVersion
            # Call the installation function
            InstallNetbird
        }
        
        # Add connection logic here
        
    } else {
        Write-Host "Netbird is connected at the moment, ignoring"
    }
}
