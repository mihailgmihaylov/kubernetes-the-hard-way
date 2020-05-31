VAGRANT_API_VERSION = '2'.freeze

Vagrant.configure(VAGRANT_API_VERSION) do |config|
  config.vm.network "private_network", type: "dhcp"
  config.hostmanager.enabled = true
  config.hostmanager.manage_host = false
  config.hostmanager.manage_guest = true
  config.hostmanager.ignore_private_ip = false
  config.hostmanager.include_offline = true
  config.hostmanager.ip_resolver = proc do |vm, resolving_vm|
    if hostname = (vm.ssh_info && vm.ssh_info[:host])
      `vagrant ssh #{vm.name} -c "/sbin/ifconfig eth0" | grep "inet addr" | tail -n 1 | egrep -o "[0-9\.]+" | head -n 1 2>&1`.split("\n").first[/(\d+\.\d+\.\d+\.\d+)/, 1]
    end
  end
  ENV['VAGRANT_NO_PARALLEL'] = 'yes'

  NODES = %w(
    master-0
    master-1
    master-2
    worker-0
    worker-1
    worker-2
  ).freeze

  NODES.each do |node|
    config.vm.define(node) do |node_config|
      node_config.vm.hostname=node
      if node =~ /^master.*/
        node_config.vm.provider :docker do |d, override|
          d.build_dir = 'master'
          d.name = node
          d.has_ssh = true
          d.privileged = true
        end
        number = node.split('-').last
        node_config.vm.synced_folder "mountdirs", "/opt/kubernetes"
        node_config.vm.network :forwarded_port, guest: 443, host: "1#{number}443"
      elsif node =~ /^worker.*/
        node_config.vm.provider :docker do |d, override|
          d.build_dir = 'worker'
          d.name = node
          d.has_ssh = true
          d.privileged = true
        end
        node_config.vm.synced_folder "mountdirs", "/opt/kubernetes"
      else
        node_config.vm.provider :docker do |d, override|
          d.build_dir = node
          d.name = node
          d.has_ssh = true
          d.privileged = true
        end
      end


      # Provisioning Steps
      # if node =~ /^master.*/
      #   node_config.vm.provision :ansible, run: :always do |ansible|
      #     ansible.playbook = 'scripts/provisioner.yml'
      #   end
      # end
    end
  end
end
