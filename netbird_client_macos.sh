#!/bin/bash
install=
requiredVersion="0.27.6"
netbird_domain="your.netbird.domain"
netbird_device_port="33073"
netbird_web_port="443"

if [[ ! -z $(/usr/local/bin/netbird) ]]
then 
    if [[ $(/usr/local/bin/netbird status | grep Management | grep -c Connected) -ge 1 ]]
    then 
        echo "Netbird connected at the moment - Aborting"
    else
        if [[ "$(/usr/local/bin/netbird version)" == "$requiredVersion" ]]
        then 
            echo "Netbird is already at $requiredVersion - ignoring"
            exit 0
        else
            echo "Netbird is not at version $requiredVersion - Will Upgrade"
            echo "Current version is: $(/usr/local/bin/netbird version)"
            install=1
        fi
    fi
else
    install=1
fi

if [[ $install -eq 1 ]]
then
    echo "Nerbird is not installed or Wrong Version"
    echo "Removing Netbird if exist"
    killall -9 netbird-ui
    /usr/local/bin/netbird down
    /usr/local/bin/netbird service stop
    /usr/local/bin/netbird service uninstall
    if [[ -d /Applications/NetBird.app ]]; then rm -rf /Applications/NetBird.app;fi
    if [[ -d "/Applications/Netbird UI.app" ]]; then rm -rf "/Applications/Netbird UI.app";fi
    rm -rf /Library/LaunchDaemons/netbird.plist
    rm -rf /etc/netbird /usr/local/bin/netbird

    cd /tmp
    rm -rf /tmp/netbird*
    echo getting netbird Application from S3 bucket
    curl --silent -o /tmp/netbird.zip https://storage.googleapis.com/qwilt-installs/netbird_app.zip
    cd /tmp
    unzip -o netbird.zip -d /

    # Check CPU type
    cpu_type=$(uname -m)
    echo "CPU Type: $cpu_type"

    if [[ "$cpu_type" == "x86_64" ]]; then
        echo "CPU type is Intel"
        pkg_url=$(curl -sIL -o /dev/null -w '%{url_effective}' https://github.com/netbirdio/netbird/releases/download/v$requiredVersion/netbird_${requiredVersion}_darwin_amd64.pkg)
        curl --silent -o /tmp/netbird.pkg "$pkg_url"

        # Add your x86_64 specific commands here
    elif [[ "$cpu_type" == "arm64" ]]; then
        echo "CPU type is M1/M2/M3"
        # Add your arm64 specific commands here
        pkg_url=$(curl -sIL -o /dev/null -w '%{url_effective}' https://github.com/netbirdio/netbird/releases/download/v$requiredVersion/netbird_${requiredVersion}_darwin_arm64.pkg)
        curl --silent -o /tmp/netbird.pkg "$pkg_url"
    else
        echo "Unsupported CPU type: $cpu_type"
        exit 1
    fi
    echo installing pkg
    installer -pkg "/tmp/netbird.pkg" -target /
    echo  Get the currently logged-in user #
    logged_in_user=$(stat -f "%Su" /dev/console)
    echo Run a command as the logged-in user: $logged_in_user
    /usr/local/bin/netbird service stop
    sleep 3
    /usr/local/bin/netbird service start
    sudo -u "$logged_in_user" open -g "/Applications/NetBird.app"
    sleep 3
    echo updating config file and restarting
    /usr/local/bin/netbird service stop
    killall -9 netbird-ui
    killall -9 netbird
    sleep 5
    /usr/bin/sed -i '' "s|api.netbird.io:443|$netbird_domain:$netbird_device_port|g" /etc/netbird/config.json
    /usr/bin/sed -i '' "s|api.wiretrustee.com:443|$netbird_domain:$netbird_device_port|g" /etc/netbird/config.json
    /usr/bin/sed -i '' "s|app.netbird.io:443|$netbird_domain:$netbird_web_port|g" /etc/netbird/config.json
    /usr/local/bin/netbird service start
    sleep 5
    sudo -u "$logged_in_user" open -g "/Applications/NetBird.app"
    sleep 5
    /bin/cat /etc/netbird/config.json
fi 
dscacheutil -flushcache; sudo killall -HUP mDNSResponder
