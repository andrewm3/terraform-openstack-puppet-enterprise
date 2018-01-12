locals {
  hostname = "${openstack_compute_instance_v2.node.name}"
  fqdn     = "${local.hostname}.${var.domain}"
}

# SSH connection details
locals {
  host        = "${openstack_compute_floatingip_v2.node.address}"
  user        = "${var.ssh_user_name}"
  private_key = "${file(var.ssh_key_file)}"
}

resource "openstack_compute_keypair_v2" "puppet" {
  name       = "${var.key_pair}"
  public_key = "${file("${var.ssh_key_file}.pub")}"
}

resource "openstack_compute_floatingip_v2" "node" {
  count = "${var.floating_ip}"
  pool  = "${var.pool}"
}

resource "openstack_compute_instance_v2" "node" {
  name = "${var.name}"
  image_name = "${var.image}"
  flavor_name = "${var.flavor}"
  key_pair = "${var.key_pair}"
  security_groups = "${var.security_groups}"
  network {
    uuid = "${var.network_uuid}"
  }
}

resource "openstack_compute_floatingip_associate_v2" "node" {
  count       = "${var.floating_ip}"
  floating_ip = "${openstack_compute_floatingip_v2.node.address}"
  instance_id = "${openstack_compute_instance_v2.node.id}"
  fixed_ip    = "${openstack_compute_instance_v2.node.access_ip_v4}"

  provisioner "file" {
    connection {
      host        = "${local.host}"
      user        = "${local.user}"
      private_key = "${local.private_key}"
    }

    source      = "conf/pe.conf"
    destination = "/tmp/pe.conf"
  }

  provisioner "remote-exec" {
    connection {
      host        = "${local.host}"
      user        = "${local.user}"
      private_key = "${local.private_key}"
    }

    inline = [
      # Hostname and /etc/hosts
      "sudo hostname ${local.hostname}",
      "echo $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) ${local.fqdn} ${local.hostname} | sudo tee -a /etc/hosts",

      # CSR attributes
      "sudo mkdir -p /etc/puppetlabs/puppet",
      "sudo tee /etc/puppetlabs/puppet/csr_attributes.yaml << YAML",
      "extension_requests:",
      "  pp_role: '${var.pp_role}'",
      "YAML",

      # Download the Puppet Enterprise installer
      "until curl --max-time 300 -o pe-installer.tar.gz \"${var.pe_source_url}\"; do sleep 1; done",
      "tar -xzf pe-installer.tar.gz",

      # Install Puppet enterprise
      "sudo ./puppet-enterprise-*-el-7-x86_64/puppet-enterprise-installer -c /tmp/pe.conf",

      # Run Puppet a few times to finalise installation
      "until sudo /opt/puppetlabs/bin/puppet agent -t; do sleep 1; done",
    ]
  }
}
