# 1. Initialize host

## 1.1 Prerequisites

Hardware required for VM:

- 8-16 GB RAM
- 4+ CPU (cores)

All host OS required to have installed:

- Ansible
- Vagrant (with vagrant-vbguest plugin)
- Virtualbox

Windows only:

- WSL
- Windows Terminal (optional)

## 1.2 Set environment

```sh
# append hosts
cat <<EOF | sudo tee -a /etc/hosts
192.168.56.10 kone kone.local kubernetes-dashboard.kone.local
192.168.56.10 prometheus.kone.local
EOF

# append to ~/.ssh/config
cat <<EOF | tee -a ~/.ssh/config
Host kone kone.local
    User admin
    Port 22
    Hostname 192.168.56.10
    StrictHostKeychecking no
    IdentityFile ~/.ssh/kone.key
EOF

# WSL: set env values for vagrant and virtualbox
export VAGRANT_WSL_ENABLE_WINDOWS_ACCESS="1"
export PATH="$PATH:/mnt/c/Program\ files/VirtualBox"
```

## 1.3 Check

To check that every prerequisite is installed run the commands below.

```sh
ansible --version | awk 'NR==1'
# expected result (version could be higher)
# ansible 2.9.6

vagrant version | awk 'NR==1'
# expected result (version could be higher)
# Installed Version: 2.4.1

vagrant plugin list
# expected result (version could be higher)
# vagrant-vbguest (0.32.0, global)

VBoxManage.exe -v
# expected result (version could be higher)
# 7.0.12r159484

cat /etc/hosts | grep 192.168.56.10
# expected result: see the list of hosts in the section 1.2 "append hosts"

grep -A3 -B3 192.168.56.10 ~/.ssh/config
# expected result: see the configuration in the section 1.2 "append to ~/.ssh/config"
```
