#!/bin/bash

# Function to perform the installation (Step 3)
installation_function() {
    echo "Starting the installation..."
    
    # Asking for user input
    read -p "Please enter your input: " user_input
    echo "You entered: $user_input"
    
    # Add your installation commands here
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
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        if [ "$NAME" == "Ubuntu" ] && [ $(echo "$VERSION_ID >= 16.04" | bc) -eq 1 ]; then
            echo "Ubuntu version is supported."
        elif [ "$NAME" == "Debian GNU/Linux" ] && [ $(echo "$VERSION_ID >= 10" | bc) -eq 1 ]; then
            echo "Debian version is supported."
        else
            echo "Unsupported OS version."
            exit 1
        fi
    else
        echo "Cannot determine OS version."
        exit 1
    fi
}

# Function to detect the virtualization environment (Step 2)
detect_virtualization() {
    VIRT_ENV=$(systemd-detect-virt)
    if [ "$VIRT_ENV" == "openvz" ] || [ "$VIRT_ENV" == "lxc" ]; then
        echo "Unsupported virtualization environment ($VIRT_ENV)."
        exit 1
    else
        echo "Virtualization environment ($VIRT_ENV) is supported."
    fi
}

# Main script execution
check_root_user
detect_os_version
detect_virtualization
installation_function
