#!/bin/bash
install=
requiredVersion="0.27.4"
netbird_domain="your.netbird.domain"
netbird_device_port="33073"
netbird_web_port="443"

if [[ "$(which /usr/bin/netbird 2>/dev/null | grep -c netbird)" -eq 0 ]]
then 
    echo "Netbird is missing, installing it now"
    install=1
else
    if  [[ "$(/usr/bin/netbird status 2>/dev/null | grep Management | grep -oc Disconnected )" -ge 1 ]]
    then
        echo "Netbird is disconnected or not installed, checking if $requiredVersion is installed"
        if [[ "$(netbird version)" == "$requiredVersion" ]]
        then 
            echo "Netbird is already at $requiredVersion - ignoring"
        else
            echo "Netbird version is not $requiredVersion, reinstalling"
            echo "Current version is: $(/usr/bin/netbird version)"
            /usr/bin/netbird service down  > /dev/null 2>&1
            /usr/bin/netbird service stop  > /dev/null 2>&1
            /usr/bin/netbird service uninstall  > /dev/null 2>&1
            dnf remove netbird netbird-ui -y > /dev/null 2>&1
            apt remove netbird netbird-ui -y > /dev/null 2>&1
            rm -rf /etc/netbird /usr/local/bin/netbird /usr/bin/netbird > /dev/null 2>&1
            install=1
        fi #end of netbird version test
    else
        echo "Netbird client is connected at the moment, Ignoring"
        install=0
    fi # end of connection test
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
    fi # end of netbird client based on OS version

/usr/bin/netbird service stop  > /dev/null 2>&1
/usr/bin/netbird service uninstall  > /dev/null 2>&1
killall -9 netbird-ui  > /dev/null 2>&1
sed -i "s|api.wiretrustee.com:443|$netbird_domain:$netbird_device_port|g" /etc/netbird/config.json
sed -i "s|api.netbird.io:443|$netbird_domain:$netbird_device_port|g" /etc/netbird/config.json
sed -i "s|app.netbird.io:443|$netbird_domain:$netbird_web_port|g" /etc/netbird/config.json
/usr/bin/netbird service install  > /dev/null 2>&1
/usr/bin/netbird service start   > /dev/null 2>&1

fi # finished installing and configuring the client
