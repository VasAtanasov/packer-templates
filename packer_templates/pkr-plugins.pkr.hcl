packer {
  required_version = ">= 1.7.0"
  required_plugins {
    virtualbox = {
      version = ">= 1.0.3"
      source  = "github.com/hashicorp/virtualbox"
    }
    vagrant = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}
