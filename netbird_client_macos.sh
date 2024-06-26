#!/bin/bash
install=
minimalVersion="0.28.0"
requiredVersion="0.28.3"
netbird_domain="Your Netbird Domain"
netbird_device_port="33073"
netbird_web_port="443"
random_port=$((20000 + RANDOM % 10001))
sudo networksetup -setv6off Ethernet
sudo networksetup -setv6off Wi-Fi

# Define a function to update config.json and create a cloudfront script
update_config () { 
  # Update config.json with the new domain and port values
  sed -i '' "s|api.netbird.io:443|$netbird_domain:$netbird_device_port|g" /etc/netbird/config.json
  sed -i '' "s|app.netbird.io:443|$netbird_domain:$netbird_web_port|g" /etc/netbird/config.json
  sed -i '' "s|\"WgPort\".*,|\"WgPort\": $random_port,|g" /etc/netbird/config.json
}

if [[ ! -z $(/usr/local/bin/netbird) ]]
then
    installedVersion=$(/usr/local/bin/netbird version)
    if [[ "$(printf '%s\n' "$minimalVersion" "$installedVersion" | sort -V | head -n1)" == "$minimalVersion" && "$installedVersion" != "$minimalVersion" ]]; then
        echo "The installed version ($installedVersion) is at least $minimalVersion."
        if [[ $(/usr/local/bin/netbird status | grep Management | grep -c Connected) -ge 1 ]]
        then 
            echo "Netbird connected at the moment - Aborting"
            update_config # execute function
            sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
        else
            if [[ "$(/usr/local/bin/netbird version)" == "$requiredVersion" ]]
            then 
                echo "Netbird is already at $requiredVersion - ignoring"
                update_config # execute function
                /usr/local/bin/netbird service restart
                exit 0
            else
                echo "Current version is: $(/usr/local/bin/netbird version)"
                echo "Netbird is not at version $requiredVersion - Will Upgrade/Downgrade"
                killall -9 netbird-ui   > /dev/null 2>&1
                /usr/local/bin/netbird down   > /dev/null 2>&1
                /usr/local/bin/netbird service stop   > /dev/null 2>&1
                install=install
            fi
        fi
    else
        echo "The installed version ($installedVersion) is less than $minimalVersion."
        echo "Forcing Netbird Upgrade"
        /usr/local/bin/netbird down   > /dev/null 2>&1
        /usr/local/bin/netbird service stop   > /dev/null 2>&1
        install=install
    fi
else
    install=install
fi

if [[ "$install" == "install" ]]
then
    cd /tmp
    rm -rf /tmp/netbird*   > /dev/null 2>&1
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
    killall -9 netbird-ui  > /dev/null 2>&1
    installer -pkg "/tmp/netbird.pkg" -target /
    echo  Get the currently logged-in user #
    logged_in_user=$(stat -f "%Su" /dev/console)
    echo Run a command as the logged-in user: $logged_in_user
    /usr/local/bin/netbird service stop   > /dev/null 2>&1
    sleep 3
    /usr/local/bin/netbird service start   > /dev/null 2>&1
    sudo -u "$logged_in_user" open -g "/Applications/NetBird.app"
    sleep 3
    echo updating config file and restarting
    /usr/local/bin/netbird service stop  > /dev/null 2>&1
    killall -9 netbird-ui  > /dev/null 2>&1
    killall -9 netbird  > /dev/null 2>&1
    sleep 5
    update_config # execute function
    /usr/local/bin/netbird service start
    sleep 5
    sudo -u "$logged_in_user" open -g "/Applications/NetBird.app"
    sleep 15
    sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
fi

