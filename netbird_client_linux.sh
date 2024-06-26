#!/bin/bash
install=
requiredVersion="0.28.3"
minimalVersion="0.28.0"
netbird_domain="your domain"
netbird_device_port="33073"
netbird_web_port="443"
random_port=$((20000 + RANDOM % 10001))

# Define a function to update config.json and create a cloudfront script
update_config () { 
  # Update config.json with the new domain and port values
  sed -i "s|api.netbird.io:443|$netbird_domain:$netbird_device_port|g" /etc/netbird/config.json
  sed -i "s|app.netbird.io:443|$netbird_domain:$netbird_web_port|g" /etc/netbird/config.json
  sed -i "s|\"WgPort\".*,|\"WgPort\": $random_port,|g" /etc/netbird/config.json
}

if [[ "$(which /usr/bin/netbird 2>/dev/null | grep -c netbird)" -eq 0 ]]
then 
    echo "Netbird is missing, installing it now"
    install=1
else
    installedVersion=$(/usr/bin/netbird version)
    if [[ "$(printf '%s\n' "$minimalVersion" "$installedVersion" | sort -V | head -n1)" == "$minimalVersion" && "$installedVersion" != "$minimalVersion" ]]; then
        echo "The installed version ($installedVersion) is at least $minimalVersion."
        service netbird start
        if  [[ "$(/usr/bin/netbird status 2>/dev/null | grep Management | grep -oc Disconnected )" -ge 1 ]] || [[ "$( /usr/bin/netbird status 2>/dev/null | grep -c YOUR_MANAGEMENT_URL)" -ge 1 ]]
        then
            echo "Netbird is disconnected or not installed, checking if $requiredVersion is installed"
            if [[ "$(netbird version)" == "$requiredVersion" ]]
            then 
                echo "Netbird is already at $requiredVersion - ignoring"
                update_config
                /usr/bin/netbird service restart
            else
                echo "Current version is: $(/usr/bin/netbird version)"
                echo "Netbird version is not $requiredVersion - Upgrading/Downgrading"
                /usr/bin/netbird service stop  > /dev/null 2>&1
                killall -9 netbird-ui  > /dev/null 2>&1
                install=1
            fi #end of netbird version test
        else
            echo "Netbird client is connected at the moment, Ignoring"
            install=0
        fi # end of connection test
    else
        echo "The installed version ($installedVersion) is less than $minimalVersion."
        echo "Forcing Netbird Upgrade"
             netbird down
            install=1
    fi

fi # end of install and version test

if [[ "$install" -eq 1 ]]
then
    echo "runnning install"
    if [[ "$(cat /etc/os-release | grep -ociE 'Fedora|centos|rocky' | sort --uniq)" -ge 1 ]]
    then
        echo downloading the client
        pkg_url=$(curl -sIL -o /dev/null -w '%{url_effective}' https://github.com/netbirdio/netbird/releases/download/v$requiredVersion/netbird_${requiredVersion}_linux_amd64.rpm)
        curl --silent -o /tmp/netbird.rpm "$pkg_url"
        rpm -Uvh  /tmp/netbird.rpm

        echo downloading the netbird-ui
        pkg_url=$(curl -sIL -o /dev/null -w '%{url_effective}' https://github.com/netbirdio/netbird/releases/download/v$requiredVersion/netbird-ui_${requiredVersion}_linux_amd64.rpm)
        curl --silent -o /tmp/netbird-ui.rpm "$pkg_url"
        rpm -Uvh  /tmp/netbird-ui.rpm
    else
        pkg_url=$(curl -sIL -o /dev/null -w '%{url_effective}' https://github.com/netbirdio/netbird/releases/download/v$requiredVersion/netbird_${requiredVersion}_linux_amd64.deb)
        # Download the package file
        curl --silent -o /tmp/netbird.deb "$pkg_url"
        pkg_url=$(curl -sIL -o /dev/null -w '%{url_effective}' https://github.com/netbirdio/netbird/releases/download/v$requiredVersion/netbird-ui_${requiredVersion}_linux_amd64.deb)
        # Download the package file
        curl --silent -o /tmp/netbird-ui.deb "$pkg_url"
        dpkg -i /tmp/netbird.deb
        dpkg -i /tmp/netbird-ui.deb
        sudo apt-get install libnotify-bin -y

    fi # end of netbird client based on OS version

/usr/bin/netbird service stop  > /dev/null 2>&1
killall -9 netbird-ui  > /dev/null 2>&1
update_config # calling function
/usr/bin/netbird service install  > /dev/null 2>&1
/usr/bin/netbird service start   > /dev/null 2>&1
logged_in_user=$(w | grep tty| awk '{print $1}' | sort --uniq)
display=$(w | grep tty| awk '{print $3}' | sort --uniq)
sudo -u $logged_in_user DISPLAY=$display netbird-ui &
fi # finished installing and configuring the client




