import subprocess, json

result = subprocess.run(['aws', 'logs', 'filter-log-events', '--region', 'us-west-2',
    '--log-group-name', '/aws/lambda/aws-integration-n89zfn1a',
    '--start-time', '1772992500000', '--end-time', '1772993700000',
    '--filter-pattern', 'x-aws-elb-accesslogs', '--limit', '1', '--output', 'json'],
    capture_output=True, text=True)
data = json.loads(result.stdout)
events = data.get('events', [])
print(f"Events found: {len(events)}")
if events:
    msg = events[0]['message']
    print(f"Message length: {len(msg)}")
    print(f"First 500 chars: {msg[:500]}")
else:
    print("stderr:", result.stderr[:500])
