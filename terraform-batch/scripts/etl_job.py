import os
import sys
import time
import random
import json
from datetime import datetime, timezone

job_id = os.environ.get("AWS_BATCH_JOB_ID", "local-test")
attempt = int(os.environ.get("AWS_BATCH_JOB_ATTEMPT", "0"))
dataset = os.environ.get("ETL_DATASET", "unknown")
pipeline = os.environ.get("ETL_PIPELINE", "batch-etl-pipeline")
source_system = os.environ.get("ETL_SOURCE", "s3://observe-demo-datalake/raw")
dest_system = os.environ.get("ETL_DEST", "s3://observe-demo-datalake/processed")

random.seed(job_id)

def log(level, stage, message, **kwargs):
    record = {
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "level": level,
        "job_id": job_id,
        "attempt": attempt,
        "pipeline": pipeline,
        "dataset": dataset,
        "stage": stage,
        "message": message,
    }
    record.update(kwargs)
    print(json.dumps(record), flush=True)

def sleep_range(lo, hi):
    time.sleep(random.uniform(lo, hi))

log("INFO", "init", "ETL job starting",
    source=source_system, destination=dest_system, version="2.1.0")

failure_roll = random.random()
if failure_roll < 0.12:
    failure_type = random.choice([
        "source_connection_timeout",
        "schema_validation_failure",
        "destination_unavailable",
        "quota_exceeded",
    ])
    sleep_range(1, 5)
    log("ERROR", "extract", "Job failed at extraction phase",
        error_type=failure_type,
        retry_attempt=attempt,
        retriable=failure_type != "schema_validation_failure")
    sys.exit(1)

log("INFO", "extract", "Connecting to source system",
    source=source_system, protocol="s3", region="us-west-2")
sleep_range(1, 4)

record_count = random.randint(8000, 750000)
extract_duration = round(random.uniform(3, 18), 3)
log("INFO", "extract", "Source scan complete",
    partitions_scanned=random.randint(4, 128),
    records_discovered=record_count,
    size_bytes=record_count * random.randint(180, 900),
    duration_s=extract_duration)

sleep_range(1, 3)

log("INFO", "transform", "Starting transformation pipeline",
    rules=["deduplicate", "schema_cast", "null_fill", "enrich_geo", "validate_refs"])

sleep_range(4, 18)

invalid_count = random.randint(0, max(1, int(record_count * 0.025)))
duplicate_count = random.randint(0, max(1, int(record_count * 0.005)))
valid_count = record_count - invalid_count - duplicate_count
transform_duration = round(random.uniform(8, 35), 3)

if invalid_count > int(record_count * 0.02):
    log("WARN", "transform", "Invalid record threshold exceeded",
        invalid_count=invalid_count,
        invalid_pct=round(invalid_count / record_count * 100, 2),
        threshold_pct=2.0)

if duplicate_count > 0:
    log("INFO", "transform", "Duplicates removed",
        duplicate_count=duplicate_count)

log("INFO", "transform", "Transformation complete",
    input_records=record_count,
    valid_records=valid_count,
    invalid_records=invalid_count,
    duration_s=transform_duration)

if failure_roll < 0.18:
    sleep_range(1, 3)
    log("ERROR", "load", "Destination write failed",
        error_type="destination_throttled",
        records_committed=0,
        retriable=True)
    sys.exit(1)

log("INFO", "load", "Opening destination transaction",
    destination=dest_system, format="parquet", compression="snappy")
sleep_range(3, 12)

bytes_written = valid_count * random.randint(220, 850)
load_duration = round(random.uniform(5, 20), 3)
log("INFO", "load", "Destination write complete",
    records_written=valid_count,
    bytes_written=bytes_written,
    partitions_written=random.randint(1, 32),
    duration_s=load_duration)

total_duration = round(extract_duration + transform_duration + load_duration + random.uniform(2, 6), 3)
log("INFO", "complete", "ETL job finished successfully",
    total_records_in=record_count,
    total_records_out=valid_count,
    records_rejected=invalid_count + duplicate_count,
    total_duration_s=total_duration,
    throughput_rps=round(record_count / max(total_duration, 1), 1))
