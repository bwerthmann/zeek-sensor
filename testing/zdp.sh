#!/bin/bash

set -e

echo 'It should have a conn.log with at least one JSON entry'
DOC=$(kubectl exec -n zeek deployments/sensor -c sensor -- tail -n1 conn.log)

jq -c '.' <<<"$DOC"

echo 'Success!'
