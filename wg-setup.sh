#!/bin/bash

# Function to display the management menu
management_menu() {
    echo "Management Menu"
    echo "1. Placeholder Option 1"
    echo "2. Placeholder Option 2"
    echo "3. Placeholder Option 3"
    echo "4. Placeholder Option 4"
    while true; do
        read -p "Please choose an option (1-4): " menu_option
        case $menu_option in
            1) echo "Option 1 selected";;
            2) echo "Option 2 selected";;
            3) echo "Option 3 selected";;
            4) echo "Option 4 selected";;
            *) echo "Invalid option. Please try again.";;
        esac
    done
}

# Function to perform the installation (Step 3)
installation_function() {
    if wg &> /dev/null; then
        echo "WireGuard is already installed."
        management_menu
    fi
    while true; do
        read -p "Do you want to install WireGuard? (yes/no): " user_input
        case $user_input in
            [Yy]* ) 
                install_wireguard
                break;;
            [Nn]* ) 
                echo "Installation aborted."
                exit 0;;
            * ) 
                echo "Please answer yes or no.";;
        esac
    done
}

# Function to install WireGuard
install_wireguard() {
    echo "Starting the installation of WireGuard..."
    
    if [[ ${OS} == "debian" ]]; then
        if [[ ${VERSION_ID} -ge 10 ]]; then
            apt-get update
            apt-get install -y wireguard iptables resolvconf qrencode
        else
            echo "deb http://deb.debian.org/debian buster-backports main" >/etc/apt/sources.list.d/backports.list
            apt-get update
            apt-get install -y iptables resolvconf qrencode
            apt-get install -y -t buster-backports wireguard
        fi
    elif [[ ${OS} == "ubuntu" ]]; then
        apt-get update
        apt-get install -y wireguard iptables resolvconf qrencode
    else
        echo "Unsupported OS."
        exit 1
    fi

    echo "WireGuard installation completed."
}

# Function to check if the user is root
check_root_user() {
    if [ "$EUID" -ne 0 ]; then
        echo "Please run as root."
        exit 1
    else
        echo "Running as root."
    fi
}

# Function to detect the OS version (Step 1)
detect_os_version() {
    source /etc/os-release
    OS="${ID}"
    if [[ ${OS} == "debian" || ${OS} == "raspbian" ]]; then
        if [[ ${VERSION_ID} -lt 10 ]]; then
            echo "Your version of Debian (${VERSION_ID}) is not supported. Please use Debian 10 Buster or later"
            exit 1
        fi
        OS=debian # overwrite if raspbian
    elif [[ ${OS} == "ubuntu" ]]; then
        RELEASE_YEAR=$(echo "${VERSION_ID}" | cut -d'.' -f1)
        if [[ ${RELEASE_YEAR} -lt 18 ]]; then
            echo "Your version of Ubuntu (${VERSION_ID}) is not supported. Please use Ubuntu 18.04 or later"
            exit 1
        fi
    else
        echo "Looks like you aren't running this installer on a Debian/Raspbian or Ubuntu system"
        exit 1
    fi
}

# Function to detect the virtualization environment (Step 2)
detect_virtualization() {
    VIRT_ENV=$(systemd-detect-virt)
    if [ "$VIRT_ENV" == "openvz" ] || [ "$VIRT_ENV" == "lxc" ]; then
        echo "Unsupported virtualization environment ($VIRT_ENV)."
        exit 1
    fi
}

# Main script execution
check_root_user
detect_os_version
detect_virtualization
installation_function
