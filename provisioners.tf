# Provisioners
locals {
  master_fqdn = "${var.master_hostname}.${var.domain}"

  pre_provisioner = [
    # Hostname and /etc/hosts
    "sudo hostname ${local.hostname}",
    "echo $(curl -s http://169.254.169.254/latest/meta-data/local-ipv4) ${local.fqdn} ${local.hostname} | sudo tee -a /etc/hosts",

    # CSR attributes
    "sudo mkdir -p /etc/puppetlabs/puppet",
    "sudo tee /etc/puppetlabs/puppet/csr_attributes.yaml << YAML",
    "extension_requests:",
    "  pp_role: '${var.pp_role}'",
    "YAML",
  ]

  node_provisioners = {
    "puppet-master" = [
      # Autosign nodes from domain
      "echo '*.${var.domain}' | sudo tee /etc/puppetlabs/puppet/autosign.conf",

      # Download the Puppet Enterprise installer
      "while : ; do",
      "  until curl --max-time 300 -o pe-installer.tar.gz \"${var.pe_source_url}\"; do sleep 1; done",
      "  tar -xzf pe-installer.tar.gz && break",
      "done",

      # Install Puppet enterprise
      "cat > pe.conf <<-EOF",
      "${var.pe_conf}",
      "EOF",
      "sudo ./puppet-enterprise-*-el-7-x86_64/puppet-enterprise-installer -c pe.conf",

      # Run Puppet a few times to finalise installation
      "until sudo /opt/puppetlabs/bin/puppet agent -t; do sleep 1; done",
    ],

    "compile-master" = [
      "echo '${var.master_ip} ${local.master_fqdn} ${var.master_hostname}' | sudo tee -a /etc/hosts",
      "curl -k 'https://${local.master_fqdn}:8140/packages/current/install.bash' | sudo bash -s main:dns_alt_names=${var.dns_alt_names}",
    ]

    "posix-agent" = [
      "echo '${var.master_ip} ${local.master_fqdn} ${var.master_hostname}' | sudo tee -a /etc/hosts",
      "curl -k 'https://${local.master_fqdn}:8140/packages/current/install.bash' | sudo bash",
    ],
  }

  node_provisioner = "${local.node_provisioners[var.node_type]}"

  post_provisioner = [
    # Run Puppet a few times to finalise installation
    "until sudo /opt/puppetlabs/bin/puppet agent -t; do sleep 1; done",
  ]

  all_provisioners = "${concat(local.pre_provisioner, local.node_provisioner, var.custom_provisioner, local.post_provisioner)}"
}
