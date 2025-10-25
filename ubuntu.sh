#!/bin/bash
set +e

## Global log variable
# Every destructive function appends to this list upon completing one action
log=()

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

## Write log to text file
_write_log () {
  echo $log | tee script.log
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
    username=$( echo $user | cut -d";" -f1 )
    clean_file_username_list+=($username)
  done

  ### COMPARE LISTS LOOKING FOR UNAUTHORIZED USERS ###
  for system_user in ${clean_system_username_list[@]}
  do
    if _contains_element "$system_user" "${clean_file_username_list[@]}"; then true  
    else 
      _print "r" "UNAUTHORIZED USER > $system_user"
      read -p "Remove user? (Y/n) " -n 1 ans
      echo
      if [[ $ans == n ]]; then true
      else
        log+=("Removed user => $user")
        sudo -S userdel $system_user
      fi
    fi
  done
  _print "g" "Completed user checks"
}

# Remove sudo permission from users who are not authorized
remove_unauthorized_admin () {
  ### GET CLEAN LIST OF USERS FROM TXT FILE ###
  proper_users_raw=$( cat $1 | grep "sudo" | cut -d";" -f1 )
  proper_users=()
  for user in ${proper_users_raw}
  do
    proper_users+=($user)
  done

  ### REMOVE UNAUTHORIZED SUPERUSERS FROM WHEEL ###
  # Returns a list of users in the wheel group
  wheel_group_users_raw=$( getent group wheel | cut -d":" -f4 | tr "," "\n" )
  wheel_group_users=()
  for user in ${wheel_group_users_raw}
  do 
    wheel_group_users+=($user)
  done

  for user in ${wheel_group_users[@]}
  do
    if _contains_element "$user" "${proper_users[@]}"; then true
    else
      _print "r" "UNAUTHORIZED SUPERUSER > $user (reason: user in wheel group)"
      read -p "Remove user? (Y/n) " -n 1 ans
      echo ""
      if [[ $ans == n ]]; then true
      else
        log+=("Removed user => $user (wheel group)")
        sudo -S userdel $user
      fi
    fi
  done

  ### REMOVE UNAUTHORIZED SUPERUSERS FROM /etc/sudoers ###
  # Check /etc/sudoers for users between lines
  sudoers_users_raw=$( sed -n '/## User privilege specification/{:a; n; /## Uncomment to allow members of group wheel to execute any command/!{p; ba}}' /etc/sudoers | grep -v "##" | cut -d" " -f1 | grep -v "#")
  sudoers_users=()
  for user in ${sudoers_users_raw}
  do
    sudoers_users+=($user)
  done 
  
  for user in ${sudoers_users_raw}
  do 
    if _contains_element "$user" "${proper_users[@]}"; then true
    else
      _print "r" "UNAUTHORIZED SUPERUSER > $user (reason: user in /etc/sudoers)"
      read -p "Remove user? (Y/n) " -n 1 ans
      echo ""
      if [[ $ans == n ]]; then true
      else
        log+=("Removed user => $user (sudoers file)")
        #Use SED to match lines starting with $user, them comment out those lines
        sudo sed -i -e "/$user/s/^/#/" /etc/sudoers
      fi
    fi
  done
}

# Delete bad tools defined in nono_app_list
# Finished BUT UNTESTED
delete_bad_tools () {
  # List of installed apps
  installed_app_list=$( dpkg --get-selections | grep -v deinstall | cut -f1 )
  # List of bad apps
  nono_app_list=("nmap" "tcpdump" "wireshark" "hping3" "netcat" "nc" "telnet" "socat" "nikto" "whois" "rsh-client" "rlogin" "rexec" "xinetd" "vnc" "rdesktop" "ftp" "vsftpd" "tftp" "rdesktop" "tightvncserver" "perl" "ruby" "python" "php" "wget" "curl" "lynx" "elinks" "sshpass" "john" "hydra" "sqlmap" "squid" "xprobe" "Doona" "nginx" "openvpn")

  for app in ${installed_app_list[@]}
  do
    if _contains_element "$app" "${nono_app_list}"
    then
      _print "r" "MALICIOUS APP > $app"
      read -p "Remove app? (Y/n) " -n 1 ans
      echo ""
      if [[ $ans == n ]]; then true
      else
        log+=("Removed app => $app")
        sudo -S apt remove "$app*" -y &> /dev/null
      fi 
    fi 
  done
  _print "g" "Finished deleting malicious tools"
}

disable_services () {
  # List of bad services
  bad_services=("telnet" "ftp" "tftp" "vsftpd" "rexec" "rlogin" "rsh" "xinetd" "apache2" "httpd" "nginx" "mysql" "mariadb" "postgresql" "postfix" "sendmail" "exim4" "dovecot" "courier" "pop3" "imap" "samba" "nfs-kernel-server" "rsync" "cifs" "rpcbind" "avahi-daemon" "cups" "bluetooth" "ssdp" "snmp" "dhcp" "telnetd" "squid")
  
  for service in ${bad_services[@]}
  do
    # Check if service is running
    service_status=$( systemctl is-active $service )
    if [ $service_status == "inactive" ]; then true
    else
      # If service is running, warn user
      _print "y" "DANGEROUS SERVICE > $service"
      # prompt user to disable and stop service
      read -p "Disable service? (Y/n) " -n 1 ans
      echo ""
      if [[ $ans == n ]]; then true
      else
        log+=("Disabled service => $service")
        sudo -S systemctl -q stop $service
        sudo -S systemctl -q disable $service
      fi
    fi
  done
  _print "g" "Finished disabling services"
}

# Check open ports
port_viewer () {
  bad_ports=(21 22 23 25 53 80 443 3306 5432 6379 5900 8080 2049 135 445 3389)

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
  cp /etc/login.defs login.defs.bak
  echo "$password_enforcement_raw_contents" | tee login.defs &> /dev/null
}

# Updates all users passwords to meet complexity requirements
update_all_user_passwords () {
	# Hash = Cyb3rP@tri0t18
	hash='$6$.z7SjTXCuV.jcxp/$J80m2lGxxn6h6gKwE8aroWG10q4xPtmg7LGH2RORrlctT8s8Ma4jiwfSUi.Ox22YAKCAC7ii8tWkaDgzKXBQm/'
	users=$( cat $1 | cut -d";" -f1 )
	for user in "${users[@]}"
	do
		sudo usermod -p "$hash" "$user"
	done
}

# Enable UFW and review open ports (install if not)
enable_firewall () {
  # Install UFW if missing
  if ! command -v ufw &>/dev/null; then
    _print y "UFW is not installed."
    read -rp "Do you want to install UFW now? [Y/n]: " ans
    if [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]; then
      sudo apt update && sudo apt install -y ufw
      _print g "UFW installed successfully."
    else
      _print y "Cannot manage firewall without UFW. Exiting."
      return 1
    fi
  fi

  # Check status
  ufw_status=$(sudo ufw status | head -n1 | awk '{print $2}')
  if [[ "$ufw_status" == "inactive" ]]; then
    _print y "UFW is currently inactive."
    read -rp "Do you want to enable UFW now? [Y/n]: " ans
    if [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]; then
        sudo ufw enable
        _print g "UFW is now active."
    else
        _print y "Warning: UFW remains inactive. Managing ports is less secure."
    fi
  elif [[ "$ufw_status" == "active" ]]; then
    _print g "UFW is active."
  else
    _print y "Could not determine UFW status."
    return 1
  fi


  # Get all allowed ports (IPv4 only) and remove duplicates
  mapfile -t open_ports < <(
    sudo ufw status verbose 2>/dev/null |
    grep -E 'ALLOW' |
    grep -vE 'To|--|Status:' |
    awk '{print $1}' | sort -u
  )

  if (( ${#open_ports[@]} == 0 )); then
    _print g "No open ports detected in UFW rules."
    return 0
  fi

  # Show open ports
  _print r "The following ports are currently open:"
  for port in "${open_ports[@]}"; do
    _print y "$port"
  done

  # Delete each port (ask user, default YES)
  for port in "${open_ports[@]}"; do
    read -rp "Do you want to delete the rule for $port? [Y/n]: " ans
    if [[ -z "$ans" || "$ans" =~ ^[Yy]$ ]]; then
      # Delete both IPv4 and IPv6 rules automatically
      sudo ufw --force delete allow "$port"
      _print g "Deleted $port from UFW rules."
    else
      _print y "Kept $port in UFW rules."
    fi
  done
  _print g "UFW port management complete."
}

# PAM file overwrite
pam_management () {
  # Ensure libpam-runtime and pam-auth-update exist
  if ! command -v pam-auth-update &>/dev/null; then
    sudo apt-get update -y && sudo apt-get install -y libpam-runtime
  fi

  # Backup current PAM config (just in case)
  backup_dir="$PWD/pam-backups-$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$backup_dir"
  sudo cp /etc/pam.d/common-* "$backup_dir"/ || true

  # Run pam-auth-update non-interactively
  sudo pam-auth-update --force --package

  # Verify output files exist and are readable
  for f in /etc/pam.d/common-*; do
    if ! sudo grep -q "pam_unix.so" "$f"; then
      _print "y" "Warning: $f may be invalid — no pam_unix.so line found!"
    fi
  done
  _print "g" "PAM configuration successfully regenerated!"
}

# Finds the correct package manager and run updates
run_updates () {
  if command -v apt-get &> /dev/null; then
    sudo apt update && sudo apt upgrade &> /dev/null &
  elif command -v dnf &> /dev/null; then
    sudo dnf check-update && sudo dnf upgrade
  elif command -v yum &> /dev/null; then
    sudo yum upgrade
  else
    _print "r" "Failed to find a package manager and run updates" 
  fi
}

# Main function
delete_extra_users $1
delete_bad_tools
disable_services
enable_firewall
pam_management
set_password_complexity
update_all_user_passwords $1
remove_unauthorized_admin $1
_write_log
port_viewer
run_updates
