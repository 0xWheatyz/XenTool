# CyberCamp 2025 Notes
According to AFA *check these against script*
- [X] Password Policies
  * Min length is 10
  * Min remeber passwords is 5
- [X] Use preconfigured pam configs in `/usr/share/pam-configs`
- [x] Enable ufw
- [ ] Remove programs
  * ophcrack

- [ ] killed python backdoor
  * Currently searches for any cronjobs containing a list of keywords
- [X] minlen = 10 in pam.d/common-password
- [x] Run updates


## Results from first round

### Notes
* Password complexity function did not work
* Update passwords did not work
* Root modifcations
  * Disable root login
  * Exclude root users.txt
* `chage` to change password policies
* Missed apps
  * Transmission
  * Hexchat
  * Thunderbird
  * AisleRiot

### All items
* Removed unauthorized users
  * ttanner
  * cdennis
* kbennett is not an admin
* Created user account mross
* User mross must change password at next login (Should for every user after changing password)
* A default minimum password age is set
* UFW enabled
* Apache2 service has been disabled
* The system refreshes list of updates automatically (Should be scripted)
* Install updates from important security updates
* Chromimum updated
* OpenSSH has been updated
* Prohibited MP3 files are removed
* Prohibited software:
  * aisleriot
  * ophcrack
* SSH root login has been disabled


## Improvements checklist
- [X] Get safe SSHD configs from github
- [ ] Add ophcrack to malicous software list
- [ ] Get list of users from readme automatically
- [ ] Enable auto updates
- [X] Instead of pre-configured configs, install hardened ones from github
- [X] Install `/etc/security/pw-quality`
- [ ] Search for media files
- [X] Force all users to change passwords on next login after updating their password
