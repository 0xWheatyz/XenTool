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
Single line usage
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/0xWheatyz/XenTool/refs/heads/main/linux.sh) users.txt
```
 

```
git clone https://github.com/0xWheatyz/XenTool.git
cd XenTool
chmod +x ubuntu.sh
./ubuntu.sh users.txt
```

#### Example users.txt file
```
root; sudo
0xWheatyz;
```
In this example root is the only account that is authorized to use sudo commands.


### Notes
---
Many functions do require sudo, it may be worth while to remove the sudo prefix in many commands and just run the whole script as sudo
