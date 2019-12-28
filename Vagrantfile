require_relative 'lib/vars'
require_relative 'lib/init_script'
require_relative 'lib/ha_script'
require_relative 'lib/master_script'
require_relative 'lib/node_script'

Vagrant.configure("2") do |config|
  config.vm.box_check_update = false

  config.vm.box = "rsteinbacher/ubuntu-server"
  config.vm.box_version = "0.1.0-alpha.2"
  config.vm.box_url = "https://nexus3-test.es.gk-software.com/nexus/repository/vagrant/boxes/custom/rsteinbacher/ubuntu-server/metadata.json"
  config.vm.box_download_ca_cert = "certificates/GKRoot.crt"

  config.vm.boot_timeout = 600

  config.vm.provider "virtualbox" do |l|
    l.cpus = 3
    l.memory = "8192"

    l.gui = false
    l.linked_clone = true
  end

  config.vm.provision :shell, inline: $init_script

  config.hostmanager.enabled = true
  config.hostmanager.manage_guest = true

  (1..$MASTER_COUNT).each do |i|
    ha = $MASTER_COUNT > 1
    hostname= "master#{ha ? i: ''}"
    config.vm.define(hostname) do |subconfig|
      subconfig.vm.hostname = hostname
      subconfig.vm.network :private_network, nic_type: "virtio", ip: ha ? $NODE_IP_NW + "#{i + 10}" : $MASTER_IP
      subconfig.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--cpus", "2"]
        vb.customize ["modifyvm", :id, "--memory", "2048"]
      end
      subconfig.vm.provision :shell, inline: ha ? $ha_script : $master_script
    end
  end

  (1..$NODE_COUNT).each do |i|
    config.vm.define("node#{i}") do |subconfig|
      subconfig.vm.hostname = "node#{i}"
      subconfig.vm.network :private_network, nic_type: "virtio", ip: $NODE_IP_NW + "#{i + 20}"
      subconfig.vm.provision :shell, inline: $node_script
    end
  end
end
