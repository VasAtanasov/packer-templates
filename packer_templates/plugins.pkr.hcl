// =============================================================================
// Packer Plugin Requirements
// =============================================================================
// Define required Packer plugins and their versions
// =============================================================================

packer {
  required_version = ">= 1.7.0"

  required_plugins {
    virtualbox = {
      version = ">= 1.1.3"
      source  = "github.com/hashicorp/virtualbox"
    }
    vagrant = {
      version = ">= 1.1.6"
      source  = "github.com/hashicorp/vagrant"
    }
  }
}