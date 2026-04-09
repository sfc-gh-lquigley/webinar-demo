locals {
  rmq_input = [
    {
      datasetId   = "42496691"
      datasetPath = null
      inputName   = "RabbitMQ Metrics"
      inputRole   = "Data"
      stageId     = null
    },
  ]
}

resource "observe_dashboard" "rabbitmq" {
  name        = "RabbitMQ - Operations Dashboard"
  description = "Comprehensive RabbitMQ dashboard: queue depth, throughput, dead-letter queues, consumer health, and broker infrastructure."
  workspace   = data.observe_workspace.default.oid

  stages = jsonencode([

    # ── Section 1: Queue Depth ─────────────────────────────────────────────

    {
      id       = "rmq-queue-depth"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_queue_messages"
        make_col queue:string(attributes.queue)
        filter not isnull(queue)
        timechart 1m, depth:avg(value), group_by(queue)
      OPAL
    },
    {
      id       = "rmq-messages-ready"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_queue_messages_ready"
        make_col queue:string(attributes.queue)
        filter not isnull(queue)
        timechart 1m, ready:avg(value), group_by(queue)
      OPAL
    },
    {
      id       = "rmq-messages-unacked"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_queue_messages_unacked"
        make_col queue:string(attributes.queue)
        filter not isnull(queue)
        timechart 1m, unacked:avg(value), group_by(queue)
      OPAL
    },
    {
      id       = "rmq-queue-summary"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_queue_messages" or metric = "rabbitmq_queue_messages_ready" or metric = "rabbitmq_queue_messages_unacked" or metric = "rabbitmq_queue_consumers"
        make_col queue:string(attributes.queue)
        filter not isnull(queue)
        aggregate
          total_messages:last(value),
          group_by(queue, metric)
        make_pivot metric, total_messages, function:"last", fill:0.0
        sort asc(queue)
      OPAL
    },

    # ── Section 2: Throughput & Rates ─────────────────────────────────────

    {
      id       = "rmq-publish-rate"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_queue_messages_published_total"
        make_col queue:string(attributes.queue)
        filter not isnull(queue)
        timechart 1m, publish_per_sec:rate(value), group_by(queue)
      OPAL
    },
    {
      id       = "rmq-delivery-rate"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_channel_messages_delivered_ack_total"
        make_col queue:string(attributes.queue)
        filter not isnull(queue)
        timechart 1m, deliver_per_sec:rate(value), group_by(queue)
      OPAL
    },
    {
      id       = "rmq-redelivery-rate"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_channel_messages_redelivered_total"
        make_col queue:string(attributes.queue)
        filter not isnull(queue)
        timechart 1m, redeliver_per_sec:rate(value), group_by(queue)
      OPAL
    },

    # ── Section 3: Dead Letter Queue ──────────────────────────────────────

    {
      id       = "rmq-dlq-depth"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_queue_messages"
        make_col queue:string(attributes.queue)
        filter queue = "failed-orders"
        timechart 1m, dlq_depth:avg(value)
      OPAL
    },
    {
      id       = "rmq-dlq-rate"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_global_messages_dead_lettered_maxlen_total"
        timechart 1m, dead_lettered_per_sec:rate(value)
      OPAL
    },
    {
      id       = "rmq-overflow-comparison"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_queue_messages" and string(attributes.queue) = "orders-standard" or metric = "rabbitmq_queue_messages" and string(attributes.queue) = "failed-orders"
        make_col queue:string(attributes.queue)
        timechart 1m, depth:avg(value), group_by(queue)
      OPAL
    },

    # ── Section 4: Consumer Health ────────────────────────────────────────

    {
      id       = "rmq-consumer-count"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_queue_consumers"
        make_col queue:string(attributes.queue)
        filter not isnull(queue)
        timechart 1m, consumers:avg(value), group_by(queue)
      OPAL
    },
    {
      id       = "rmq-consumer-utilization"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_queue_consumer_utilisation"
        make_col queue:string(attributes.queue)
        filter not isnull(queue)
        timechart 1m, utilization_pct:avg(value) * 100, group_by(queue)
      OPAL
    },
    {
      id       = "rmq-publish-vs-deliver"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_queue_messages_published_total" or metric = "rabbitmq_channel_messages_delivered_ack_total"
        make_col queue:string(attributes.queue)
        filter queue = "orders-standard" or queue = "audit-log" or queue = "payments"
        timechart 1m, rate:rate(value), group_by(queue, metric)
      OPAL
    },

    # ── Section 5: Broker Infrastructure ─────────────────────────────────

    {
      id       = "rmq-memory"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_process_resident_memory_bytes"
        make_col memory_mb:value / 1048576
        timechart 1m, memory_mb:avg(memory_mb)
      OPAL
    },
    {
      id       = "rmq-disk"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_disk_space_available_bytes"
        make_col disk_gb:value / 1073741824
        timechart 5m, disk_gb:avg(disk_gb)
      OPAL
    },
    {
      id       = "rmq-connections"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_connections"
        timechart 1m, connections:avg(value)
      OPAL
    },
    {
      id       = "rmq-channels"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_channels"
        timechart 1m, channels:avg(value)
      OPAL
    },
    {
      id       = "rmq-erlang-processes"
      input    = local.rmq_input
      params   = null
      pipeline = <<-OPAL
        filter metric = "rabbitmq_erlang_processes_used"
        timechart 5m, erlang_procs:avg(value)
      OPAL
    },
  ])

  layout = jsonencode({
    autoPack = true
    gridLayout = {
      sections = [

        # ── Section 1: Queue Backlog ───────────────────────────────────────
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "Queue Depth & Backlog"
          }
          items = [
            {
              card   = { cardType = "stage", stageId = "rmq-queue-depth" }
              layout = { height = 7, width = 12, x = 0, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-messages-ready" }
              layout = { height = 7, width = 6, x = 0, y = 7 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-messages-unacked" }
              layout = { height = 7, width = 6, x = 6, y = 7 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-queue-summary" }
              layout = { height = 8, width = 12, x = 0, y = 14 }
            },
          ]
        },

        # ── Section 2: Message Throughput ──────────────────────────────────
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "Message Throughput (msgs/sec)"
          }
          items = [
            {
              card   = { cardType = "stage", stageId = "rmq-publish-rate" }
              layout = { height = 7, width = 6, x = 0, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-delivery-rate" }
              layout = { height = 7, width = 6, x = 6, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-redelivery-rate" }
              layout = { height = 6, width = 12, x = 0, y = 7 }
            },
          ]
        },

        # ── Section 3: Dead Letter Queue ───────────────────────────────────
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "Dead Letter Queue (DLQ)"
          }
          items = [
            {
              card   = { cardType = "stage", stageId = "rmq-dlq-depth" }
              layout = { height = 7, width = 6, x = 0, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-dlq-rate" }
              layout = { height = 7, width = 6, x = 6, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-overflow-comparison" }
              layout = { height = 7, width = 12, x = 0, y = 7 }
            },
          ]
        },

        # ── Section 4: Consumer Health ─────────────────────────────────────
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "Consumer Health"
          }
          items = [
            {
              card   = { cardType = "stage", stageId = "rmq-consumer-count" }
              layout = { height = 7, width = 6, x = 0, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-consumer-utilization" }
              layout = { height = 7, width = 6, x = 6, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-publish-vs-deliver" }
              layout = { height = 7, width = 12, x = 0, y = 7 }
            },
          ]
        },

        # ── Section 5: Broker Infrastructure ───────────────────────────────
        {
          card = {
            cardType = "section"
            closed   = false
            title    = "Broker Infrastructure"
          }
          items = [
            {
              card   = { cardType = "stage", stageId = "rmq-memory" }
              layout = { height = 6, width = 6, x = 0, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-disk" }
              layout = { height = 6, width = 6, x = 6, y = 0 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-connections" }
              layout = { height = 6, width = 4, x = 0, y = 6 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-channels" }
              layout = { height = 6, width = 4, x = 4, y = 6 }
            },
            {
              card   = { cardType = "stage", stageId = "rmq-erlang-processes" }
              layout = { height = 6, width = 4, x = 8, y = 6 }
            },
          ]
        },
      ]
    }
  })
}

output "rabbitmq_dashboard_id" {
  value = observe_dashboard.rabbitmq.id
}

output "rabbitmq_dashboard_oid" {
  value = observe_dashboard.rabbitmq.oid
}

output "rabbitmq_dashboard_url" {
  value = "https://146268791759.observeinc.com/workspace/dashboard/${observe_dashboard.rabbitmq.id}"
}
