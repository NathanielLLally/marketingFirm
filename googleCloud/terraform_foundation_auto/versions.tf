terraform {
  required_version = ">= 1.3"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 5.22"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = ">= 5.22"
    }
  }
  provider_meta "google" {
    module_name = "blueprints/terraform/fs-exported-af1b09b0ce26c2ce/v0.1.0"
  }
  provider_meta "google-beta" {
    module_name = "blueprints/terraform/fs-exported-af1b09b0ce26c2ce/v0.1.0"
  }
}
