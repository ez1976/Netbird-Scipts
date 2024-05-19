
# Define the required version
$requiredVersion = "0.27.7"
$netbird_domain = "your.netbird.domain"
$netbird_device_port = "33073"
$netbird_web_port = "443"

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
}

function configure_start_script {   
    #create the custom script to run
    @'
@echo off
setx NB_ICE_RELAY_ACCEPTANCE_MIN_WAIT_SEC "15" /m
netbird status > "%temp%\netbird_status.txt" 2>&1

REM Check if the word "error" appears in the output file
findstr /C:"error" "%temp%\netbird_status.txt" > NUL
if "%ERRORLEVEL%"=="0" (
    REM If error is found, restart NetBird service
    tskill netbird-ui > $null 2>&1
    netbird service start  > NUL 2>&1
    netbird service restart  > NUL 2>&1
)
timeout /t 2 > NUL

REM Define the path to the Netbird executable
set "programPath=C:\Program Files\Netbird\netbird-ui.exe"
    REM If the program is not running, start it
    start "" "%programPath%"
    :startNetbird
    tskill netbird-ui
    start netbird-ui
    netbird up
'@ | Set-Content -Path "C:\ProgramData\Netbird\netbird-ui-qwilt.bat" -Encoding UTF8

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


    # Copy the shortcut to the Startup folder on each remote computer
    Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\NetBird.lnk" -Destination "C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\StartUp" -Force
    Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\NetBird.lnk" -Destination "C:\ProgramData\Microsoft\Windows\Start Menu\Programs" -Force
    Copy-Item -Path "C:\ProgramData\Microsoft\Windows\Start Menu\NetBird.lnk" -Destination "C:\Users\Public\Desktop" -Force

    #showing all icons in the traybar
    Set-ItemProperty HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer EnableAutoTray 0
    # Get the currently logged-in user session
    $currentUserSession = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    # set to run after computer resumes from sleep
    # Define variables
    
    # Set to run after computer resumes from sleep
    # Define variables
    $taskName = "Run netbird on Resume"
    $programPath = "C:\ProgramData\Netbird\netbird-ui-qwilt.bat"

    # Create trigger for system resume event using event subscription
    $triggerXml = @"
    <QueryList>
      <Query Id='0' Path='System'>
        <Select Path='System'>*[System[Provider[@Name='Microsoft-Windows-Power-Troubleshooter'] and (EventID=1)]]</Select>
      </Query>
    </QueryList>
"@

    # Create the action to start the program
    $action = New-ScheduledTaskAction -Execute $programPath

    # Register the scheduled task
    Register-ScheduledTask -TaskName $taskName -Trigger (New-ScheduledTaskTrigger -AtStartup -RandomDelay (New-TimeSpan -Seconds 30)) -Action $action -Description "Runs $programPath on system resume" -User "SYSTEM" -RunLevel Highest -Force

}

[Environment]::SetEnvironmentVariable("NB_ICE_RELAY_ACCEPTANCE_MIN_WAIT_SEC", "15", "Machine")
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
            configure_start_script
        } else {
            Write-Host "Netbird Current Version is:" $netbirdVersion
            Write-Host "Netbird version is not $requiredVersion - Upgrading/Downgrading"
            # Call the installation function
            InstallNetbird
            configure_start_script
        }
        
        # Add connection logic here
        
    } else {
        Write-Host "Netbird is connected at the moment, ignoring"
        configure_start_script

    }
}
