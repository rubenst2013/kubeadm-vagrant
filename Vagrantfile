require_relative 'lib/vars'
require_relative 'lib/init_script'
require_relative 'lib/ha_script'
require_relative 'lib/master_script'
require_relative 'lib/node_script'
require_relative 'lib/load_balancer'

Vagrant.configure("2") do |config|
  config.vm.box_check_update = false

  config.vm.box = "rsteinbacher/ubuntu-server"
  config.vm.box_version = "0.1.0-alpha.2"
  config.vm.box_url = "https://nexus3-test.es.gk-software.com/nexus/repository/vagrant/boxes/custom/rsteinbacher/ubuntu-server/metadata.json"
  config.vm.box_download_ca_cert = "certificates/GKRoot.crt"

  config.vm.boot_timeout = 600

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 3
    vb.memory = "8192"

    vb.gui = false
    vb.linked_clone = true

    vb.customize ["modifyvm", :id, "--hwvirtex", "on"]
    vb.customize ["modifyvm", :id, "--triplefaultreset", "on"]
    vb.customize ["modifyvm", :id, "--largepages", "on"]
    vb.customize ["modifyvm", :id, "--vtxvpid", "on"]
    vb.customize ["modifyvm", :id, "--graphicscontroller", "vmsvga"]
    vb.customize ["modifyvm", :id, "--vram", "128"]
  end

  config.hostmanager.enabled = true
  config.hostmanager.manage_guest = true

  (1..$PUBLIC_LOAD_BALANCER_COUNT).each do |i|
    hostname= "load-balancer#{i}"
    config.vm.define(hostname) do |subconfig|
      subconfig.vm.hostname = hostname
      subconfig.vm.network :private_network, nic_type: "virtio", ip: $NODE_IP_NW + "#{i + 90}", virtualbox__intnet: "node_network"
      subconfig.vm.network :private_network, nic_type: "virtio", ip: $PUBLIC_LOAD_BALANCER_IP_NW + "#{i + 10}", virtualbox__intnet: false
      subconfig.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--cpus", "1"]
        vb.customize ["modifyvm", :id, "--memory", "1536"]
      end

      subconfig.vm.provision "remove-microk8s", type: "shell", run: "once", inline: '''
        #!/bin/bash

        microk8s.stop
        snap remove microk8s
        ip a | grep -o "veth[a-z0-9]\+" | xargs -I[] sudo ip link delete []
        sudo ip link delete flannel.1
      '''

      subconfig.vm.provision "load-balancer", type: "shell", run: "once", inline: $lb_script
      #subconfig.vm.provision :shell, inline: ha ? $ha_script : $master_script
    end
  end

  (1..$MASTER_COUNT).each do |i|
    ha = $MASTER_COUNT > 1
    hostname= "master#{ha ? i: ''}"
    config.vm.define(hostname) do |subconfig|
      subconfig.vm.hostname = hostname
      subconfig.vm.network :private_network, nic_type: "virtio", ip: ha ? $NODE_IP_NW + "#{i + 10}" : $MASTER_IP, virtualbox__intnet: "node_network"
      subconfig.vm.provider :virtualbox do |vb|
        vb.customize ["modifyvm", :id, "--cpus", "2"]
        vb.customize ["modifyvm", :id, "--memory", "2048"]
      end
      
      subconfig.vm.provision "init", type: "shell", run: "once", inline: $init_script
      subconfig.vm.provision "master", type: "shell", run: "once", inline: ha ? $ha_script : $master_script
    end
  end

  (1..$NODE_COUNT).each do |i|
    config.vm.define("node#{i}") do |subconfig|
      subconfig.vm.hostname = "node#{i}"
      subconfig.vm.network :private_network, nic_type: "virtio", ip: $NODE_IP_NW + "#{i + 20}", virtualbox__intnet: "node_network"

      subconfig.vm.provision "init", type: "shell", run: "once", inline: $init_script, keep_color: "true"
      subconfig.vm.provision "node", type: "shell", run: "once", inline: $node_script, keep_color: "true"
    end
  end
end
