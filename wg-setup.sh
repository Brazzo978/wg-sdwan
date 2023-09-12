#!/bin/bash

# Function to add a new WireGuard client
add_wireguard_client() {
    echo "Add WireGuard Client"
    while true; do
        read -p "Do you want to add a new WireGuard tunnel? (yes/no): " user_input
        case $user_input in
            [Yy]* )
                read -p "Please paste the WireGuard configuration here and press Enter: " wg_config
                # Find the next available configuration file number
                for i in {01..99}
                do
                    if [ ! -f /etc/wireguard/wg${i}.conf ]; then
                        echo "$wg_config" > /etc/wireguard/wg${i}.conf
                        # Try to bring up the WireGuard interface
                        if wg-quick up wg${i}; then
                            echo "WireGuard tunnel wg${i} added successfully."
                        else
                            echo "Failed to add WireGuard tunnel wg${i}."
                            rm /etc/wireguard/wg${i}.conf  # Remove the configuration file if the command fails
                        fi
                        break
                    fi
                done
                break;;
            [Nn]* ) 
                echo "Operation aborted."
                break;;
            * ) 
                echo "Please answer yes or no.";;
        esac
    done
}

# Function to list all WireGuard configurations
list_wireguard_configs() {
    echo "List of WireGuard Configurations:"
    if [ -d /etc/wireguard ]; then
        ls /etc/wireguard/*.conf
    else
        echo "No configurations found."
    fi
}

# Function to remove a WireGuard client
remove_wireguard_client() {
    echo "Remove WireGuard Client"
    echo "List of WireGuard Configurations:"
    
    if [ -d /etc/wireguard ]; then
        ls /etc/wireguard/*.conf
        while true; do
            read -p "Please enter the number of the configuration to remove (e.g., 01 for wg01.conf): " config_number
            if [[ -f /etc/wireguard/wg${config_number}.conf ]]; then
                read -p "Are you sure you want to remove wg${config_number}.conf? (yes/no): " confirmation
                case $confirmation in
                    [Yy]* )
                        # Bring down the tunnel before removing the configuration file
                        if wg-quick down wg${config_number} &> /dev/null; then
                            echo "WireGuard tunnel wg${config_number} brought down successfully."
                            if rm /etc/wireguard/wg${config_number}.conf; then
                                echo "Configuration wg${config_number}.conf removed successfully."
                            else
                                echo "Failed to remove configuration wg${config_number}.conf."
                            fi
                        else
                            echo "Failed to bring down the WireGuard tunnel wg${config_number} or it was not active. Removing the configuration file anyway."
                            if rm /etc/wireguard/wg${config_number}.conf; then
                                echo "Configuration wg${config_number}.conf removed successfully."
                            else
                                echo "Failed to remove configuration wg${config_number}.conf."
                            fi
                        fi
                        break;;
                    [Nn]* )
                        echo "Operation aborted."
                        break;;
                    * )
                        echo "Please answer yes or no.";;
                esac
            else
                echo "Invalid number. Please try again."
            fi
        done
    else
        echo "No configurations found."
    fi
}

find_best_route() {
    echo "Find the Best Route"
    while true; do
        read -p "Do you want to prefer the lowest ping or the path with less hop count to the host? (ping/tracert): " user_choice
        case $user_choice in
            [Pp]* ) 
                find_lowest_ping
                break;;
            [Tt]* ) 
                find_hop_tracert
                break;;
            * ) 
                echo "Please answer with ping or tracert.";;
        esac
    done
}


find_lowest_ping() {
    echo "Finding the lowest ping..."
    
    # Check if the hostv4.txt file exists
    if [ ! -f /etc/wireguard/hostv4.txt ]; then
        echo "File /etc/wireguard/hostv4.txt not found!"
        return
    fi
    
    # Get the list of WireGuard configurations
    configs=(/etc/wireguard/wg*.conf)
    
    # Get the list of IP addresses
    mapfile -t ips < /etc/wireguard/hostv4.txt
    
    # Initialize an associative array to store the lowest ping time for each IP
    declare -A lowest_ping
    
    # Initialize an associative array to store the configuration name for the lowest ping time for each IP
    declare -A best_config
    
    # Loop through each IP address
    for ip in "${ips[@]}"; do
        # Loop through each configuration
        for config in "${configs[@]}"; do
            # Extract the configuration name (without the path and extension)
            config_name=$(basename "$config" .conf)
            
            # Ping the IP address through the tunnel and get the average ping time
            # We are using the 'fping' utility here as it allows specifying the interface and gives the average ping time directly
            # Install it with 'apt install fping' if not installed
            {
                avg_ping=$(fping -c 100 -I "$config_name" "$ip" 2>&1 | grep 'avg round trip time' | awk -F= '{print $2}' | awk '{print $1}')
                
                # Check if the ping was successful
                if [ -n "$avg_ping" ]; then
                    # Check if this is the lowest ping time for this IP so far
                    if [ -z "${lowest_ping[$ip]}" ] || bc <<< "$avg_ping < ${lowest_ping[$ip]}" ; then
                        # Update the lowest ping time and the best configuration for this IP
                        lowest_ping["$ip"]=$avg_ping"
                        best_config["$ip"]=$config_name"
                    fi
                fi
            } &
        done
        
        # Wait for all background processes to finish before moving to the next IP
        wait
    done
    
    # Write the results to the preferred.txt file
    : > /etc/wireguard/preferred.txt  # Clear the file
    for ip in "${ips[@]}"; do
        echo "$ip ${best_config[$ip]} ${lowest_ping[$ip]}" >> /etc/wireguard/preferred.txt
    done

    echo "Completed. The results have been saved to /etc/wireguard/preferred.txt."
}




# Function to display the management menu
management_menu() {
    echo "Management Menu"
    echo "1. Add WireGuard Client"
    echo "2. List WireGuard Configs"
    echo "3. Remove WireGuard Client"
    echo "4. Find the Best Route"
    while true; do
        read -p "Please choose an option (1-4): " menu_option
        case $menu_option in
            1) add_wireguard_client;;
            2) list_wireguard_configs;;
            3) remove_wireguard_client;;
            4) find_best_route;;
            *) echo "Invalid option. Please try again.";;
        esac
    done
}

# Function to perform the installation
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
