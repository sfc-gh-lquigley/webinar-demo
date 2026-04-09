terraform {
  required_providers {
    observe = {
      source  = "observeinc/observe"
      version = "~> 0.14"
    }
  }
}

provider "observe" {
  customer  = "146268791759"
  api_token = var.observe_api_token
  domain    = "observeinc.com"
}

variable "observe_api_token" {
  type      = string
  sensitive = true
}

data "observe_workspace" "default" {
  name = "Demo Playground"
}
