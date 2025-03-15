# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|

  config.vm.box = "ubuntu/focal64"

  config.vm.network :forwarded_port, guest: 3003, host: 3003
  config.vm.network :forwarded_port, guest: 5433, host: 5433

  config.vm.network :private_network, ip: "192.168.56.9"

  config.vm.synced_folder ".", "/ziher"

  config.vm.provider :virtualbox do |vb|
    #vb.gui = true

    vb.customize ["modifyvm", :id, "--memory", "8192"]
    vb.customize ["modifyvm", :id, "--cpus", "4"]
    vb.customize ["modifyvm", :id, "--ioapic", "on"]
  end

  config.vm.provision :shell, :path => "vagrant-provision.sh"
end
