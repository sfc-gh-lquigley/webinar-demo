data "observe_dataset" "cloudtrail_events" {
  workspace = data.observe_workspace.sandbox.oid
  name      = "aws/CloudTrail Events"
}

data "observe_dataset" "lambda_metrics" {
  workspace = data.observe_workspace.sandbox.oid
  name      = "aws/Lambda Function Metrics"
}

data "observe_dataset" "lambda_functions" {
  workspace = data.observe_workspace.sandbox.oid
  name      = "aws/Lambda Function"
}

locals {
  cloudtrail_input = [
    {
      datasetId   = data.observe_dataset.cloudtrail_events.id
      datasetPath = null
      inputName   = "aws/CloudTrail Events"
      inputRole   = "Data"
      stageId     = null
    },
  ]

  lambda_metrics_input = [
    {
      datasetId   = data.observe_dataset.lambda_metrics.id
      datasetPath = null
      inputName   = "aws/Lambda Function Metrics"
      inputRole   = "Data"
      stageId     = null
    },
  ]

  lambda_functions_input = [
    {
      datasetId   = data.observe_dataset.lambda_functions.id
      datasetPath = null
      inputName   = "aws/Lambda Function"
      inputRole   = "Data"
      stageId     = null
    },
  ]
}

resource "observe_dashboard" "aws_overview" {
  name        = "AWS Overview"
  description = "Comprehensive AWS dashboard covering CloudTrail API activity, Lambda health, security and IAM operations, and function inventory."
  workspace   = data.observe_workspace.sandbox.oid

  stages = jsonencode([
    # ── CloudTrail: API Activity ────────────────────────────────────────────
    {
      id       = "ct-activity-timechart"
      input    = local.cloudtrail_input
      params   = null
      pipeline = "timechart 1m, event_count:count(), group_by(eventSource)"
    },
    {
      id       = "ct-top-services"
      input    = local.cloudtrail_input
      params   = null
      pipeline = <<-OPAL
        statsby call_count:count(), group_by(eventSource)
        sort desc(call_count)
        limit 10
      OPAL
    },
    {
      id       = "ct-top-operations"
      input    = local.cloudtrail_input
      params   = null
      pipeline = <<-OPAL
        statsby call_count:count(), error_count:countif(not isnull(errorCode) and errorCode != ""), group_by(eventSource, eventName)
        sort desc(call_count)
        limit 20
      OPAL
    },

    # ── CloudTrail: Error Analysis ──────────────────────────────────────────
    {
      id       = "ct-error-timechart"
      input    = local.cloudtrail_input
      params   = null
      pipeline = <<-OPAL
        filter not isnull(errorCode) and errorCode != ""
        timechart 5m, error_count:count(), group_by(eventSource)
      OPAL
    },
    {
      id       = "ct-error-table"
      input    = local.cloudtrail_input
      params   = null
      pipeline = <<-OPAL
        filter not isnull(errorCode) and errorCode != ""
        statsby count:count(), group_by(errorCode, eventSource, eventName)
        sort desc(count)
        limit 20
      OPAL
    },
    {
      id       = "ct-events-by-region"
      input    = local.cloudtrail_input
      params   = null
      pipeline = <<-OPAL
        statsby event_count:count(), group_by(awsRegion)
        sort desc(event_count)
      OPAL
    },

    # ── CloudTrail: Security & IAM ──────────────────────────────────────────
    {
      id       = "ct-iam-ops"
      input    = local.cloudtrail_input
      params   = null
      pipeline = <<-OPAL
        filter eventSource ~ /iam\.amazonaws\.com/ or eventSource ~ /sts\.amazonaws\.com/
        make_col user_arn:string(userIdentity.arn)
        statsby count:count(), group_by(eventName, user_arn, awsRegion)
        sort desc(count)
        limit 20
      OPAL
    },
    {
      id       = "ct-top-callers"
      input    = local.cloudtrail_input
      params   = null
      pipeline = <<-OPAL
        make_col user_arn:string(userIdentity.arn), user_type:string(userIdentity.type)
        filter not isnull(user_arn) and user_arn != ""
        statsby call_count:count(), group_by(user_arn, user_type)
        sort desc(call_count)
        limit 15
      OPAL
    },
    {
      id       = "ct-region-timechart"
      input    = local.cloudtrail_input
      params   = null
      pipeline = "timechart 5m, event_count:count(), group_by(awsRegion)"
    },
    {
      id       = "ct-assume-role"
      input    = local.cloudtrail_input
      params   = null
      pipeline = <<-OPAL
        filter eventName = "AssumeRole" or eventName = "AssumeRoleWithWebIdentity" or eventName = "AssumeRoleWithSAML"
        timechart 5m, assume_role_count:count(), group_by(eventName)
      OPAL
    },

    # ── Lambda: Function Health ─────────────────────────────────────────────
    {
      id       = "lambda-invocations"
      input    = local.lambda_metrics_input
      params   = null
      pipeline = <<-OPAL
        align options(bins: 60), inv:sum(m("Invocations"))
        timechart invocations:sum(inv), group_by(functionName)
      OPAL
    },
    {
      id       = "lambda-duration"
      input    = local.lambda_metrics_input
      params   = null
      pipeline = <<-OPAL
        align options(bins: 60), dur:avg(m("Duration"))
        timechart avg_duration_ms:avg(dur), group_by(functionName)
      OPAL
    },
    {
      id       = "lambda-errors"
      input    = local.lambda_metrics_input
      params   = null
      pipeline = <<-OPAL
        align options(bins: 60), err:sum(m("Errors"))
        timechart total_errors:sum(err), group_by(functionName)
      OPAL
    },
    {
      id       = "lambda-throttles"
      input    = local.lambda_metrics_input
      params   = null
      pipeline = <<-OPAL
        align options(bins: 60), thr:sum(m("Throttles"))
        timechart total_throttles:sum(thr), group_by(functionName)
      OPAL
    },
    {
      id       = "lambda-concurrent"
      input    = local.lambda_metrics_input
      params   = null
      pipeline = <<-OPAL
        align options(bins: 60), conc:max(m("ConcurrentExecutions"))
        timechart max_concurrent:max(conc), group_by(functionName)
      OPAL
    },
    {
      id       = "lambda-summary"
      input    = local.lambda_metrics_input
      params   = null
      pipeline = <<-OPAL
        align options(bins: 1), inv:sum(m("Invocations")), dur:avg(m("Duration")), err:sum(m("Errors")), thr:sum(m("Throttles"))
        aggregate total_invocations:sum(inv), avg_duration_ms:avg(dur), total_errors:sum(err), total_throttles:sum(thr), group_by(functionName)
        make_col error_rate_pct:case(total_invocations > 0, 100.0 * total_errors / total_invocations, true, 0.0)
        sort desc(total_invocations)
      OPAL
    },

    # ── Lambda: Function Inventory ──────────────────────────────────────────
    {
      id       = "lambda-inventory"
      input    = local.lambda_functions_input
      params   = null
      pipeline = <<-OPAL
        topk 50, functionName
        pick_col functionName, runtime, region, memorySize, timeout, description, lastModified
        sort functionName
      OPAL
    },
  ])

  layout = jsonencode({
    autoPack = true
    gridLayout = {
      sections = [
        # ── Section 1: CloudTrail API Activity ────────────────────────────
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "CloudTrail: API Activity"
          }
          items = [
            {
              card   = { cardType = "stage", stageId = "ct-activity-timechart" }
              layout = { height = 6, width = 12, x = 0, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "ct-top-services" }
              layout = { height = 8, width = 6, x = 0, y = 6 }
            },
            {
              card   = { cardType = "stage", stageId = "ct-top-operations" }
              layout = { height = 8, width = 6, x = 6, y = 6 }
            },
          ]
        },

        # ── Section 2: CloudTrail Error Analysis ──────────────────────────
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "CloudTrail: Error Analysis"
          }
          items = [
            {
              card   = { cardType = "stage", stageId = "ct-error-timechart" }
              layout = { height = 6, width = 12, x = 0, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "ct-error-table" }
              layout = { height = 8, width = 6, x = 0, y = 6 }
            },
            {
              card   = { cardType = "stage", stageId = "ct-events-by-region" }
              layout = { height = 8, width = 6, x = 6, y = 6 }
            },
          ]
        },

        # ── Section 3: Security & IAM ─────────────────────────────────────
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "CloudTrail: Security & IAM"
          }
          items = [
            {
              card   = { cardType = "stage", stageId = "ct-assume-role" }
              layout = { height = 6, width = 12, x = 0, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "ct-iam-ops" }
              layout = { height = 8, width = 6, x = 0, y = 6 }
            },
            {
              card   = { cardType = "stage", stageId = "ct-top-callers" }
              layout = { height = 8, width = 6, x = 6, y = 6 }
            },
            {
              card   = { cardType = "stage", stageId = "ct-region-timechart" }
              layout = { height = 6, width = 12, x = 0, y = 14 }
            },
          ]
        },

        # ── Section 4: Lambda Health ──────────────────────────────────────
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "Lambda: Function Health"
          }
          items = [
            {
              card   = { cardType = "stage", stageId = "lambda-invocations" }
              layout = { height = 6, width = 6, x = 0, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "lambda-duration" }
              layout = { height = 6, width = 6, x = 6, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "lambda-errors" }
              layout = { height = 6, width = 6, x = 0, y = 6 }
            },
            {
              card   = { cardType = "stage", stageId = "lambda-throttles" }
              layout = { height = 6, width = 6, x = 6, y = 6 }
            },
            {
              card   = { cardType = "stage", stageId = "lambda-concurrent" }
              layout = { height = 6, width = 12, x = 0, y = 12 }
            },
            {
              card   = { cardType = "stage", stageId = "lambda-summary" }
              layout = { height = 5, width = 12, x = 0, y = 18 }
            },
          ]
        },

        # ── Section 5: Lambda Inventory ───────────────────────────────────
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "Lambda: Function Inventory"
          }
          items = [
            {
              card   = { cardType = "stage", stageId = "lambda-inventory" }
              layout = { height = 10, width = 12, x = 0, y = 0 }
            },
          ]
        },
      ]
    }
  })
}

output "aws_overview_dashboard_id" {
  value = observe_dashboard.aws_overview.id
}

output "aws_overview_dashboard_oid" {
  value = observe_dashboard.aws_overview.oid
}
