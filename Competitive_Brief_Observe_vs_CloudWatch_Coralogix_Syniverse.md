# Competitive Brief: Observe vs. CloudWatch & Coralogix for Syniverse

> **Classification:** Internal Use Only
> **Last Updated:** March 26, 2026

---

## Executive Summary

Syniverse is running six or more observability tools — CloudWatch, X-Ray, Splunk (security), Graylog, EFK, Prometheus/Grafana, and homegrown solutions — with no standardized platform. Their primary driver is CloudWatch cost escalation ("skyrocketing"), with a stated savings target of 20-30%. They want a single, centralized observability platform covering both their cloud (Kubernetes, EC2/ECS) and larger on-prem footprint, standardized on OpenTelemetry.

**The two competitors in this deal serve different roles:**

- **AWS CloudWatch** is the incumbent. Syniverse is paying too much and getting fragmented signal coverage in return. CloudWatch is the cost problem they're trying to solve.
- **Coralogix** is a potential replacement being evaluated for its cost optimization story (TCO Optimizer, unit-based pricing). It's the "we can do it cheaper" pitch.

**Observe's position:** Neither CloudWatch nor Coralogix can deliver what Syniverse actually needs — a single platform, single query language, single UI that covers all signal types across cloud and on-prem, with native OTLP ingestion and no data tiering decisions. Observe is the platform consolidation play, not just the cost reduction play.

---

## 1. Solution Profiles

### AWS CloudWatch

| Attribute | Detail |
|---|---|
| **Vendor** | Amazon Web Services |
| **Type** | Cloud-native monitoring suite (AWS-only) |
| **Architecture** | Separate services: CloudWatch Logs, CloudWatch Metrics, X-Ray (traces), Application Signals, Alarms, Dashboards |
| **Query Language(s)** | Logs Insights (SQL-like) for logs; PromQL-compatible for metrics; X-Ray filter expressions for traces |
| **Pricing** | Consumption-based: $0.50/GB log ingest + $0.03/GB/mo storage + $0.005/GB query; $0.30/metric for custom metrics; separate X-Ray trace charges |
| **Retention** | Default "Never Expire" (storage costs compound); configurable per log group |
| **On-Prem Support** | None. AWS services only. |
| **OTel Support** | ADOT (AWS Distro for OpenTelemetry) — a fork with AWS-specific extensions |

### Coralogix

| Attribute | Detail |
|---|---|
| **Vendor** | Coralogix (private, Israel-based) |
| **Type** | SaaS observability platform |
| **Architecture** | Kafka-based ingestion with 3-tier data pipeline (Frequent Search, Monitoring, Compliance). Customer-owned S3 storage. |
| **Query Language** | DataPrime |
| **Pricing** | Unit-based: 1 unit = $1.50. Logs $0.42/GB, Traces $0.16/GB, Metrics $0.05/GB. TCO Optimizer routes data to tiers. |
| **Retention** | "Infinite" via S3 remote query. Frequent Search hot storage: configurable (recommended 7 days). |
| **On-Prem Support** | Limited. Primarily cloud-native SaaS. |
| **OTel Support** | Supported but architecture optimized for Coralogix-native pipelines |

### Observe

| Attribute | Detail |
|---|---|
| **Vendor** | Observe Inc. (Snowflake) |
| **Type** | Unified observability platform backed by Snowflake data lake |
| **Architecture** | Single Snowflake-backed data store for all signal types. Knowledge Graph for entity relationships. |
| **Query Language** | OPAL — one language for logs, metrics, traces, and entities |
| **Pricing** | Subscription based on committed ingest volume. No per-user, per-dashboard, per-alert, or per-query fees. |
| **Retention** | 13-month default hot retention. No rehydration. No tiering decisions. ~10x compression. |
| **On-Prem Support** | OTel Collector-based collection from on-prem environments |
| **OTel Support** | Native OTLP ingestion (gRPC/HTTP). No proprietary agents. |

### Key Architectural Contrast

| Signal Type | CloudWatch | Coralogix | Observe |
|---|---|---|---|
| **Logs** | CloudWatch Logs + Logs Insights | DataPrime + 3-tier pipeline | Unified data lake + OPAL |
| **Metrics** | CloudWatch Metrics (custom + detailed) | Metrics pipeline ($0.05/GB) | Unified data lake + OPAL |
| **Traces** | X-Ray (separate service) | Traces pipeline ($0.16/GB) | Unified data lake + OPAL |
| **Cross-Signal Query** | Not possible — separate services | Limited — separate views per signal | Single OPAL query across all signals |
| **Entity Relationships** | None | None | Knowledge Graph auto-discovery |
| **AI Investigation** | CloudWatch Investigations (Dec 2025 GA, limited to 2 concurrent per region) | Olly AI (newer, less proven) | AI SRE with full Knowledge Graph context |

**What this means for Syniverse:** Syniverse's #1 requirement is "a single, centralized observability platform." CloudWatch is structurally incapable of this — it's a collection of separate AWS services, each with its own UI section and query approach, that only works for AWS resources. Coralogix unifies more than CloudWatch does, but its 3-tier pipeline forces upfront data classification decisions and DataPrime is logs-centric. Observe is the only platform where a single query in a single language can span logs, traces, and metrics — the definition of "centralized."

---

## 2. Competitor Strengths (Acknowledge Honestly)

### CloudWatch

1. **Zero-setup for AWS services.** EC2, Lambda, ECS, and other AWS services emit metrics and logs to CloudWatch automatically. No instrumentation required for basic infrastructure monitoring. For Syniverse's AWS workloads, this baseline coverage is already in place.

2. **Deep AWS integration.** Alarms can trigger Auto Scaling, Lambda remediation, and SNS notifications natively. No webhook configuration needed. CloudWatch is operationally embedded in AWS workflows.

3. **Application Signals (GA).** AWS's newer APM layer provides service-level dashboards with automatic trace-to-log correlation for supported runtimes. This partially addresses the cross-signal gap, though it requires Application Signals to be enabled and supported instrumentation.

4. **Tiered log pricing at scale.** The May 2025 pricing change introduced tiered vended log pricing (Lambda, VPC Flow Logs). At 50+ TB/month, log ingestion drops to $0.05/GB. Large-volume AWS-native workloads benefit significantly.

5. **CloudWatch Investigations (Dec 2025 GA).** AI-powered incident resolution with automated root cause analysis. Limited to 2 concurrent and 150 monthly investigations per region, but a genuine step toward AI-assisted triage.

### Coralogix

1. **TCO Optimizer is genuinely useful.** The ability to route data to different cost tiers (Frequent Search at $1.15/GB, Monitoring at $0.50/GB, Compliance at $0.14/GB) gives finance and platform teams direct control over spend. This is the feature that resonates with cost-conscious buyers.

2. **Customer-owned S3 storage.** Data lives in the customer's own S3 bucket. This addresses data sovereignty concerns and eliminates vendor lock-in for stored data. Syniverse's security team will appreciate this.

3. **In-stream analysis.** Coralogix can generate alerts and metrics from log data before it's indexed. This means certain alerting workflows work even on data routed to the lowest-cost Compliance tier.

4. **Unlimited users and hosts included.** No per-seat or per-host charges. For a company-wide rollout at Syniverse, this eliminates a common cost variable.

5. **24/7 real engineer support.** Coralogix claims 17-second median response time and 1-hour median resolution. Their support reputation is strong.

6. **Unit-based pricing flexibility.** The unit system lets teams shift between logs, metrics, and traces within their committed spend without renegotiating contracts.

---

## 3. Competitor Weaknesses (Supported by Evidence)

### CloudWatch: The Cost Spiral

**Evidence:** CloudWatch uses a "triple-charge" model for logs: $0.50/GB ingestion (first 10TB) + $0.03/GB/month storage + $0.005/GB for Logs Insights queries. Default log retention is "Never Expire," meaning storage costs compound silently every month. An enterprise deployment with 50+ microservices, VPC Flow Logs, and X-Ray typically costs ~$9,250/month — and log ingestion + storage accounts for over 80% of that bill.
*Source: [CloudBurn — CloudWatch Pricing 2026](https://cloudburn.io/blog/amazon-cloudwatch-pricing)*

**Talk track:** *"Let's look at your current CloudWatch bill. You're paying to ingest the data, then paying again to store it, then paying a third time every time you query it. And because the default retention is 'Never Expire,' your storage costs are growing every month whether you're using that data or not. How much has your CloudWatch spend grown in the last 12 months?"*

### CloudWatch: Fragmented Architecture

**Evidence:** CloudWatch answers "what is unhealthy." X-Ray answers "where in the request path it became unhealthy." They are "complementary, not interchangeable" — separate tools with separate UIs. Trace-to-log correlation is "not automatic in the default setup" and requires explicitly enabling Application Signals with compatible instrumentation. During incidents, "rebuilding your mental model as you jump between these views adds time to resolution."
*Source: [dev.to — AWS X-Ray vs CloudWatch](https://dev.to/signoz/aws-x-ray-vs-cloudwatch-explained-metrics-logs-traces-and-when-to-use-each-4jff)*

**Talk track:** *"When one of your multi-step flows breaks, what happens today? Your engineer opens CloudWatch Logs to see the error. Then switches to X-Ray to find the trace. Then goes back to CloudWatch Metrics to check if the downstream service was degraded. Three different tools, three different query interfaces, no automatic linking. That context-switching is exactly what adds 15-20 minutes to every triage cycle."*

### CloudWatch: No On-Prem Story

**Evidence:** CloudWatch is an AWS service that monitors AWS resources. It has no agent or capability for monitoring on-premises infrastructure. Syniverse has stated their on-prem footprint is larger than their cloud environment.

**Talk track:** *"Half the reason you need six tools today is because CloudWatch only works for AWS. Your on-prem environment — which you've told us is actually larger than your cloud footprint — needs its own entirely separate monitoring stack. That's not consolidation, that's perpetuating the problem."*

### CloudWatch: Custom Metric Dimension Explosion

**Evidence:** Each unique combination of metric name + namespace + dimensions creates a separate billable metric at $0.30/metric/month. A single metric name with a high-cardinality dimension like `userId` with 10,000 unique values = 10,000 billable metrics = $3,000/month. "This is where costs explode."
*Source: [CloudBurn — CloudWatch Pricing 2026](https://cloudburn.io/blog/amazon-cloudwatch-pricing)*

**Talk track:** *"Have you audited your custom metrics dimensions? Every unique combination of metric name plus dimensions is a separately billed metric. Teams publishing metrics with user IDs or request IDs as dimensions see bills go from hundreds to thousands overnight. One metric name with 10,000 unique values is $3,000 a month."*

### Coralogix: Three Tiers, Three Experiences

**Evidence:** Coralogix's TCO Optimizer routes data to three tiers: Frequent Search ($1.15/GB for full indexing), Monitoring ($0.50/GB for metrics/alerting only), and Compliance ($0.14/GB for archive only). The Compliance tier has limited query capabilities — data must be "sent back for further analysis" to be fully queryable. Frequent Search hot storage is "recommended 7 days" retention. This forces platform admins to make upfront decisions about which data is "important" and which isn't — before they know what they'll need during the next incident.
*Source: [coralogix.com/pricing](https://coralogix.com/pricing/)*

**Talk track:** *"The TCO Optimizer sounds great in a sales pitch — route less important data to cheaper tiers. But who decides what's less important? In practice, the log that matters most during an incident is the one nobody thought to put in Frequent Search. You end up either over-classifying everything as high-priority (which eliminates the cost savings) or under-classifying critical data (which means slow queries during outages). With Observe, there's no tiering decision to make — all data is equally queryable at any time."*

### Coralogix: DataPrime is Logs-First

**Evidence:** Coralogix's DataPrime query language was built for log analytics. While Coralogix supports metrics and traces, cross-signal investigation requires navigating between separate platform views. There is no single query that spans logs, traces, and metrics in one execution — each signal type has its own exploration interface.

**Talk track:** *"Coralogix does logs very well. But when you're troubleshooting a multi-step flow — which you've told us is a key requirement — you need to see the trace, the logs from each service, and the infrastructure metrics all in one view. With Coralogix, that's three separate views. With Observe, it's one OPAL query."*

### Coralogix: On-Prem Coverage Gaps

**Evidence:** Coralogix is a cloud-native SaaS platform. While it can ingest data from on-premises sources via OTel Collectors or Fluent Bit, it does not provide purpose-built on-prem infrastructure monitoring, host-level discovery, or multi-site management capabilities comparable to what Syniverse needs for their "larger on-prem footprint."

**Talk track:** *"You need a platform that treats your on-prem environment as a first-class citizen, not an afterthought. Can you walk us through how you'd get full visibility into your on-prem Kubernetes clusters and bare-metal hosts with the same depth you get for cloud resources?"*

---

## 4. Observe Strengths to Lead With

### 1. One Platform, One Language, One UI

Observe stores all telemetry — logs, metrics, traces, events — in a single Snowflake-backed data lake. OPAL (Observe Processing and Analytics Language) is the one query language that works across all signal types. Syniverse's engineers learn one tool, one language, and can investigate any signal from one interface. This directly addresses the "single, centralized observability platform" requirement.

### 2. OTel-Native — No Proprietary Lock-in

Observe accepts OTLP natively via gRPC and HTTP. No proprietary agents, no vendor-specific instrumentation libraries. Syniverse's stated strategy of adopting OpenTelemetry as a standard for metrics, logs, and traces aligns directly — deploy OTel Collectors across cloud and on-prem, point them at Observe, done. The Prometheus receiver in the OTel Collector can scrape existing app metrics as a bridge during migration.

### 3. 13-Month Hot Retention — No Tiering Decisions

All data is equally queryable for 13 months with no rehydration delays and no tiering decisions. Unlike Coralogix's 3-tier model that forces upfront classification, and unlike CloudWatch's "Never Expire" storage cost compounding, Observe's model is simple: ingest it, query it anytime for 13 months, done. ~10x compression into S3-based storage keeps the underlying economics efficient.

### 4. Knowledge Graph and AI SRE

Observe's Knowledge Graph automatically discovers entities (services, hosts, pods, containers) and maps relationships across all signal types. AI SRE uses this graph context to investigate incidents autonomously. This addresses Syniverse's requirements for "AI for correlation" and "proactive alerting" — not as bolt-on features, but as capabilities built on the unified data model.

### 5. Subscription Pricing — Cost Predictability

Observe's subscription model is based on committed ingest volume. No per-user fees (Syniverse wants company-wide rollout). No per-dashboard fees (they want consolidated dashboards). No per-alert fees (they want unified alarming). No per-query fees (unlike CloudWatch's triple-charge model). This directly addresses the cost predictability requirement and the 20-30% savings target.

### 6. Hybrid Cloud + On-Prem Coverage

Observe covers both environments through OTel Collector-based collection. The same platform, same UI, same query language works for Syniverse's AWS workloads (Kubernetes, EC2/ECS) and their larger on-prem footprint. This is the consolidation story that neither CloudWatch (AWS-only) nor Coralogix (cloud-native SaaS with limited on-prem depth) can match.

---

## 5. Kill Points Against CloudWatch & Coralogix

### Kill Point 1: "Six Tools Becomes One"

**When to use:** When Syniverse discusses their current tool sprawl and the operational burden of maintaining CloudWatch + X-Ray + Splunk + Graylog + EFK + Prometheus/Grafana + homegrown.

**Key message:** CloudWatch adds one more AWS-only silo. Coralogix replaces some tools but not all. Only Observe replaces the entire observability stack with a single platform.

**Evidence:** CloudWatch cannot monitor on-prem (eliminating it as a consolidation option). Coralogix is primarily cloud-native SaaS. Observe's OTel Collector-based architecture covers both cloud and on-prem with one data pipeline.

**Talk track:** *"You told us you're running six-plus tools and want one platform. CloudWatch literally cannot cover your on-prem environment — you'd still need at least two tools. Coralogix could cover more, but you'd still have separate views for different signals. With Observe, your OTel Collectors from both cloud and on-prem feed into one data lake, one query language, one UI. That's what consolidation actually means."*

### Kill Point 2: "The CloudWatch Bill Only Goes Up"

**When to use:** When cost discussions center on CloudWatch spend.

**Key message:** CloudWatch's triple-charge model (ingest + store + query) with default "Never Expire" retention creates costs that compound silently. Moving to another tool doesn't help if you're still paying CloudWatch for the data that flows through it.

**Evidence:** Enterprise CloudWatch deployments cost ~$9,250/month. The triple-charge model means the headline $0.50/GB is misleading — effective cost is $0.535/GB in month one, and storage costs accrue every subsequent month. Custom metric dimension explosion can turn one metric into thousands of billable metrics.
*Source: [CloudBurn — CloudWatch Pricing 2026](https://cloudburn.io/blog/amazon-cloudwatch-pricing)*

**Talk track:** *"Your CloudWatch bill is 'skyrocketing' because the pricing model is designed to grow. You pay to put data in, pay to keep it, and pay every time you look at it. The default retention is 'Never Expire,' so storage costs grow every month even if nobody queries that data. And custom metrics? Every unique dimension combination is separately billed. With Observe, you pay for committed ingest volume — one price, predictable, no hidden charges for querying your own data."*

### Kill Point 3: "Coralogix Makes You Choose Before You Know"

**When to use:** When Coralogix leads with their TCO Optimizer as a cost advantage.

**Key message:** The TCO Optimizer forces teams to classify data into tiers at ingest time. The data that matters most during an incident is often the data nobody thought to prioritize. This creates a false economy — you save on storage but lose on mean time to resolution.

**Evidence:** Coralogix Compliance tier ($0.14/GB) requires data to be "sent back for further analysis" to be fully queryable. Frequent Search is recommended at 7-day retention. Admins must decide upfront what's "important."
*Source: [coralogix.com/pricing](https://coralogix.com/pricing/)*

**Talk track:** *"Coralogix will show you their TCO Optimizer and it looks great — route 'unimportant' data to the cheap tier. But here's the question: who decides what's unimportant? That DNS timeout log from your Compliance tier that nobody thought mattered? That's the log you'll need at 2am when a multi-step flow is failing. With Observe, all data is equally queryable for 13 months. No tiering decisions. No 'send it back for analysis' delays. The data is just there when you need it."*

### Kill Point 4: "One Query, All Signals"

**When to use:** When demonstrating multi-step flow troubleshooting — Syniverse's stated key requirement.

**Key message:** CloudWatch requires three tools with three query approaches to investigate a cross-service issue. Coralogix requires navigating between separate views per signal type. Observe uses one OPAL query across all signals.

**Evidence:** CloudWatch: "CloudWatch answers 'what is unhealthy.' X-Ray answers 'where in the request path.' They are complementary, not interchangeable." Trace-to-log correlation is "not automatic."
*Source: [dev.to — AWS X-Ray vs CloudWatch](https://dev.to/signoz/aws-x-ray-vs-cloudwatch-explained-metrics-logs-traces-and-when-to-use-each-4jff)*

**Talk track:** *"Let's run your actual multi-step flow scenario side by side. In CloudWatch, you open Logs Insights for the error, switch to X-Ray for the trace, switch back to CloudWatch Metrics for the dashboard — three tools, three query syntaxes, no automatic linking. In Observe, you write one OPAL query that pulls the trace, the associated logs from every service in the flow, and the infrastructure metrics. One query, one result, one screen. During a bake-off, let's time both approaches and measure."*

### Kill Point 5: "OTel Standard, Not OTel Fork"

**When to use:** When Syniverse discusses their OpenTelemetry adoption strategy.

**Key message:** CloudWatch uses ADOT — Amazon's fork of OpenTelemetry with AWS-specific extensions. This creates subtle vendor lock-in. Observe accepts standard OTLP with no modifications.

**Evidence:** ADOT (AWS Distro for OpenTelemetry) adds AWS-specific exporters and configuration that aren't part of upstream OTel. Observe's OTLP endpoint accepts standard OTel data via gRPC and HTTP with no proprietary extensions required.

**Talk track:** *"You've made a smart strategic decision to standardize on OpenTelemetry. Make sure that standardization is actually standard. ADOT is Amazon's distribution of OTel — it adds AWS-specific pieces that create a soft lock-in. Coralogix supports OTel but their architecture is optimized for their native pipelines. Observe is OTLP-native — your standard OTel Collectors point at our OTLP endpoint and that's it. No fork, no proprietary extensions, no 'AWS Distro' in the middle."*

---

## 6. Objection Handling

### "CloudWatch is free for basic monitoring — why pay for Observe?"

**Response:** *"CloudWatch's 'free' basic monitoring covers 5-minute metrics from AWS services. The moment you need application logs, custom metrics, traces, or queries, you're paying — and paying three times for logs. Your current bill already proves that 'free basic monitoring' doesn't mean low cost. The question isn't whether to pay for observability — it's whether you pay a predictable subscription or an unpredictable consumption bill that grows every month."*

### "Coralogix is cheaper per GB than Observe"

**Response:** *"Per-GB comparisons are misleading when the architectures are different. Coralogix's $0.42/GB for logs sounds low, but that's for Frequent Search tier at $1.15/GB — the cheap rate is for Compliance tier data you can't fully query. Then you add S3 storage costs in your own bucket. Then you factor in the operational cost of managing tiering decisions across your org. Observe's subscription pricing includes all query, storage, and retention costs for 13 months. Let's model your actual data volume through both platforms and compare the total cost, not just the headline rate."*

### "We're already invested in AWS — shouldn't we stay with CloudWatch?"

**Response:** *"Staying with AWS for infrastructure is smart. Staying with CloudWatch for observability means accepting that half your environment — the on-prem half, which is actually your larger footprint — will never be covered. You'll always need additional tools. Observe doesn't replace AWS — it monitors your AWS environment alongside everything else. Your OTel Collectors in ECS and on-prem both send to the same Observe endpoint. One platform for everything, and you keep running on AWS."*

### "Coralogix's TCO Optimizer will give us the cost control we need"

**Response:** *"The TCO Optimizer gives you cost control by asking you to make data classification decisions you can't fully predict. It works well for data you know is low-value — audit logs you'll never query, compliance records you archive for legal. But for operational data where you can't predict what you'll need during an incident? You either over-classify to Frequent Search (losing the cost savings) or under-classify to Monitoring/Compliance (losing query speed when it matters most). Observe eliminates this trade-off entirely — all data, fully queryable, 13 months, one price."*

### "We need Splunk for security — can Observe replace that too?"

**Response:** *"Observe is an observability platform, not a SIEM. We'd recommend keeping Splunk for your security use case today. However, having all your observability signals in Observe means your security team can correlate with operational data when needed — and the same OTel Collectors that feed Observe can also forward security-relevant logs to Splunk. You standardize collection once and route to the right destination."*

---

## 7. POC / Bake-Off Strategy

### Success Criteria (Designed for Competitive Advantage)

| # | Criterion (Neutral Language) | What It Really Tests |
|---|---|---|
| 1 | Ingest logs, metrics, and traces from both AWS (Kubernetes, EC2/ECS) and on-prem environments into a single platform with no separate tools or UIs required. | CloudWatch cannot do on-prem at all. Coralogix on-prem coverage is limited. |
| 2 | Demonstrate a multi-step flow investigation: starting from an error, navigate to the associated trace, then to logs from each downstream service, then to infrastructure metrics — all in a single UI with one query language. | CloudWatch requires 3 separate tools. Coralogix requires navigating between views. Observe does this in one OPAL query. |
| 3 | Execute a single query that filters across logs, traces, and metrics for a specific business field (e.g., transaction ID). No query language switching. | Tests true cross-signal correlation. CloudWatch cannot do this. |
| 4 | Show all data from 6+ months ago is immediately queryable with no rehydration, no tier promotion, and no performance degradation compared to recent data. | CloudWatch's old data has storage cost overhead. Coralogix Compliance tier requires "send back for analysis." Observe 13-month hot retention. |
| 5 | Provide a cost monitoring dashboard showing daily ingest volume, current spend, and projected monthly cost — accessible to platform admins without vendor support involvement. | Tests self-service cost visibility. Syniverse explicitly requested this. |
| 6 | Demonstrate PII detection and filtering at ingest time, with audit logging of what was filtered. | Syniverse explicitly raised PII/security concerns. Tests data governance capabilities. |
| 7 | Ingest data via standard OpenTelemetry Protocol (OTLP) with no proprietary agents, no vendor-specific SDK extensions, and no forked distributions required. | Tests OTel purity. ADOT is a fork. Observe is OTLP-native. |
| 8 | Provide a unified alarm and logging interface with suppression controls to reduce alert noise across the entire environment. | Syniverse explicitly requested "single UI for alarms and logging" with "suppression of unnecessary logging." |

### Suggested Bake-Off Workflow

**Phase 1: Ingest (Day 1-3)**
- Deploy OTel Collectors to a representative sample: 2-3 AWS services (K8s + ECS) and 1-2 on-prem hosts.
- Each vendor configures their platform to ingest from the same collectors.
- Measure: Time to first data visible in UI. Configuration complexity. Any proprietary components required.

**Phase 2: Investigate (Day 4-7)**
- Inject a known multi-step flow failure.
- Each vendor's SE demonstrates the investigation workflow: error → trace → logs → metrics.
- Measure: Number of tools/views/query languages required. Time to root cause. Number of clicks from error to resolution.

**Phase 3: Operate (Day 8-14)**
- Configure alerts, dashboards, and PII filtering.
- Generate a cost monitoring view.
- Simulate a 6-month-old data query.
- Measure: Dashboard creation time. Alert configuration complexity. Historical data query performance. Cost transparency.

**Phase 4: Evaluate (Day 15)**
- Score each criterion 1-5.
- Total cost comparison using actual ingested volumes from the POC period.
- Team feedback survey on investigation ergonomics.

---

## 8. Syniverse-Specific Positioning Summary

| Syniverse Requirement | CloudWatch | Coralogix | Observe |
|---|---|---|---|
| Single centralized platform | No (separate services, AWS-only) | Partial (SaaS, limited on-prem) | Yes (unified data lake, cloud + on-prem) |
| 20-30% cost savings vs. CloudWatch | N/A (is the cost problem) | Possible (TCO Optimizer) | Yes (subscription vs. triple-charge) |
| Multi-step flow correlation | 3 tools required | Separate views per signal | One OPAL query |
| On-prem coverage | None | Limited | Full via OTel Collectors |
| OTel standardization | ADOT fork | Supported | Native OTLP, no fork |
| PII filtering | Data Protection ($0.12/GB scan charge) | Available | Available |
| Cost monitoring dashboard | AWS Cost Explorer (separate tool) | Available | Available |
| AI correlation | CloudWatch Investigations (limited) | Olly AI (newer) | AI SRE with Knowledge Graph |
| Unified alarm + logging UI | No (separate sections) | Closer | Yes (OPAL + alerts in one UI) |
| Configurable retention | Per log group (storage costs compound) | 3-tier + S3 infinite | 13-month hot, all-inclusive |

---

*This document is for internal use only. Do not share with Syniverse or any external party. Customer-facing materials should use neutral language — e.g., "platforms with separate backends" rather than "Kill Point."*
