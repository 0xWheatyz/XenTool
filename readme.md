# XenTool
A system hardening toolkit

## Features
---
* Check system users against list from file
* Disable often risky services
* Remove commonly malicious programs
* List open ports


## Usage
---
Super duper simple
```
git clone https://github.com/0xWheatyz/XenTool.git
cd XenTool
chmod +x ubuntu.sh
./ubuntu.sh users.txt
```
or all as one,
`git clone https://github.com/0xWheatyz/XenTool.git && cd XenTool &&chmod +x ubuntu.sh && ./ubuntu.sh users.txt`
`users.txt` is a text file containing authorized user and their superuser status.

#### Example users.txt file
```
root; sudo
0xWheatyz;
```
In this example root is the only account that is authorized to use sudo commands.


### Notes
---
Many functions do require sudo, it may be worth while to remove the sudo prefix in many commands and just run the whole script as sudo
