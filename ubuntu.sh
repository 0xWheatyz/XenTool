#!/bin/bash
set +e

## Helper function to check that string is in array
# Usage: _contains_element "string" "${array[@]}"
# Returns: 0 if exists, 1 if not found
_contains_element () {
  local e match="$1"
  shift
  for e; do [[ "$e" == "$match" ]] && return 0; done
  return 1
}

## Helper function for the fancy print colors
_print () {
  local color="$1"
  local text="$2"
  case "$color" in 
    r)
      echo -e "[\e[31m-\e[0m] $text"
      ;;
    y)
      echo -e "[\e[33m!\e[0m] $text"
      ;;
    g) 
      echo -e "[\e[32m+\e[0m] $text"
      ;;
    *)
      echo "invaild color"
      ;;
    esac
}

# Get all users with a login shell
delete_extra_users () {
  ### GET SYSTEM USERS ###
  # Get users from /etc/passwd with login shells begining with /bin/
  users=$( awk -F: '($7 ~ /\/(bash|zsh|sh|dash|ksh)$/) {print $1}' /etc/passwd )
  clean_system_username_list=()
  # Loop through users
  for user in $users
  do
    clean_system_username_list+=($user)
  done
  
  ### GET USERS FROM FILE ###
  # Read file into string
  users=$( cat $1 )
  # Initalize a list
  clean_file_username_list=()
  # Loop through users and assign to list
  for user in $users 
  do 
    clean_file_username_list+=($user)
  done

  ### COMPARE LISTS LOOKING FOR UNAUTHORIZED USERS ###
  for system_user in ${clean_system_username_list[@]}
  do
    if _contains_element "$system_user" "${clean_file_username_list[@]}"; then true  
    else 
      _print "r" "UNAUTHORIZED > $system_user"
      read -p "Remove user? (Y/n) " -n 1 ans
      echo
      if [[ $ans == n ]]; then true
      else
        sudo -S userdel $system_user
      fi
    fi
  done
  _print "g" "Completed user checks"
}

# Delete bad tools defined in nono_app_list
# Finished BUT UNTESTED
delete_bad_tools () {
  # List of installed apps
  installed_app_list=$( dpkg --get-selections | grep -v deinstall | cut -f1 )
  # List of bad apps
  nono_app_list=("nmap" "wireshark" "thunderbird")
  for app in ${installed_app_list[@]}
  do
    if _contains_element "$app" "${nono_app_list}"
    then
      _print "r" "$app"
      read -p "Remove app? (Y/n) " -n 1 ans
      echo ""
      if [[ $ans == n ]]; then true
      else
        sudo -S apt remove "$app*"
      fi 
    fi 
  done
  _print "g" "Finished deleting malicious tools"
}

disable_services () {
  # List of bad services
  bad_services=("nginx" "apache" "apache2" "sshd")
  
  for service in ${bad_services[@]}
  do
    # Check if service is running
    service_status=$( systemctl is-active $service )
    if [ $service_status == "inactive" ]; then true
    else
      # If service is running, warn user
      _print "y" "$service"
      # prompt user to disable and stop service
      read -p "Disable service? (Y/n) " -n 1 ans
      echo ""
      if [[ $ans == n ]]; then true
      else
        sudo -S systemctl stop $service
        sudo -S systemctl disable $service
      fi
    fi
  done
  _print "g" "Finished disabling services"
}


# Check open ports
port_viewer () {
  bad_ports=(22 23 25 53 80 443 3306 5432 6379 5900 8080 2049 135 445 3389)

  for port in "${bad_ports[@]}"
  do 
    if ss -tuln | grep -q ":$port "
    then
      _print "y" "Open port > $port"
    fi 
  done
}


# Update password complexity
set_password_complexity () {
  # Copy password file from somewhere...
  # /etc/login.defs
  password_enforcement_raw_contents="# /etc/login.defs - configuration for login and user account management\n# PASS_MAX_DAYS: maximum number of days a password is valid\nPASS_MAX_DAYS   90\n# PASS_MIN_DAYS: minimum number of days between password changes\nPASS_MIN_DAYS   7\n# PASS_MIN_LEN: minimum acceptable password length\nPASS_MIN_LEN    12\n# PASS_WARN_AGE: number of days before password expires that the user is warned\nPASS_WARN_AGE   14\n# ENCRYPT_METHOD: encryption method to use for password hashing\nENCRYPT_METHOD  SHA512\n# Default umask for users\nUMASK           077\n# Allow users to use shadow passwords\nSHA_CRYPT       yes"
  echo "$password_enforcement_raw_contents" | tee login.defs &> /dev/null

}

# Main function
delete_extra_users $1
delete_bad_tools
disable_services
set_password_complexity
