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
}

now = datetime.now(timezone.utc)
start = now - timedelta(minutes=60)

query = {
    "query": {
        "stages": [
            {
                "input": [{"datasetId": DATASET_ID, "inputRole": "Data"}],
                "stageID": "main",
                "pipeline": "timechart 1m, count() as log_count"
            }
        ],
        "outputStage": "main",
    },
    "startTime": start.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "endTime": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
}

print("Querying Observe API...")
resp = requests.post(
    f"{base_url}/v1/meta",
    headers=headers,
    json={"query": json.dumps(query)},
    timeout=30,
)

if resp.status_code != 200:
    print(f"Non-200 from /v1/meta: {resp.status_code}")
    print(resp.text[:2000])

    print("\nTrying GraphQL endpoint instead...")
    gql_query = """
    query ExportQuery($input: ExportInput!) {
      export(input: $input) {
        dataset {
          id
          name
        }
        data
      }
    }
    """

    gql_payload = {
        "query": gql_query,
        "variables": {
            "input": {
                "stageList": {
                    "stages": [
                        {
                            "input": [
                                {
                                    "datasetId": DATASET_ID,
                                    "inputRole": "Data",
                                    "inputName": "Kubernetes Logs",
                                }
                            ],
                            "stageId": "main",
                            "pipeline": "timechart 1m, count() as log_count",
                        }
                    ],
                    "outputStage": "main",
                },
                "startTime": start.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "endTime": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            }
        },
    }

    resp2 = requests.post(
        f"{base_url}/v1/graphql",
        headers=headers,
        json=gql_payload,
        timeout=30,
    )
    print(f"GraphQL status: {resp2.status_code}")
    print(resp2.text[:3000])
else:
    print(f"Success: {resp.status_code}")
    print(resp.text[:3000])
