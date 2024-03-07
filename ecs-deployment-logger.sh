#!/usr/bin/env bash

CLUSTER="${1}"
SERVICE="${2}"

show_cluster_events() {
  echo -e "show latest cluster events\n"
  aws ecs describe-services --cluster "${CLUSTER}" --services "${SERVICE}" | jq -r '.services[0].events[].message'
}

get_deployments() {
  aws ecs describe-services --cluster "${CLUSTER}" --services "${SERVICE}" | jq '[.services[0].deployments[] | select(.rolloutState != "COMPLETED")]'
}

get_deployment_ids() {
  echo "${1}" | jq -r '[.[].id]'
}

get_task_ids() {
  aws ecs list-tasks --cluster "${CLUSTER}" --no-paginate --started-by "${1}" --output json | jq '[.taskArns[] | split("/") | .[2]]'
}

get_task() {
  aws ecs describe-tasks --cluster "${CLUSTER}" --tasks "${1}" | jq '.tasks[0]'
}

get_task_arn() {
    TASK_ARN=$(echo "${1}" | jq '.taskDefinitionArn')
    #remove leading/trailing " so aws-cli wont get confused
    TASK_ARN=${TASK_ARN%\"}
    TASK_ARN=${TASK_ARN#\"}
    echo "${TASK_ARN}"
}

get_log_group() {
    LOG_GROUP=$(aws ecs describe-task-definition --task-definition "${1}" | jq '.taskDefinition.containerDefinitions[].logConfiguration.options."awslogs-group"')
    #remove leading/trailing " so aws-cli wont get confused
    LOG_GROUP=${LOG_GROUP%\"}
    LOG_GROUP=${LOG_GROUP#\"}
    echo "${LOG_GROUP}"
}

get_container_ids() {
  echo "${1}" | jq '[.containers[].runtimeId | split("-") | .[0]]'
}

get_stream() {
    STREAM=$(aws logs describe-log-streams --log-group-name "${2}" | jq ".logStreams[] | select(.logStreamName | endswith(\"${1}\")) | .logStreamName")
    STREAM=${STREAM%\"}
    STREAM=${STREAM#\"}
    echo "${STREAM}"
}

process_container() {
    STREAM=$(get_stream "${1}" "${2}")
    echo -e "examining Cloudwatch logs ${2}/${STREAM}\n"
    aws logs get-log-events --log-group-name "${2}" --log-stream-name "$STREAM" | jq -r '.events[].message'
}

process_task() {
    echo -e "examining ECS task ${1}\n"

    TASK=$(get_task "${1}")
    TASK_ARN=$(get_task_arn "$TASK")
    LOG_GROUP=$(get_log_group "${TASK_ARN}")
    CONTAINER_IDS=$(get_container_ids "${TASK}")

    process_containers "${CONTAINER_IDS}" "${LOG_GROUP}"
}

process_deployment() {
  echo -e "\nexamining ECS deployment ${1}\n"

  TASK_IDS=$(get_task_ids "${1}")
  process_tasks "${TASK_IDS}"
}

process_deployments() {
  for deploymentId in $(echo "${1}" | jq -r '.[]'); do
    process_deployment "${deploymentId}"
  done
}

process_tasks() {
  for taskId in $(echo "${1}" | jq -r '.[]'); do
    process_task "${taskId}"
  done
}

process_containers() {
    for containerId in $(echo "${1}" | jq -r '.[]'); do
      process_container "${containerId}" "${2}"
    done
}

DEPLOYMENTS=$(get_deployments)
IDS=$(get_deployment_ids "${DEPLOYMENTS}")

show_cluster_events
process_deployments "${IDS}"