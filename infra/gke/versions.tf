terraform {
  required_version = ">= 1.6.0"
  required_providers {
    google = { source = "hashicorp/google", version = ">= 6.36, < 8.0" }
    flux   = { source = "fluxcd/flux", version = "~> 1.5" }
    tls    = { source = "hashicorp/tls", version = "~> 4.0" }
    github = { source = "integrations/github", version = "~> 6.4" }
    local  = { source = "hashicorp/local", version = "~> 2.4" }
  }
}
