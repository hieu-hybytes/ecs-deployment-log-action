#!/usr/bin/env bash
#
# Get deployment status from Amazon ECS deployments

CLUSTER="${1}"
SERVICE="${2}"
STATE="${3:-FAILED}"

output_cluster_events() {
  aws ecs describe-services --cluster "${CLUSTER}" --services "${SERVICE}" | jq -r '.services[0].events[].message'
}

#######################################
# Get Amazon ECS service deployment id
# Globals:
#   CLUSTER
#   SERVICE
#   STATE
# Agruments:
#   None
# Outputs:
#   Write service deployment id to stdout
#######################################
get_deployment_ids() {
  aws ecs describe-services --cluster "${CLUSTER}" --services "${SERVICE}" --query "services[*].deployments[?rolloutState==\`${STATE}\`].id" --output text
}

#######################################
# Get rollout state of a service deployment
# Globals:
#   CLUSTER
#   SERVICE
# Agruments:
#   Service deployment id
# Outputs:
#   Write service deployment failure reason to stdout
#######################################
get_deployment_rollout_state() {
  aws ecs describe-services --cluster "${CLUSTER}" --services "${SERVICE}" --query "services[*].deployments[?id==\`${1}\`].rolloutStateReason" --output text
}

get_task_ids() {
    local opts=""
    if [ "x${STATE}" == "xFAILED" ] ; then
        local opts="--desired-status STOPPED"
    fi
    aws ecs list-tasks --cluster "${CLUSTER}" --no-paginate --started-by "${1}" ${opts} | jq '[.taskArns[] | split("/") | .[2]]'
}

get_task_stopped_reason() {
  aws ecs describe-tasks --cluster "${CLUSTER}" --tasks "${1}" --query 'tasks[0].stoppedReason'
}

process_task() {
    REASON=$(get_task_stopped_reason "${1}")
    echo "${REASON}"
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
    echo "Processing task ${taskId}"
    process_task "${taskId}"
    return
  done
}

main() {
    SERVICE_DEPLOYMENT_ID=$(get_deployment_ids)
    ROLLOUT_STATE_REASON=$(get_deployment_rollout_state "${SERVICE_DEPLOYMENT_ID}")

    typeset -p SERVICE_DEPLOYMENT_ID \
	    ROLLOUT_STATE_REASON

    process_deployment "${SERVICE_DEPLOYMENT_ID}"
}

main
