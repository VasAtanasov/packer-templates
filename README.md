# packer-templates

### Building Boxes

#### Requirements

- [Packer](https://www.packer.io/)
- [Vagrant](https://www.vagrantup.com/)
- [VirtualBox](https://www.virtualbox.org/)

#### Using `packer`

To build an Ubuntu 18.04 box for only the VirtualBox provider

```bash
cd packer_templates/ubuntu
packer build -var 'version=202207.14.0' ubuntu-20.04-amd64.json
```

> **Note**: version var must be set

If the build is successful, your box files will be in the `builds` directory at the root of the repository.

> **Note**: This configuration includes a post-processor that pushes the built box to Vagrant Cloud (which requires a `VAGRANT_CLOUD_TOKEN` environment variable to be set); remove the `vagrant-cloud` post-processor from the Packer template to build the box locally and not push it to Vagrant Cloud. You don't need to specify a `version` variable either, if not using the `vagrant-cloud` post-processor.
>
> box_basename can be overridden like other Packer vars with `-var 'box_basename=ubuntu-18.04'`
