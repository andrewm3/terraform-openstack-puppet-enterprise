terraform-openstack-puppet-enterprise
=====================================

This repository is a Terraform module designed to be able to spin up Puppet masters and agents.

See the [examples](examples/) directory for a demonstration of how the module can be used in different scenarios. To try out one of the examples, run the below:

    $ cd examples/<example>
    $ terraform init
    $ terraform apply
    
And follow the prompts to enter values for the variables. Note: the examples assume a default SSH key location of `~/.ssh/id_rsa.terraform` - change the `ssh_key_file` variable if you prefer to use another.
