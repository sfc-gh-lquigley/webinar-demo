# Competitive Brief: Observe vs. Splunk for Pfizer

> **Classification:** Internal Use Only
> **Last Updated:** March 26, 2026

---

## Executive Summary

Splunk, now a Cisco subsidiary ($28B acquisition completed March 2024), is the incumbent observability and log management platform at Pfizer. Splunk's portfolio has expanded through acquisitions (SignalFx, Omnition, AppDynamics via Cisco) into a multi-product suite that spans logs, metrics, traces, and SIEM — but each signal type lives in a separate backend with a separate query language.

Pfizer is evaluating Observe as a potential replacement, with specific requirements around **Mulesoft API monitoring** (event UUID correlation across the request lifecycle), **cost-effective log retention**, **dashboarding parity**, and **sensitive data governance**. Observe's unified data lake architecture — single backend, single query language (OPAL), Snowflake-backed storage with 13-month hot retention — directly addresses Pfizer's core frustrations with Splunk's fragmented tooling and ingest-based cost model.

**The contest:** A multi-product, multi-query-language suite assembled through acquisition (Splunk) versus a purpose-built unified observability platform (Observe).

---

## 1. Solution Profiles

### Splunk (Cisco)

| Dimension | Detail |
|---|---|
| **Founded** | 2003; acquired by Cisco for $28B (completed Mar 2024) |
| **Core Products** | Splunk Enterprise/Cloud (logs), Splunk Observability Cloud (metrics/traces, ex-SignalFx), ITSI, AppDynamics, Enterprise Security (SIEM) |
| **Architecture** | Separate backends per product: Splunk indexers (logs), SignalFx backend (metrics), APM backend (traces), AppDynamics (APM) |
| **Query Languages** | SPL (logs), SPL2 (emerging), SignalFlow (metrics), separate APM query interfaces |
| **Storage** | Hot/warm (local SSD) → cold (remote S3 via SmartStore) → frozen (archive, requires rehydration) |
| **Pricing** | Ingest-based (per GB/day) or Workload (SVCs). New pricing pilot announced Sep 2025, not yet GA |
| **OTel Support** | Splunk Distribution of OTel Collector; OTLP ingestion into Observability Cloud |

### Observe (Snowflake)

| Dimension | Detail |
|---|---|
| **Founded** | 2017; acquired by Snowflake (2024) |
| **Core Product** | Unified observability platform — logs, metrics, traces, events in a single data lake |
| **Architecture** | Single Snowflake-backed data store for all signal types |
| **Query Language** | OPAL (Observe Processing and Analytics Language) — one language for all signals |
| **Storage** | S3-backed with ~10x compression; 13-month default hot retention, no rehydration required |
| **Pricing** | Subscription-based on committed ingest volume. No per-user, per-dashboard, per-alert fees |
| **OTel Support** | Native OTLP ingestion (gRPC/HTTP); no proprietary agents required |

### Key Architectural Contrast

| Signal | Splunk Backend | Splunk Query Language | Observe Backend | Observe Query Language |
|---|---|---|---|---|
| Logs | Splunk Indexers | SPL | Unified Data Lake | OPAL |
| Metrics | SignalFx (Obs Cloud) | SignalFlow | Unified Data Lake | OPAL |
| Traces | APM (Obs Cloud) | APM UI queries | Unified Data Lake | OPAL |
| Dashboards | Dashboard Studio (logs) + Obs Cloud dashboards (metrics) | Mixed | Single dashboard system | OPAL |
| Alerts | Splunk Alerts (logs) + Detectors (Obs Cloud) | Mixed | Unified alerting | OPAL |

**What this means for Pfizer:** Today, correlating a Mulesoft API request by event UUID requires Pfizer engineers to query logs in Splunk Cloud (SPL), then context-switch to Splunk Observability Cloud for traces and metrics (SignalFlow/APM UI). In Observe, the same investigation is a single OPAL query against one data store — no tool switching, no query language switching, no copy-pasting UUIDs between products.

---

## 2. Competitor Strengths (Acknowledge Honestly)

These are genuine Splunk advantages that should not be dismissed:

1. **SPL Maturity and Ecosystem** — SPL is one of the most powerful log query languages in the industry. Pfizer's team likely has deep SPL expertise, saved searches, and institutional knowledge. This represents real switching cost.

2. **Splunkbase App Ecosystem** — Over 2,000+ apps and add-ons on Splunkbase, including Mulesoft-specific Technology Add-ons (TAs). Pfizer may depend on specific TAs for data ingestion and parsing.

3. **Enterprise Security (SIEM)** — Splunk ES is a Gartner Leader in SIEM. If Pfizer uses Splunk for both observability and security, migrating observability alone creates a split-brain scenario. This is a valid concern.

4. **Cisco Distribution and Support** — Post-acquisition, Splunk benefits from Cisco's global enterprise support infrastructure, TAC, and bundled purchasing agreements. Pfizer may have existing Cisco ELAs that include Splunk.

5. **Federated Search (Emerging)** — .conf25 (Sep 2025) announced Splunk Federated Search for Snowflake, allowing SPL queries against Snowflake data lakes without ingestion. If executed well, this could address some ingest cost complaints. However, this is **announced, not GA** — and federation adds query latency compared to native storage.

6. **Dashboard Studio** — Splunk's Dashboard Studio provides rich visualization capabilities with XML-based customization. Pfizer has provided existing Splunk dashboard examples that represent a parity baseline.

---

## 3. Competitor Weaknesses (Supported by Evidence)

### 3.1 Fragmented Architecture — Multiple Products, Multiple Query Languages

**Evidence:** Splunk's own documentation describes its portfolio as separate products requiring integration: Splunk Enterprise/Cloud for logs (SPL), Splunk Observability Cloud for metrics and traces (SignalFlow, APM UI), AppDynamics for application monitoring, and ITSI for IT service management. Log Observer Connect bridges logs into the Observability Cloud UI, but as a **read-only connection** — not a unified data store.

**Source:** [Splunk Observability Cloud and the Splunk platform](https://help.splunk.com/en/splunk-observability-cloud/administer/splunk-platform-users/splunk-observability-cloud-and-the-splunk-platform)

**Talk track:** *"When your Mulesoft team needs to trace an API request from ingestion through processing to response, they start in Splunk Cloud with an SPL query to find logs, then switch to Observability Cloud's APM UI for traces, then look at Infrastructure Monitoring for host metrics — that's three products, two query languages, and zero ability to write a single query across all three. In Observe, it's one OPAL query."*

### 3.2 Ingest-Based Pricing Creates a Data Tax

**Evidence:** Splunk's ingest pricing charges per GB/day ingested. IDC analyst Stephen Elliot stated at .conf25: *"Ingest costs have been the sticking point for Splunk customers."* Splunk's own leadership acknowledged this by announcing a new pricing pilot (Sep 2025) that separates ingestion from analytics — but the pilot is **not yet generally available**.

**Source:** [TechTarget — Under Cisco, Splunk AI roadmap tees up pricing overhaul](https://www.techtarget.com/searchitoperations/news/366630519/Under-Cisco-Splunk-AI-roadmap-tees-up-pricing-overhaul)

**Talk track:** *"Every additional Mulesoft environment Pfizer onboards increases your Splunk bill linearly. That creates a perverse incentive to not monitor things — the opposite of what observability should encourage. Observe's subscription model means you can scale monitoring without per-GB penalties."*

### 3.3 Frozen Tier Retention Requires Rehydration

**Evidence:** Splunk's SmartStore architecture tiers data from hot/warm → cold → frozen. Frozen data is archived and **not searchable** without rehydration — a process that requires moving data back to indexers, consuming time and compute resources.

**Source:** [Splunk SmartStore documentation](https://help.splunk.com/en/splunk-enterprise/administer/manage-indexers-and-indexer-clusters/10.2/implement-smartstore-to-reduce-local-storage-requirements/about-smartstore)

**Talk track:** *"Pfizer needs historical analysis across months of Mulesoft API data. In Splunk, data older than your hot/warm retention is either expensive to keep searchable or frozen and unsearchable without rehydration. In Observe, 13 months of data is hot by default — no rehydration, no waiting, no extra cost."*

### 3.4 Cisco Acquisition — Product Consolidation Uncertainty

**Evidence:** Cisco is mid-integration of overlapping products: AppDynamics (Cisco's pre-existing APM), Splunk Observability Cloud (SignalFx-based), and Splunk ITSI all serve overlapping use cases. The "Cisco Data Fabric" announced at .conf25 is described as a **multi-year journey**, not a current capability. Splunk Enterprise Security 8.2 merged previously separate SOAR, TIM, and UEBA tools — indicating ongoing consolidation.

**Source:** [TechTarget — Cisco-Splunk strategy shift unveiled with Data Fabric](https://www.techtarget.com/searchitoperations/news/366630300/Cisco-Splunk-strategy-shift-unveiled-with-Data-Fabric)

**Talk track:** *"Cisco is consolidating four overlapping products into a unified platform — but that's a multi-year roadmap, not today's reality. Pfizer needs to ask: which product is the long-term winner? AppDynamics or Splunk Obs Cloud? ITSI or the new Data Fabric? Observe doesn't have this problem — one product, one architecture, no consolidation risk."*

### 3.5 Cross-Signal Correlation is UI-Level, Not Query-Level

**Evidence:** Splunk Observability Cloud offers UI-based correlations (click from trace to logs via Log Observer Connect), but there is no single query that can span logs, metrics, and traces. Engineers cannot write a compound query that filters traces by duration, joins with associated logs, and correlates to infrastructure metrics — this requires multiple manual steps across separate UIs.

**Talk track:** *"Splunk offers what the industry calls 'correlation theater' — you can click from a trace to associated logs in the UI, but you can't write a query that says 'show me all logs from requests where the Mulesoft API response time exceeded 5 seconds and the host CPU was above 90%.' In Observe, that's a single OPAL query with correlation tags."*

---

## 4. Observe Strengths to Lead With

### 4.1 Unified Data Lake — One Backend, One Query Language

All telemetry — logs, metrics, traces, events — is stored in a single Snowflake-backed data store and queried with OPAL. For Pfizer's Mulesoft use case, this means a single investigation flow from API request to log entry to infrastructure metric.

**Documentation:** [Observe Architecture](https://docs.observeinc.com)

### 4.2 Correlation Tags — One-Click Cross-Signal Navigation

Correlation tags (e.g., `event_uuid`, `trace_id`, `host`) are configured once by an admin and enable pivot-menu navigation between any dataset. For Pfizer: configure `event_uuid` as a correlation tag, and every log, trace, and metric containing that UUID becomes instantly navigable via right-click.

**Setup requirement:** One-time admin configuration per correlation field.

**Documentation:** [Correlation Tags](https://docs.observeinc.com/docs/correlation-tags)

### 4.3 13-Month Hot Retention — No Rehydration, No Surprise Costs

Observe stores all data in S3 with ~10x compression and provides 13 months of searchable hot retention by default. No tiering decisions, no rehydration workflows, no frozen archives. Pfizer's historical analysis requirements are met natively.

**Setup requirement:** Zero-config (default retention).

### 4.4 Subscription Pricing — No Data Tax

Observe's subscription model is based on committed ingest volume with no per-user, per-dashboard, or per-alert fees. As Pfizer scales Mulesoft monitoring, costs are predictable — not linearly tied to each additional GB.

### 4.5 OPAL — Purpose-Built for Cross-Signal Investigation

OPAL supports sub-queries, joins across datasets, and filtering across signal types in a single query. For the Mulesoft use case, Pfizer can write a single OPAL query that:
- Filters traces by event UUID
- Joins associated log entries
- Correlates infrastructure metrics from the same time window
- Displays results in a single view

### 4.6 Knowledge Graph and AI SRE

Observe's Knowledge Graph automatically discovers entities (services, hosts, pods) and maps relationships across all signal types. AI SRE performs autonomous incident investigation across the Knowledge Graph, accelerating root cause analysis for Mulesoft API failures.

**Documentation:** [AI SRE](https://docs.observeinc.com/docs/ai-sre)

---

## 5. Kill Points Against Splunk

### Kill Point 1: "Two Products, Two Languages, Zero Unified Queries"

**When to use:** When the Pfizer team describes their current Mulesoft troubleshooting workflow — jumping between Splunk Cloud and Splunk Observability Cloud.

**Key message:** Splunk requires engineers to use different products and query languages for logs vs. metrics/traces. There is no single query that spans all signals.

**Evidence:** Splunk Enterprise/Cloud uses SPL for logs. Splunk Observability Cloud uses SignalFlow for metrics and a separate APM UI for traces. Log Observer Connect provides read-only log access in Obs Cloud but does not enable cross-signal queries. ([Splunk docs](https://help.splunk.com/en/splunk-observability-cloud/administer/splunk-platform-users/splunk-observability-cloud-and-the-splunk-platform))

**Talk track:** *"Let me show you a side-by-side. In Splunk, trace your Mulesoft API request by event UUID: Step 1 — SPL query in Splunk Cloud to find logs. Step 2 — Copy the trace ID. Step 3 — Switch to Splunk Observability Cloud APM. Step 4 — Paste the trace ID. Step 5 — Switch to Infrastructure Monitoring for host metrics. In Observe: Step 1 — OPAL query with event UUID. Done. One product, one query, one result."*

### Kill Point 2: "The Ingest Tax"

**When to use:** When Pfizer expresses concern about monitoring costs, or when discussing scaling Mulesoft environments.

**Key message:** Splunk's pricing model punishes data growth. Every new Mulesoft environment, every increase in log verbosity, every additional API endpoint increases the bill.

**Evidence:** Splunk ingest pricing ranges $1,800–$18,000/yr for 1–10 GB/day. At enterprise scale, costs escalate rapidly. Splunk's own leadership acknowledged this is "the sticking point" and is piloting new pricing — but it's not available yet. ([TechTarget, Sep 2025](https://www.techtarget.com/searchitoperations/news/366630519/Under-Cisco-Splunk-AI-roadmap-tees-up-pricing-overhaul))

**Talk track:** *"Ask Splunk: 'If we double our Mulesoft log volume next year, what happens to our bill?' Then ask us the same question. The difference in answers tells you everything about the pricing models."*

### Kill Point 3: "Frozen Data, Frozen Investigations"

**When to use:** When Pfizer discusses historical analysis requirements or compliance-driven data retention.

**Key message:** Splunk's frozen tier is not searchable. Historical investigations require rehydration — a manual, time-consuming process that adds cost and delays root cause analysis.

**Evidence:** Splunk SmartStore documentation describes frozen data as archived and requiring rehydration to search. ([Splunk docs](https://help.splunk.com/en/splunk-enterprise/administer/manage-indexers-and-indexer-clusters/10.2/implement-smartstore-to-reduce-local-storage-requirements/about-smartstore))

**Talk track:** *"Imagine it's 3 AM, and you need to investigate a Mulesoft API pattern that started degrading four months ago. In Splunk, that data might be frozen — you'd need to rehydrate it before you can even start searching. In Observe, it's hot. You query it instantly, the same way you query today's data."*

### Kill Point 4: "Four Products Looking for a Platform"

**When to use:** When the Pfizer team asks about Splunk's roadmap or long-term platform strategy.

**Key message:** Cisco is consolidating AppDynamics, Splunk Observability Cloud, ITSI, and Splunk Enterprise into a unified "Data Fabric" — but this is a multi-year roadmap, not a current product. Pfizer is betting on a consolidation that hasn't happened yet.

**Evidence:** Cisco's Data Fabric was announced at .conf25 (Sep 2025) and described as a multi-year journey. Meanwhile, AppDynamics and Splunk Observability Cloud still overlap significantly. ([TechTarget](https://www.techtarget.com/searchitoperations/news/366630300/Cisco-Splunk-strategy-shift-unveiled-with-Data-Fabric))

**Talk track:** *"Ask Splunk: 'Should we invest in AppDynamics or Splunk Observability Cloud for APM? Which one is the future?' If they can't give you a clear answer, that tells you the consolidation isn't done. Observe is one product today."*

### Kill Point 5: "Mulesoft UUID Correlation — The POC Litmus Test"

**When to use:** During POC scoping discussions.

**Key message:** Ask both vendors to trace a single Mulesoft API request by event UUID from ingestion through processing to response, correlating logs, traces, and metrics in a single query. This is Pfizer's actual workflow — make it the test.

**Talk track:** *"Here's the POC criterion that matters most: give both vendors the same event UUID and ask them to show you every log, trace, and metric associated with that request — in a single query, in a single UI. Whoever can do that without switching tools wins."*

---

## 6. Objection Handling

### Objection 1: "Our team already knows SPL — the switching cost is too high."

**Response:** *"That's a legitimate concern, and SPL expertise is valuable. Two points: First, OPAL's syntax is designed to be approachable for engineers with SPL experience — it uses similar piping concepts. Second, consider the hidden switching cost you're already paying: your team switches between SPL and SignalFlow every time they investigate an issue that crosses logs and metrics. With Observe, they learn one language that covers everything. The net switching cost may actually be lower."*

### Objection 2: "Splunk is a Gartner Leader — it's the safe choice."

**Response:** *"Splunk's Gartner leadership is primarily in SIEM (Enterprise Security), not observability. For observability specifically, the market has shifted toward unified platforms. More importantly, the Splunk that was evaluated for those rankings is pre-Cisco — the product is actively being restructured. 'Safe' means different things when the vendor is mid-acquisition integration."*

### Objection 3: "We have a Cisco ELA that includes Splunk — it's essentially free."

**Response:** *"'Free' in licensing doesn't mean free in total cost. Consider: the engineering time spent context-switching between Splunk products, the operational cost of managing SmartStore tiers, the overage risk on ingest pricing, and the opportunity cost of slower root cause analysis. The question isn't whether Splunk's license is free — it's whether Splunk's total cost of investigation is lower than Observe's."*

### Objection 4: "Splunk's new Data Fabric will solve the fragmentation problem."

**Response:** *"Cisco described Data Fabric as a multi-year journey at .conf25 in September 2025. Pfizer's Mulesoft monitoring needs exist today. You can wait multiple years for Splunk to build what Observe already has — or you can evaluate what's available now. We'd encourage you to ask Splunk for a specific GA date on Data Fabric with unified cross-signal querying."*

### Objection 5: "We use Splunkbase TAs for Mulesoft ingestion — does Observe support that?"

**Response:** *"Observe ingests data via standard protocols — OTLP, syslog, HTTP, and Observe's own collection agents. For Mulesoft, the data collection mechanism (Anypoint Platform logs and metrics) can be directed to Observe via standard log forwarding or OTel Collector. The difference: instead of relying on a community-maintained TA that may break on Splunk version upgrades, you're using standard protocols that are vendor-agnostic."*

---

## 7. POC / Bake-Off Strategy

### Success Criteria Mapped to Competitive Angles

| # | Criterion (Neutral Language) | What It Really Tests |
|---|---|---|
| 1 | Correlate a Mulesoft API request by event UUID from ingestion → processing → response in a **single query** | One query language + one backend vs. multi-product, multi-language |
| 2 | Navigate from a Mulesoft trace span to associated log entries in **one click** via the UI — and the reverse path (log → trace) | Native bi-directional correlation vs. Log Observer Connect (read-only, one direction) |
| 3 | Build a Mulesoft API dashboard showing error rates, latency percentiles, throughput, and associated log context — **all from one UI** | Unified dashboarding vs. separate Dashboard Studio + Obs Cloud dashboards |
| 4 | Search 6+ months of historical Mulesoft logs without manual rehydration, additional cost, or latency penalty | 13-month hot retention vs. SmartStore frozen tier rehydration |
| 5 | Filter sensitive data fields (e.g., PII, PHI) at ingest and demonstrate an audit trail of exclusions | Data governance controls comparison |
| 6 | Alert on Mulesoft API degradation (e.g., p99 latency spike) with automatic correlation to infrastructure metrics and associated logs | Unified alerting vs. separate alert systems (Splunk Alerts + Obs Cloud Detectors) |
| 7 | Provide API access to programmatically create dashboards, alerts, and manage data configuration | API completeness and automation capability |
| 8 | Demonstrate AI-assisted root cause analysis for a Mulesoft API failure that spans multiple services | AI SRE (Observe) vs. Splunk AI Assistant scope and cross-signal capability |

### Suggested Bake-Off Workflow

1. **Provide identical data:** Both vendors receive the same Mulesoft log and trace data set covering a known incident.
2. **Timed investigation:** Give each vendor 30 minutes to identify the root cause of a Mulesoft API failure using event UUID correlation. Measure: time to root cause, number of tool switches, number of query languages used.
3. **Dashboard parity:** Provide Pfizer's existing Splunk dashboard examples. Ask each vendor to replicate the dashboards within their platform. Measure: fidelity, time to build, ease of modification.
4. **Scale test:** Increase Mulesoft log volume by 3x. Measure: query performance impact, cost impact, any data loss or throttling.
5. **Historical query:** Query data from 4+ months ago for a specific event UUID pattern. Measure: query latency, additional steps required (rehydration?), cost.

---

*This document is for internal Observe/Snowflake use only. Do not share with Pfizer or any external party. All competitor claims cite primary sources and should be re-verified before each customer interaction.*
