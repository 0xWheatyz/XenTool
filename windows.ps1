function Check-And-Manage-Users {
    param (
        [string]$FilePath
    )

    # Check if file exists
    if (-not (Test-Path -Path $FilePath)) {
        Write-Error "File not found: $FilePath"
        return
    }

    # Import the user list
    $userList = Import-Csv -Path $FilePath

    foreach ($user in $userList) {
        $username = $user.username
        $isAdminExpected = $user.isAdmin -eq "true"

        # Check if the user exists
        $localUser = Get-LocalUser -Name $username -ErrorAction SilentlyContinue
        if (-not $localUser) {
            Write-Output "User '$username' does not exist on this system. Skipping..."
            continue
        }

        # Check if the user is an administrator
        $isAdmin = (Get-LocalGroupMember -Group "Administrators" -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $username }) -ne $null

        if ($isAdmin -ne $isAdminExpected) {
            if ($isAdmin -and -not $isAdminExpected) {
                # Remove user from Administrators group
                Write-Output "Removing '$username' from Administrators group..."
                Remove-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction SilentlyContinue
            } elseif (-not $isAdmin -and $isAdminExpected) {
                # Add user to Administrators group
                Write-Output "Adding '$username' to Administrators group..."
                Add-LocalGroupMember -Group "Administrators" -Member $username -ErrorAction SilentlyContinue
            }
        } else {
            Write-Output "User '$username' is correctly set as Admin=$isAdminExpected."
        }

        # Remove the user if not needed
        if (-not $isAdminExpected -and $localUser) {
            Write-Output "Deleting user '$username' from the system..."
            Remove-LocalUser -Name $username -ErrorAction SilentlyContinue
        }
    }
}


Check-And-Manage-Users -FilePath "users.txt"
