# Node properties
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

  provisioner "remote-exec" {
    connection {
      host        = "${local.host}"
      user        = "${local.user}"
      private_key = "${local.private_key}"
    }

    inline = "${local.all_provisioners}"
  }
}
