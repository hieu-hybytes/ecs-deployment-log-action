# ECS Deployment Logger - Github Action

Fetches ECS Deployment Logs and Container Logs (started the `failed` or `pending` deployment).

> Only works if the containers move their logs to AWS Cloudwatch

## Usage

> the following is just an ECS deployment

```yaml
name: Example workflow for ECS Deployment
on: [push]
jobs:
  run:
    runs-on: ubuntu-latest
    steps:
      # configure AWS credentials
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: eu-central-1

      # fetch current task definition from ECS
      - name: Download task definition
        run: |
          aws ecs describe-task-definition --task-definition ${{ inputs.task_definition }} --query taskDefinition > task-definition.json

      # update task defintion with new image
      - name: Render Amazon ECS task definition for first container
        id: render-web-container
        uses: aws-actions/amazon-ecs-render-task-definition@v1
        with:
          task-definition: task-definition.json
          container-name: ${{ inputs.container_name }}
          image: ${{ inputs.docker_image }}:${{ inputs.commit }}

      # deploy new task definition with updated docker image
      - name: Deploy Amazon ECS task definition
        uses: aws-actions/amazon-ecs-deploy-task-definition@v1
        with:
          task-definition: task-definition.json
          service: ${{ inputs.service }}
          cluster: ${{ inputs.cluster }}
          wait-for-service-stability: true
      
      # see below for the 2 variants on how to use this action
```

### Action-Configuration to only show logs in case of an error or cancellation

```yaml
      - name: Show Deployment Logs
        if: failure() || cancelled()
        uses: digitalkaoz/ecs-deployment-log-action@v2.1
        with:
          cluster: ${{ inputs.cluster }}
          service: ${{ inputs.service }}
```

### Action-Configuration to always show logs

```yaml
      - name: Show Deployment Logs
        uses: digitalkaoz/ecs-deployment-log-action@v2.1
        with:
          cluster: ${{ inputs.cluster }}
          service: ${{ inputs.service }}
          state: NONE # available values are COMPLETED | FAILED | IN_PROGRESS | NONE
```