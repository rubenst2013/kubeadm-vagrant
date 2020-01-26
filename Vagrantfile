require_relative 'lib/vars'
require_relative 'lib/init_script'
require_relative 'lib/ha_script'
require_relative 'lib/master_script'
require_relative 'lib/node_script'
require_relative 'lib/load_balancer'

current_dir    = File.dirname(File.expand_path(__FILE__))

Vagrant.configure("2") do |config|
  config.vm.box_check_update = false

  config.vm.box = "ubuntu-server-without-microk8s"

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

      subconfig.vm.provision "load-balancer", type: "shell", run: "once", inline: $lb_script
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

      if hostname == "master#{ha ? 1: ''}"
        #subconfig.vm.provision "cni-flannel",               type: "shell", run: "once", path: "provisioning/cni/flannel/provision.sh"
        subconfig.vm.provision "cni-weave",                 type: "shell", run: "once", path: "provisioning/cni/weave/provision.sh"
        subconfig.vm.provision "csi-external-snapshotter",  type: "shell", run: "once", path: "provisioning/csi/external-snapshotter.sh"

        # Once vagrant has finished provisioning your environment, run these commands against master1 manually
        subconfig.vm.provision "csi-driver-host-path",      type: "shell", run: "never", path: "provisioning/csi/driver-host-path.sh"
        subconfig.vm.provision "cni-nginx-ingress",         type: "shell", run: "never", path: "provisioning/cni/nginx/provision.sh"
      end
    end
  end

  (1..$NODE_COUNT).each do |i|
    config.vm.define("node#{i}") do |subconfig|
      subconfig.vm.hostname = "node#{i}"
      subconfig.vm.network :private_network, nic_type: "virtio", ip: $NODE_IP_NW + "#{i + 20}", virtualbox__intnet: "node_network"

      subconfig.vm.provider :virtualbox do |vb|
        disk = current_dir + "/local_storage_#{i}.vdi"
        unless File.exist?(disk)
          vb.customize [
            "createmedium", "disk",
            "--filename", disk,
            "--size", 500 * 1024,
            "--format", "vdi",
            "--variant", "Standard"
          ]
        end
        vb.customize [
          "storageattach", :id,
            "--storagectl", "SCSI Controller",
            "--port", "5",
            "--device", "0",
            "--type", "hdd",
            "--medium", disk,
            "--mtype", "normal",
            "--nonrotational", "on",
            "--discard", "on"
        ]
      end

      subconfig.vm.provision "lvm", type: "shell", run: "once", path: "provisioning/lvm.sh", keep_color: "true"

      subconfig.vm.provision "init", type: "shell", run: "once", inline: $init_script, keep_color: "true"
      subconfig.vm.provision "node", type: "shell", run: "once", inline: $node_script, keep_color: "true"
    end
  end
end
