Vagrant.configure("2") do |config|
  box_name = ENV["BOX_NAME"] || "debian-12"

  config.vm.box = box_name
  config.vm.hostname = "test-#{box_name}"
  config.vm.synced_folder ".", "/vagrant"

  # Run BATS tests inside the VM
  config.vm.provision "shell", inline: <<-SHELL
    set -euo pipefail
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y --no-install-recommends bats
    install -d -m 0755 /usr/local/lib/k8s
    install -m 0644 /vagrant/packer_templates/scripts/_common/lib.sh /usr/local/lib/k8s/lib.sh
    bats -r /vagrant/tests/scripts || exit 1
  SHELL
end

