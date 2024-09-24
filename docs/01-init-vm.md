# 2. Initialize Single Node Kubernetes Cluster

## 2.1 Initialize VM with Vagrant

```sh
### on host ###

# create ssh key for admin user and copy public key the to local folder
username='admin'
key_path="${HOME}/.ssh/kone.key"

ssh-keygen -t rsa -b 4096 -C "${username}" -f "${key_path}" -q -N "" <<<y >/dev/null 2>&1
mkdir -p ./ansible/ssh
cat "${key_path}.pub" > ./ansible/ssh/public.key

# clean previous guest key (optional)
mkdir -p "${HOME}/.ssh"
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "192.168.56.10"

# provision VM and apply initial_install playbook to create admin user
vagrant up --no-provision \
  && while ! nc -zw 1 kone 22; do echo 'Waiting for VM "kone" to accept ssh...'; sleep 5; done \
  && vagrant provision \
  && vagrant halt
```

## 2.2 Adjust the VM Options and Fix Networking

```sh
### on host ###
vbox_bin='VBoxManage.exe'

# set three networks: internal, host-only and NAT
# set the VM to run headless by default
# fix DNS after changing networking
$vbox_bin modifyvm "kone" \
  --macaddress1 auto --nic1 intnet \
  --macaddress2 auto --nic2 hostonly \
  --macaddress3 auto --nic3 nat \
  --defaultfrontend headless \
  --natdnshostresolver1 on \
  --natdnsproxy1 on

# start the VM, wait for it to become available and connect to it
$vbox_bin startvm "kone" \
  && while ! nc -zw 1 kone 22; do echo 'Waiting for VM "kone" to accept ssh...'; sleep 5; done; \
  echo 'VM "kone" is ready to accept ssh'
```

## 2.3 Apply Playbook to Install Kubernetes

```sh
### on host ###

# apply the already applied playbook to verify that playbooks can be run with the run-playbook script
bash ./scripts/run-playbook.sh -b ./ansible/initial_setup.yaml -i ./ansible/inventory.cfg -u "${username}" -k "${key_path}"

# apply network fix playbook
bash ./scripts/run-playbook.sh -b ./ansible/network-fix.yaml -i ./ansible/inventory.cfg -u "${username}" -k "${key_path}"

# apply install kubernetes playbook
ansible-galaxy install -r ./ansible/requirements.yml --roles-path ./ansible/roles
bash ./scripts/run-playbook.sh -b ./ansible/install-kube.yaml -i ./ansible/inventory.cfg -u "${username}" -k "${key_path}"
```
