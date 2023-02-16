#!/bin/bash

set -euo pipefail

echo 'It should get a recent log uid from deployments/sensor'
query=$(kubectl exec -n zeek deployments/sensor -c sensor  -- tail -n1 conn.log |jq -r '.uid')
echo "uid=${query}"

kubectl port-forward service/quickstart-es-http 9200 2>/dev/null &

echo 'It should be in Elastic Search'
i=0
while true; do
	((i=i+1))
	[[ $i -gt 60 ]] && exit 1
curl -fsSk \
	  -u "elastic:$(kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')" \
	  "https://localhost:9200/customlogs-generic-default/_search" \
	  -H "Content-Type: application/json" \
	  -d @<( \
	         jq -n --arg query "${query}" '{"query":{"bool":{"filter":[{"bool":{"should":[{"term":{"zeek.connection.uid.keyword":$query}}],"minimum_should_match":1}}]}}}' \
               ) \
	       | jq -e '.hits.hits |length > 0' && break || sleep .5
done

echo 'Success!'
