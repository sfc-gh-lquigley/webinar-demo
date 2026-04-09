terraform {
  required_providers {
    observe = {
      source  = "observeinc/observe"
      version = "~> 0.14"
    }
  }
}

provider "observe" {
  customer  = "193729085807"
  api_token = var.observe_api_token
  domain    = "observeinc.com"
}

variable "observe_api_token" {
  type      = string
  sensitive = true
}

data "observe_workspace" "sandbox" {
  name = "Default"
}

data "observe_dataset" "aws_logs" {
  workspace = data.observe_workspace.sandbox.oid
  name      = "AWS-Quickstart/Logs"
}

data "observe_dataset" "k8s_logs" {
  workspace = data.observe_workspace.sandbox.oid
  name      = "Kubernetes Explorer/Kubernetes Logs"
}

resource "observe_dashboard" "waf_overview" {
  name        = "WAF Overview - Demo"
  description = "Overview dashboard for WAF, host, and app logs from the observe-demo-app"
  workspace   = data.observe_workspace.sandbox.oid

  stages = jsonencode([
    {
      id = "stage-waf-list"
      input = [
        {
          datasetId   = data.observe_dataset.aws_logs.id
          datasetPath = null
          inputName   = "AWS-Quickstart/Logs"
          inputRole   = "Data"
          stageId     = null
        },
      ]
      params   = null
      pipeline = ""
    },
    {
      id = "stage-waf-timechart"
      input = [
        {
          datasetId   = data.observe_dataset.aws_logs.id
          datasetPath = null
          inputName   = "AWS-Quickstart/Logs"
          inputRole   = "Data"
          stageId     = null
        },
      ]
      params   = null
      pipeline = "timechart count()"
    },
    {
      id = "stage-host-list"
      input = [
        {
          datasetId   = data.observe_dataset.k8s_logs.id
          datasetPath = null
          inputName   = "Kubernetes Explorer/Kubernetes Logs"
          inputRole   = "Data"
          stageId     = null
        },
      ]
      params   = null
      pipeline = ""
    },
    {
      id = "stage-host-timechart"
      input = [
        {
          datasetId   = data.observe_dataset.k8s_logs.id
          datasetPath = null
          inputName   = "Kubernetes Explorer/Kubernetes Logs"
          inputRole   = "Data"
          stageId     = null
        },
      ]
      params   = null
      pipeline = "timechart count()"
    },
  ])

  layout = jsonencode({
    autoPack = true
    gridLayout = {
      sections = [
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "WAF Logs"
          }
          items = [
            {
              card = {
                cardType = "stage"
                stageId  = "stage-waf-timechart"
              }
              layout = {
                height = 6
                width  = 12
                x      = 0
                y      = 0
              }
            },
            {
              card = {
                cardType = "stage"
                stageId  = "stage-waf-list"
              }
              layout = {
                height = 8
                width  = 12
                x      = 0
                y      = 6
              }
            },
          ]
        },
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "Host Logs"
          }
          items = [
            {
              card = {
                cardType = "stage"
                stageId  = "stage-host-timechart"
              }
              layout = {
                height = 6
                width  = 12
                x      = 0
                y      = 0
              }
            },
            {
              card = {
                cardType = "stage"
                stageId  = "stage-host-list"
              }
              layout = {
                height = 8
                width  = 12
                x      = 0
                y      = 6
              }
            },
          ]
        },
      ]
    }
  })
}

output "dashboard_id" {
  value = observe_dashboard.waf_overview.id
}

output "dashboard_oid" {
  value = observe_dashboard.waf_overview.oid
}

resource "observe_dashboard" "k8s_logs" {
  name        = "Luke/maxbot test"
  description = "Log list and log volume over time grouped by service and cluster"
  workspace   = data.observe_workspace.sandbox.oid

  stages = jsonencode([
    {
      id = "stage-k8s-list"
      input = [
        {
          datasetId   = data.observe_dataset.k8s_logs.id
          datasetPath = null
          inputName   = "Kubernetes Explorer/Kubernetes Logs"
          inputRole   = "Data"
          stageId     = null
        },
      ]
      params   = null
      pipeline = "pick_col timestamp, cluster, namespace, pod, container, body"
    },
    {
      id = "stage-k8s-barchart"
      input = [
        {
          datasetId   = data.observe_dataset.k8s_logs.id
          datasetPath = null
          inputName   = "Kubernetes Explorer/Kubernetes Logs"
          inputRole   = "Data"
          stageId     = null
        },
      ]
      params   = null
      pipeline = "timechart 1m, A_log_count:count(), group_by(cluster, namespace)"
    },
  ])

  layout = jsonencode({
    autoPack = true
    gridLayout = {
      sections = [
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "Kubernetes Logs"
          }
          items = [
            {
              card = {
                cardType = "stage"
                stageId  = "stage-k8s-barchart"
              }
              layout = {
                height = 6
                width  = 12
                x      = 0
                y      = 0
              }
            },
            {
              card = {
                cardType = "stage"
                stageId  = "stage-k8s-list"
              }
              layout = {
                height = 10
                width  = 12
                x      = 0
                y      = 6
              }
            },
          ]
        },
      ]
    }
  })
}

output "k8s_dashboard_id" {
  value = observe_dashboard.k8s_logs.id
}

output "k8s_dashboard_oid" {
  value = observe_dashboard.k8s_logs.oid
}
