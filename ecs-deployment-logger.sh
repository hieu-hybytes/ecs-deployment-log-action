#!/usr/bin/env bash

CLUSTER="${1}"
SERVICE="${2}"
STATE="${3:-FAILED}"

output_cluster_events() {
  aws ecs describe-services --cluster "${CLUSTER}" --services "${SERVICE}" | jq -r '.services[0].events[].message'
}

get_deployment_ids() {
  aws ecs describe-services --cluster "${CLUSTER}" --services "${SERVICE}" --query "services[*].deployments[?rolloutState==\`${STATE}\`].id" --output text
}

get_task_ids() {
    local opts=""
    if [ "x${STATE}" == "xFAILED" ] ; then
        local opts="--desired-status STOPPED"
    fi
    aws ecs list-tasks --cluster "${CLUSTER}" --no-paginate --started-by "${1}" ${opts} | jq '[.taskArns[] | split("/") | .[2]]'
}

get_task() {
  aws ecs describe-tasks --cluster "${CLUSTER}" --tasks "${1}" | jq '.tasks[0]'
}

get_task_stopped_reason() {
  aws ecs describe-tasks --cluster "${CLUSTER}" --tasks "${1}" --query 'tasks[0].stoppedReason'
}

process_task() {

    REASON=$(get_task_stopped_reason "${1}")
    # leaves dummy values
    TASK=$(get_task "${1}")

    typeset -p TASK \
	       REASON 
}

process_deployment() {
  if [ "x${1}" == "x" ] ; then
    echo "No deployments matched specified state ${STATE}"
    return
  fi
  if [ "x${STATE}" == "xFAILED" ] ; then
    echo "Examining ECS deployment ${1}"
    TASK_IDS=$(get_task_ids "${1}")
    process_tasks "${TASK_IDS}"
  fi
}

process_tasks() {
  for taskId in $(echo "${1}" | jq -r '.[]'); do
    echo process_task "${taskId}"
    process_task "${taskId}"
  done
}

main() {
    SERVICE_DEPLOYMENT_ID=$(get_deployment_ids)
    process_deployment "${SERVICE_DEPLOYMENT_ID}"
}

main

