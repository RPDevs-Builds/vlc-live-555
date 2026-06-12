jobs_json='{"jobs": [{"name": "Compile (linux-64bit)", "status": "completed", "conclusion": "success"}]}'
echo "$jobs_json" | jq -r --arg n "Compile (linux-64bit)" '.jobs[] | select(.name == $n) | "\(.status)|\(.conclusion)"'
