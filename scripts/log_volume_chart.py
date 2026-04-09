import os
import requests
import json
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from datetime import datetime, timedelta, timezone

CUSTOMER_ID = os.environ.get("OBSERVE_CUSTOMER_ID", "193729085807")
API_TOKEN = os.environ.get("OBSERVE_API_TOKEN", "")
DATASET_ID = "42133546"

base_url = f"https://{CUSTOMER_ID}.observeinc.com"
headers = {
    "Authorization": f"Bearer {CUSTOMER_ID} {API_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/x-ndjson",
}

payload = {
    "query": {
        "stages": [
            {
                "input": [
                    {
                        "inputName": "logs",
                        "datasetId": DATASET_ID,
                    }
                ],
                "stageID": "main",
                "pipeline": "timechart 1m, log_count:count()",
            }
        ],
    }
}

print("Querying Observe export API...")
resp = requests.post(
    f"{base_url}/v1/meta/export/query",
    headers=headers,
    json=payload,
    params={"interval": "1h"},
    timeout=60,
)

print(f"Status: {resp.status_code}")
if resp.status_code not in (200, 206):
    print(resp.text[:2000])
    exit(1)

lines = resp.text.strip().split("\n")
print(f"Got {len(lines)} data points")

if lines:
    sample = json.loads(lines[0])
    print(f"Sample keys: {list(sample.keys())}")
    print(f"Sample: {json.dumps(sample, indent=2)}")

timestamps = []
counts = []
for line in lines:
    row = json.loads(line)
    ts_val = row.get("_c_valid_from")
    count_val = row.get("log_count", 0)
    if ts_val:
        ts_num = int(ts_val)
        ts = datetime.fromtimestamp(ts_num / 1e9, tz=timezone.utc)
        timestamps.append(ts)
        counts.append(int(count_val))

if not timestamps:
    print("No data parsed.")
    exit(1)

paired = sorted(zip(timestamps, counts))
timestamps = [p[0] for p in paired]
counts = [p[1] for p in paired]

print(f"Parsed {len(timestamps)} points, range: {timestamps[0]} to {timestamps[-1]}")
print(f"Total: {sum(counts):,}, Avg: {sum(counts)/len(counts):,.0f}/min, Max: {max(counts):,}/min")

fig, ax = plt.subplots(figsize=(14, 5))

ax.fill_between(timestamps, counts, alpha=0.15, color='#5B8FF9')
ax.plot(timestamps, counts, color='#5B8FF9', linewidth=1.5)

ax.set_facecolor('#FAFAFA')
fig.patch.set_facecolor('#FFFFFF')
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.spines['left'].set_color('#E0E0E0')
ax.spines['bottom'].set_color('#E0E0E0')
ax.tick_params(colors='#666666', labelsize=9)
ax.grid(axis='y', alpha=0.3, color='#CCCCCC')

ax.xaxis.set_major_formatter(mdates.DateFormatter('%H:%M', tz=timezone.utc))
ax.xaxis.set_major_locator(mdates.MinuteLocator(interval=10))
plt.xticks(rotation=0)

ax.set_xlabel('Time (UTC)', fontsize=10, color='#666666')
ax.set_ylabel('Log Count', fontsize=10, color='#666666')
ax.set_title('Kubernetes Log Volume — Past 60 Minutes', fontsize=13, fontweight='bold', color='#333333', pad=15)

total = sum(counts)
avg = total / len(counts) if counts else 0
mx = max(counts) if counts else 0
stats_text = f'Total: {total:,}  |  Avg: {avg:,.0f}/min  |  Max: {mx:,}/min'
ax.text(0.5, -0.15, stats_text, transform=ax.transAxes, ha='center', fontsize=9, color='#888888')

plt.tight_layout()
out_path = "/Users/lquigley/observe-demo-app/log_volume_chart.png"
plt.savefig(out_path, dpi=150, bbox_inches='tight')
print(f"\nChart saved to {out_path}")
