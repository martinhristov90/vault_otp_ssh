Vagrant.configure("2") do |config|

    config.vm.define "vault_server" do |vault_server|
      vault_server.vm.hostname = "vault-server"
      vault_server.vm.box = "martinhristov90/vault"
      vault_server.vm.provision "shell", path: "./configs/scripts/vaultSetupSSH.sh", privileged: false
      vault_server.vm.network "private_network", ip: "192.168.1.10"
    end
  
    config.vm.define "ubuntu_ssh" do |ubuntu_ssh|
      ubuntu_ssh.vm.hostname = "ubuntu-ssh-server"
      ubuntu_ssh.vm.box = "martinhristov90/ubuntu1604"
      ubuntu_ssh.vm.provision "shell", path: "./configs/scripts/ubuntuSSHsetup.sh", privileged: false
      ubuntu_ssh.vm.provision "shell", path: "./configs/scripts/install_vault_ssh_helper.sh", privileged: true
      ubuntu_ssh.vm.network "private_network", ip: "192.168.1.20"
    end
  end
    