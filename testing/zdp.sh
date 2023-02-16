#!/bin/bash

set -euo pipefail

echo 'It should have a conn.log with at least one JSON entry'
kubectl exec -n zeek deployments/sensor -c sensor -- tail -n1 conn.log | jq -c '.'

echo 'Success!'
