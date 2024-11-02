#!/bin/bash

declare -A USER_MAP  # Declare associative array to keep track of user IDs and usernames globally

# Function to display the menu
display_menu() {
    echo "1. Create Groups and Users"
    echo "2. Create Directories and Set Access Permissions"
    echo "3. Change Group IDs and Verify"
    echo "4. Display User Groups"
    echo "5. Change User Name"
    echo "6. Display Hashed Password File"
    echo "7. Switch to Another User"
    echo "8. Install and Configure Apache with Custom Pages"
    echo "9. Network Configuration"
    echo "10. Change Directory Group Ownership"
    echo "11. Delete Users and Groups"
    echo "12. Exit"
}

# Create groups and users
create_groups_and_users() {
    read -p "Enter name for the first group (default: frontend): " group1
    read -p "Enter name for the second group (default: backend): " group2
    group1=${group1:-frontend}
    group2=${group2:-backend}

    sudo groupadd $group1
    sudo groupadd $group2

    for i in $(seq 1 20); do
        user_id="user$i"
        user_name=$(printf "user%02d" $i)
        if [ $i -le 10 ]; then
            sudo useradd -N -m -G $group1 -p $(openssl passwd -1 SecurePass123) $user_name
        else
            sudo useradd -N -m -G $group2 -p $(openssl passwd -1 SecurePass123) $user_name
        fi
        echo "User $user_name created with ID $user_id"
        USER_MAP[$user_id]=$user_name
    done

    declare -p USER_MAP > user_map_file
    echo "Groups and users created successfully."
}

# Load the USER_MAP from a file
load_user_map() {
    if [ -f user_map_file ]; then
        source user_map_file
    fi
}

# Create directories and set permissions
create_directories_and_set_permissions() {
    sudo mkdir -p /var/www/$group1
    sudo mkdir -p /var/www/$group2

    sudo chown -R :$group1 /var/www/$group1
    sudo chown -R :$group2 /var/www/$group2

    sudo chmod 770 /var/www/$group1
    sudo chmod 770 /var/www/$group2

    echo "Directories created and permissions set successfully."
}


# Change group IDs and verify
change_group_ids_and_verify() {
    # Check and delete existing groups with GID 1002 or 1003 if necessary
    existing_group_1002=$(getent group 1002 | cut -d: -f1)
    existing_group_1003=$(getent group 1003 | cut -d: -f1)
    
    if [ -n "$existing_group_1002" ]; then
        sudo groupdel $existing_group_1002
        echo "Deleted existing group with GID 1002: $existing_group_1002"
    fi
    if [ -n "$existing_group_1003" ]; then
        sudo groupdel $existing_group_1003
        echo "Deleted existing group with GID 1003: $existing_group_1003"
    fi
    
    # Change the Group ID for $group1 to 1002
    sudo groupmod -g 1002 $group1
    echo "Group ID for '$group1' changed to 1002 successfully."

    # Change the Group ID for $group2 to 1003
    sudo groupmod -g 1003 $group2
    echo "Group ID for '$group2' changed to 1003 successfully."

    # Verify the changes
    group1_gid=$(getent group $group1 | cut -d: -f3)
    group2_gid=$(getent group $group2 | cut -d: -f3)

    echo "$group1 Group ID: $group1_gid"
    echo "$group2 Group ID: $group2_gid"

    if [ "$group1_gid" -eq 1002 ] && [ "$group2_gid" -eq 1003 ]; then
        echo "Verification successful: Group IDs are correctly set."
    else
        echo "Error: Group ID verification failed."
    fi
}

#display_user_groups():
display_user_groups() {
    read -p "Enter the username to display groups: " specific_user
    if id "$specific_user" &>/dev/null; then
        echo "Groups for $specific_user:"
        groups $specific_user
    else
        echo "Error: User $specific_user does not exist."
    fi
}

# Change user name
change_user_name() {
    read -p "Do you want to change the name of a user? (y/n): " change
    if [ "$change" == "y" ]; then
        read -p "Enter the current user ID: " user_id
        read -p "Enter the new user name (default: network_admin): " new_name
        new_name=${new_name:-network_admin}
        sudo usermod -l $new_name ${USER_MAP[$user_id]}
        sudo usermod -d /home/$new_name -m $new_name
        USER_MAP[$user_id]=$new_name  # Update the map with the new username
        echo "User name changed successfully."
    fi
}

#display_hashed_password_file:
display_hashed_password_file() {
    echo "Detailed user information:"
    echo "---------------------------------------------------------------------------------------------------------"
    printf "%-10s %-20s %-50s %-20s %-20s\n" "UserID" "Username" "Hashed Password" "Groups" "Access Level"
    echo "---------------------------------------------------------------------------------------------------------"
    
    for user_id in "${!USER_MAP[@]}"; do
        current_username=${USER_MAP[$user_id]}
        hashed_password=$(sudo grep $current_username /etc/shadow | cut -d: -f2)
        user_groups=$(groups $current_username | cut -d: -f2)
        home_directory=$(eval echo ~$current_username)
        access_level=$(stat -c %A $home_directory)
        
        printf "%-10s %-20s %-50s %-20s %-20s\n" "$user_id" "$current_username" "$hashed_password" "$user_groups" "$access_level"
    done
    
    echo "---------------------------------------------------------------------------------------------------------:)"
}
#switch_to_another_user:
switch_to_another_user() {
    read -p "Enter the user ID to switch to: " user_id
    user_name=${USER_MAP[$user_id]}

    if [ -n "$user_name" ]; then
        echo "Switching to $user_name..."
        sudo -u $user_name bash -c 'echo "WELCOME to the group body"; whoami'
        echo "Returned to the original user."
    else
        echo "Error: User ID $user_id does not exist in the map."
    fi
}


# Install and configure Apache with custom pages
install_and_configure_apache() {
    if ! apache2 -v &> /dev/null; then
        sudo apt update
        sudo apt install apache2 -y
    fi

    # Set appropriate permissions
    sudo chown -R $USER:$USER /var/www/$group1
    sudo chown -R $USER:$USER /var/www/$group2

    # Create custom index.html files without printing the contents in the terminal
    group1_users=$(getent group $group1 | cut -d: -f4)
    group2_users=$(getent group $group2 | cut -d: -f4)

    echo "Welcome to $group1 site. Apache configured by script for the $group1 group. Users in $group1 group: $group1_users" | sudo tee /var/www/$group1/index.html > /dev/null
    echo "Welcome to $group2 site. Apache configured by script for the $group2 group. Users in $group2 group: $group2_users" | sudo tee /var/www/$group2/index.html > /dev/null

    # Configure Apache virtual hosts
    sudo bash -c "cat > /etc/apache2/sites-available/${group1}.local.conf <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName ${group1}.local
    DocumentRoot /var/www/$group1
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF"

    sudo bash -c "cat > /etc/apache2/sites-available/${group2}.local.conf <<EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    ServerName ${group2}.local
    DocumentRoot /var/www/$group2
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF"

    sudo a2ensite ${group1}.local.conf
    sudo a2ensite ${group2}.local.conf
    sudo systemctl restart apache2

    echo "Apache installed and configured successfully."
}

# Network configuration
network_configuration() {
    read -p "Do you want to assign a static IP address? (y/n): " assign_ip
    if [ "$assign_ip" == "y" ]; then
        local ip_address="192.168.1.100"
        local dns_server="8.8.8.8"
        sudo bash -c "cat > /etc/netplan/01-netcfg.yaml <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    ens160:
      dhcp4: no
      addresses: [$ip_address/24]
      gateway4: 192.168.1.1
      nameservers:
        addresses: [$dns_server]
EOF"
        # Set the correct permissions for the netplan file
        sudo chmod 600 /etc/netplan/01-netcfg.yaml
        sudo netplan apply

        # Check the applied settings
        echo "Checking IP and DNS settings..."
        ip addr show ens160 | grep 'inet ' | awk '{print $2}'
        cat /etc/resolv.conf | grep nameserver

        echo "Static IP address and DNS settings assigned successfully."
    fi
}

#change_directory_group_ownership:
change_directory_group_ownership() {
    sudo chown -R :$group1 /var/www/$group1
    sudo chown -R :$group2 /var/www/$group2
    echo "Directory group ownership changed successfully."
}

delete_users_and_groups() {
    echo "Please choose an option for deleting:"
    echo "1. Delete a single user"
    echo "2. Delete a single group"
    echo "3. Delete all users"
    echo "4. Delete all groups"
    echo "5. Delete both all users and all groups"
    echo "6. Cancel"
    read -p "Choose an option (1-6): " delete_choice

    case $delete_choice in
        1)
            read -p "Enter the username to delete: " username
            sudo userdel -r $username
            echo "User $username deleted successfully."
            ;;
        2)
            read -p "Enter the group name to delete: " group_name
            sudo groupdel $group_name
            echo "Group $group_name deleted successfully."
            ;;
        3)
            for user_id in $(seq 1 20); do
                user_name=$(printf "user%02d" $user_id)
                sudo userdel -r $user_name
                echo "User $user_name deleted successfully."
            done
            ;;
        4)
            sudo groupdel $group1
            sudo groupdel $group2
            echo "Groups $group1 and $group2 deleted successfully."
            ;;
        5)
            for user_id in $(seq 1 20); do
                user_name=$(printf "user%02d" $user_id)
                sudo userdel -r $user_name
                echo "User $user_name deleted successfully."
            done
            sudo groupdel $group1
            sudo groupdel $group2
            echo "Users and groups deleted successfully."
            ;;
        6)
            echo "Canceling deletion."
            ;;
        *)
            echo "Invalid option. Returning to main menu."
            ;;
    esac
}
exit_script() {
    echo "Exiting script."
    exit 0
}
# Main script logic
load_user_map  # Load the USER_MAP from the file

while true; do
    display_menu
    read -p "Please choose an option: " option
    case $option in
        1) create_groups_and_users ;;
        2) create_directories_and_set_permissions ;;
        3) change_group_ids_and_verify ;;
        4) display_user_groups ;;
        5) change_user_name ;;
        6) display_hashed_password_file ;;
        7) switch_to_another_user ;;
        8) install_and_configure_apache ;;
        9) network_configuration ;;
        10) change_directory_group_ownership ;;
        11) delete_users_and_groups ;;
        12) exit_script ;;
        *) echo "Invalid option. Please try again (be careful this time)" ;;
    esac
done





