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
