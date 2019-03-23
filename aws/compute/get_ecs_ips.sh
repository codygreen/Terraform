TASKS=`aws ecs list-tasks --cluster f5-demo-httpd --output json \
| jq -r '.taskArns[]'`
IPS=`aws ecs describe-tasks --cluster f5-demo-httpd --tasks \
$TASKS | \
jq '[ .tasks[].containers[].networkInterfaces[].privateIpv4Address | .] | join(",")' `

jq -n --arg ips "$IPS" '{"ips": $ips}'