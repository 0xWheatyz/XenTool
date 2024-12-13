### Windows System Hardening Script ###

# Helper function for logging
$log = @()
function Write-Log {
    param (
        [string]$Message,
        [string]$Type = "INFO"  # INFO, WARN, ERROR
    )
    $log += "[$Type] $Message"
    Write-Host "[$Type] $Message"
}

# Function to write logs to a file
function Write-LogFile {
    $log | Out-File -FilePath "C:\HardeningScript.log" -Encoding UTF8
}

# Function to check for unauthorized users
function Remove-ExtraUsers {
    param (
        [string]$AuthorizedUsersFile
    )
    Write-Log "Checking for unauthorized users..."

    # Get list of local users
    $localUsers = Get-LocalUser | Where-Object { $_.Enabled -eq $true } | Select-Object -ExpandProperty Name

    # Get authorized users from file
    $authorizedUsers = Get-Content -Path $AuthorizedUsersFile

    # Compare and remove unauthorized users
    foreach ($user in $localUsers) {
        if ($authorizedUsers -notcontains $user) {
            Write-Log "Unauthorized user found: $user" "WARN"
            $response = Read-Host "Remove user $user? (Y/n)"
            if ($response -ne "n") {
                try {
                    Remove-LocalUser -Name $user
                    Write-Log "Removed user: $user" "INFO"
                } catch {
                    Write-Log "Failed to remove user: $user. $_" "ERROR"
                }
            }
        }
    }
    Write-Log "Completed user checks."
}

# Function to remove unauthorized admin users
function Remove-UnauthorizedAdmins {
    param (
        [string]$AuthorizedAdminsFile
    )
    Write-Log "Checking for unauthorized admin users..."

    # Get list of administrators
    $adminGroup = Get-LocalGroupMember -Group "Administrators" | Select-Object -ExpandProperty Name

    # Get authorized admins from file
    $authorizedAdmins = Get-Content -Path $AuthorizedAdminsFile

    # Compare and remove unauthorized admins
    foreach ($admin in $adminGroup) {
        if ($authorizedAdmins -notcontains $admin) {
            Write-Log "Unauthorized admin found: $admin" "WARN"
            $response = Read-Host "Remove admin $admin? (Y/n)"
            if ($response -ne "n") {
                try {
                    Remove-LocalGroupMember -Group "Administrators" -Member $admin
                    Write-Log "Removed admin: $admin" "INFO"
                } catch {
                    Write-Log "Failed to remove admin: $admin. $_" "ERROR"
                }
            }
        }
    }
    Write-Log "Completed admin checks."
}

# Function to uninstall unwanted applications
function Remove-BadTools {
    $badTools = @("nmap", "wireshark", "telnet", "ftp", "curl", "wget", "php", "python", "ruby", "perl")
    Write-Log "Checking for and removing unwanted applications..."

    foreach ($tool in $badTools) {
        $installedApp = Get-AppxPackage | Where-Object { $_.Name -match $tool }
        if ($installedApp) {
            Write-Log "Found unwanted application: $tool" "WARN"
            $response = Read-Host "Remove application $tool? (Y/n)"
            if ($response -ne "n") {
                try {
                    Get-AppxPackage $tool | Remove-AppxPackage
                    Write-Log "Removed application: $tool" "INFO"
                } catch {
                    Write-Log "Failed to remove application: $tool. $_" "ERROR"
                }
            }
        }
    }
    Write-Log "Completed application removal."
}

# Function to disable unwanted services
function Disable-Services {
    $badServices = @("Telnet", "FTP", "RemoteRegistry", "SMB", "SNMP", "SSDP", "Bluetooth")
    Write-Log "Disabling unwanted services..."

    foreach ($service in $badServices) {
        try {
            $serviceStatus = Get-Service -Name $service -ErrorAction SilentlyContinue
            if ($serviceStatus -and $serviceStatus.Status -ne "Stopped") {
                Write-Log "Disabling service: $service" "WARN"
                Stop-Service -Name $service -Force
                Set-Service -Name $service -StartupType Disabled
                Write-Log "Disabled service: $service" "INFO"
            }
        } catch {
            Write-Log "Failed to disable service: $service. $_" "ERROR"
        }
    }
    Write-Log "Completed disabling services."
}

# Function to check open ports
function Check-OpenPorts {
    $badPorts = @(22, 23, 25, 80, 443, 3306, 3389)
    Write-Log "Checking for open ports..."

    foreach ($port in $badPorts) {
        $portCheck = Test-NetConnection -Port $port -InformationLevel Quiet
        if ($portCheck) {
            Write-Log "Open port detected: $port" "WARN"
        }
    }
    Write-Log "Completed port checks."
}

# Function to enforce password complexity
function Set-PasswordComplexity {
    Write-Log "Enforcing password complexity policies..."

    try {
        secedit /export /cfg C:\secpol.cfg
        (Get-Content C:\secpol.cfg).replace("PasswordComplexity = 0", "PasswordComplexity = 1") |
            Set-Content C:\secpol.cfg
        secedit /configure /db secedit.sdb /cfg C:\secpol.cfg /areas SECURITYPOLICY
        Remove-Item C:\secpol.cfg
        Write-Log "Password complexity enforced." "INFO"
    } catch {
        Write-Log "Failed to enforce password complexity. $_" "ERROR"
    }
}

function Remove-MediaFilesFromHomeDirs {
    # Define a list of media file extensions to remove
    $mediaExtensions = @('.mp3', '.mp4', '.avi', '.mkv', '.mov', '.flv', '.wmv', '.wav', '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp')

    # Get all user home directories (assuming they are under C:\Users\ or can be customized)
    $homeDirectories = Get-ChildItem -Path "C:\Users" -Directory

    foreach ($homeDir in $homeDirectories) {
        # Get all files in the home directory and its subdirectories
        $files = Get-ChildItem -Path $homeDir.FullName -Recurse -File

        foreach ($file in $files) {
            # Check if the file has a media extension
            if ($mediaExtensions -contains $file.Extension.ToLower()) {
                Write-Host "Removing file: $($file.FullName)"

                # Remove the media file
                try {
                    Remove-Item -Path $file.FullName -Force -ErrorAction Stop
                } catch {
                    Write-Warning "Failed to remove $($file.FullName): $_"
                }
            }
        }
    }
}

function Update-AllApps {
    # Try using winget first
    try {
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            Write-Host "Updating all applications using winget..."
            $apps = winget list
            $apps | ForEach-Object {
                $appName = $_.Name
                Write-Host "Updating $appName..."
                winget upgrade --id $appName --silent --accept-package-agreements --accept-source-agreements
            }
            Write-Host "All applications updated successfully via winget."
        } else {
            Write-Host "winget not found. Moving on to Chocolatey..."
        }
    } catch {
        Write-Warning "An error occurred while updating applications using winget: $_"
    }

    # Now, try using Chocolatey if winget fails or is unavailable
    try {
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Host "Updating all applications using Chocolatey..."
            choco upgrade all -y
            Write-Host "All applications updated successfully via Chocolatey."
        } else {
            Write-Host "Chocolatey not found. Unable to update applications."
        }
    } catch {
        Write-Warning "An error occurred while updating applications using Chocolatey: $_"
    }
}

# Main Script Execution
$authorizedUsersFile = "C:\AuthorizedUsers.txt"
$authorizedAdminsFile = "C:\AuthorizedAdmins.txt"

Remove-ExtraUsers -AuthorizedUsersFile $authorizedUsersFile
Remove-UnauthorizedAdmins -AuthorizedAdminsFile $authorizedAdminsFile
Remove-BadTools
Disable-Services
Check-OpenPorts
Set-PasswordComplexity
Write-LogFile
Remove-MediaFilesFromHomeDirs
Update-AllApps

# Windows Security Hardening Script
# This script implements multiple security best practices for Windows systems.
# Run with administrative privileges.

# Log File Initialization
$LogFile = "C:\security_hardening.log"
Start-Transcript -Path $LogFile -Append

Write-Output "Starting Windows Security Hardening Script..."

# Function to log actions
Function Log-Action {
    param ([string]$Message)
    Write-Output $Message | Out-File -FilePath $LogFile -Append
}

# 1. Enable Windows Firewall and Configure Rules
Log-Action "Enabling Windows Firewall..."
Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
Log-Action "Windows Firewall enabled."

# Example Rule: Allow RDP from a specific IP
$AllowedIP = "192.168.1.100"
New-NetFirewallRule -DisplayName "Allow RDP" -Direction Inbound -Protocol TCP -LocalPort 3389 -Action Allow -RemoteAddress $AllowedIP
Log-Action "Configured RDP rule for IP $AllowedIP."

# 2. Enable BitLocker for Disk Encryption
Log-Action "Enabling BitLocker on C:\ drive..."
Enable-BitLocker -MountPoint "C:" -EncryptionMethod XtsAes256 -UsedSpaceOnlyEncryption -TpmProtector
Log-Action "BitLocker enabled."

# 3. Regularly Apply Windows Updates
Log-Action "Installing Windows Updates..."
Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
Import-Module PSWindowsUpdate
Install-WindowsUpdate -AcceptAll -AutoReboot
Log-Action "Windows Updates installed."

# 4. Restrict Remote Desktop Protocol (RDP) Access
Log-Action "Disabling RDP..."
Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\Terminal Server" -Name "fDenyTSConnections" -Value 1
Log-Action "RDP disabled."

# 5. Audit and Monitor Event Logs
Log-Action "Enabling audit policies..."
AuditPol.exe /set /category:* /success:enable /failure:enable
Log-Action "Audit policies enabled."

# 6. Disable Unused Network Protocols
Log-Action "Disabling SMBv1..."
Set-SmbServerConfiguration -EnableSMB1Protocol $false
Log-Action "SMBv1 disabled."

# 7. Implement Local Security Policies
Log-Action "Configuring local security policies..."
secedit /configure /cfg "C:\Windows\Security\Templates\SecTemplate.inf" /db SecDB.sdb
Log-Action "Local security policies configured."

# 8. Remove Legacy Applications and Features
Log-Action "Removing Internet Explorer..."
Disable-WindowsOptionalFeature -FeatureName Internet-Explorer-Optional-amd64 -Online
Log-Action "Internet Explorer removed."

# 9. Enable Controlled Folder Access
Log-Action "Enabling Controlled Folder Access..."
Set-MpPreference -EnableControlledFolderAccess Enabled
Log-Action "Controlled Folder Access enabled."

# 10. Harden PowerShell
Log-Action "Configuring PowerShell execution policies..."
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
Set-ItemProperty -Path "HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name "EnableScriptBlockLogging" -Value 1
Log-Action "PowerShell hardened."

# 11. Use AppLocker or Windows Defender Application Control (WDAC)
Log-Action "Configuring AppLocker policies..."
Set-AppLockerPolicy -PolicyType Enforced -XMLPolicy "C:\Path\To\AppLockerPolicy.xml"
Log-Action "AppLocker policies configured."

# 12. Secure Administrator Accounts
Log-Action "Renaming default Administrator account..."
Rename-LocalUser -Name "Administrator" -NewName "SecureAdmin"
Log-Action "Administrator account renamed."

# 13. Enable Enhanced Security in Windows Defender
Log-Action "Enabling enhanced security features in Windows Defender..."
Set-MpPreference -EnableNetworkProtection Enabled
Log-Action "Windows Defender enhanced security features enabled."

# 14. Disable USB Ports (if not required)
Log-Action "Disabling USB ports..."
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" -Name "Start" -Value 4
Log-Action "USB ports disabled."

# 15. Backup Critical Data
Log-Action "Creating a backup..."
wbadmin start backup -backupTarget:D: -include:C: -allCritical -quiet
Log-Action "Backup created."

Write-Output "Security Hardening Script Completed."
Stop-Transcript

