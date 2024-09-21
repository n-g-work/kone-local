# -*- mode: ruby -*-
# vi: set ft=ruby :

$out_file = File.new('vagrant.log', 'w')
def $stdout.write string
    log_datas=string
    if log_datas.gsub(/\r?\n/, "") != ''
        log_datas=::Time.now.strftime("[%Y-%m-%d %T %z]")+" "+log_datas.gsub(/\r\n/, "\n")
    end
    super log_datas
    $out_file.write log_datas
    $out_file.flush
end
def $stderr.write string
    log_datas=string
    if log_datas.gsub(/\r?\n/, "") != ''
        log_datas=::Time.now.strftime("[%Y-%m-%d %T %z]")+" "+log_datas.gsub(/\r\n/, "\n")
    end
    super log_datas
    $out_file.write log_datas
    $out_file.flush
end

# debian "box" => "debian/bullseye64" or "debian/buster64"
# ubuntu cloud image box: "box" => "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64-vagrant.box"
boxes = [
    {
        "name" => "kone",
        "box" => "https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64-vagrant.box",
        "memory" => 16384,
        "cpus" => 8,
        "ip" => "192.168.56.10"
    }
]

Vagrant.configure("2") do |config|
    boxes.each do |box|
        config.ssh.insert_key = false
        config.vbguest.auto_update = false

        config.vm.define box['name'] do |curr|
            curr.vm.box = box['box']

            curr.vm.network "private_network", ip: box['ip']
            curr.vm.synced_folder ".", "/vagrant", disabled: true

            curr.vm.provider "virtualbox" do |vb|
                vb.name = box['name']
                # Display the VirtualBox GUI when booting the machine
                vb.gui = false
                # Customize the amount of memory on the VM:
                vb.memory = box['memory']
                vb.cpus = box['cpus']
                # make it usable from WSL:
                vb.customize [ "modifyvm", :id, "--uartmode1", "disconnected" ]
            end

            curr.vm.provision "ansible" do |ansible|
                ansible.playbook = File.join(File.dirname(__FILE__),"./ansible/initial_setup.yaml")
                ansible.inventory_path = File.join(File.dirname(__FILE__),"./ansible/inventory.cfg")
                #ansible.verbose = "vvvv"
            end
        end
    end
end
