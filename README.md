# senzing-api-gateway

## Overview

AWS instructions on how to create a fully functioning api gateway with load balancers and scaleable servers

## Pre-requisite

Install AWS ECS CLI by following these [instructions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_CLI_installation.html)

Install AWS CLI by following these [instructions](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html)

Can use this Dockerfile which does the same thing

```console
export AWS_ACCESS_KEY_ID=<Replace with AWS Access Key ID>
export AWS_SECRET_ACCESS_KEY=<Replace with AWS Secret Access Key>
export AWS_DEFAULT_REGION=<Replace with AWS Default Region e.g. us-east-2>
docker build -t senzing-awscli:latest  --build-arg AWS_ACCESS_KEY_ID --build-arg AWS_SECRET_ACCESS_KEY --build-arg AWS_DEFAULT_REGION .
docker run -it senzing-awscli:latest /bin/bash
```

Edit the following files
1. docker-compose.yml
1. ecs-params.yml
1. task-execution-assume-role.json

## Setup

Step 1: Load balancer

Step 2: ECS Fargate Cluster

Step 3: AWS Cognito

### Step 1: Create Fargate Cluster

First need to create iam role and attach the task execution role policy that would allow ECS agent to make API calls for security_groups

```console
aws iam --region <aws-region> create-role --role-name <iam role name> --assume-role-policy-document file://task-execution-assume-role.json
aws iam --region <aws-region> attach-role-policy --role-name <iam role name> --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

Example

```console
aws iam --region us-east-1 create-role --role-name ecsTaskExecutionRole --assume-role-policy-document file://task-execution-assume-role.json
aws iam --region us-east-1 attach-role-policy --role-name ecsTaskExecutionRole --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

Create a cluster configuration

```console
ecs-cli configure --cluster <cluster-name> --default-launch-type FARGATE --config-name <cluster-config-name> --region <aws-region>
```

create ecs-cli profile with access and secret key

```console
ecs-cli configure profile --access-key $AWS_ACCESS_KEY_ID --secret-key $AWS_SECRET_ACCESS_KEY --profile-name <ecs-profile-name>
```

Example

```console
ecs-cli configure --cluster senzing-example-cluster --default-launch-type FARGATE --config-name senzing-example-cluster-config --region us-east-1
ecs-cli configure profile --access-key $AWS_ACCESS_KEY_ID --secret-key $AWS_SECRET_ACCESS_KEY --profile-name senzing-profile
```

Create ECS cluster based on the cluster profile and ecs-cli profile. Take note of the VPC and subnet IDs that are created.

```console
ecs-cli up --cluster-config <cluster-config-name> --ecs-profile <ecs-profile-name>
```

Example
```console
ecs-cli up --cluster-config senzing-example-cluster-config --ecs-profile senzing-profile
aws ec2 describe-security-groups --filters Name=vpc-id,Values=<cluster-vpc-id> --region us-east-1
aws ec2 authorize-security-group-ingress --group-id <cluster-security-group-id> --protocol tcp --port 80 --cidr 0.0.0.0/0 --region us-east-1
```

### Step 2: Create Application Load Balancer

create application load balancer (ALB), record down arn

```console
aws elbv2 create-load-balancer --name $loadBalancerName --type application --subnet-mappings SubnetId=<replace with cluster subnet ID>
```

create target group, record down arn

```console
aws elbv2 create-target-group --name senzing-target-group --protocol TCP --port 80 --vpc-id <insert cluster vpc id> --target-type ip
```

create listener

aws elbv2 create-listener --load-balancer-arn <insert ALB ARN> \
  --protocol TCP --port 80 \
  --default-actions Type=forward,TargetGroupArn=<insert target group ARN>

### Step 3: Deploy Service to cluster

deploy compose to Cluster

```console
ecs-cli compose --project-name <compose-service-name> service up --create-log-groups --cluster-config <cluster-config-name> --ecs-profile <ecs-profile-name> --target-groups <insert target group arn>
```

example

```console
ecs-cli compose --project-name senzing-example service up --create-log-groups --cluster-config senzing-example-cluster-config --ecs-profile senzing-profile
```

To check if containers are running

```console
ecs-cli compose --project-name <compose-service-name> service ps --cluster-config <cluster-config-name> --ecs-profile <ecs-profile-name>
```

Example

```console
ecs-cli compose --project-name senzing-example service ps --cluster-config senzing-example-cluster-config --ecs-profile senzing-profile
```

### Step 4: Add Autoscale policy

Register your ECS service as a scalable target

```console
aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --scalable-dimension ecs:service:DesiredCount \
    --resource-id service/senzing-example-cluster/senzing-example \
    --min-capacity 2 \
    --max-capacity 10
```

Create a scale up policy, take note of the PolicyARN to use it in the metric alarm

```console
aws application-autoscaling put-scaling-policy \
  --policy-name senzing-scale-up \
  --service-namespace ecs \
  --resource-id service/senzing-example-cluster/senzing-example \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-type StepScaling \
  --step-scaling-policy-configuration file://config_up.json
```

Create an alarm that triggers the scale up policy

```console
aws cloudwatch put-metric-alarm \
  --alarm-name Step-Scaling-AlarmHigh-ECS:service/senzing-example-cluster/senzing-example
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 60 --evaluation-periods 2 --threshold 70 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=ClusterName,Value=senzing-example Name=ServiceName,Value=sample-app-service \
  --alarm-actions PolicyARN
```

Create a scale down policy, take note of the PolicyARN to use it in the metric alarm

```console
aws application-autoscaling put-scaling-policy \
  --policy-name senzing-scale-down \
  --service-namespace ecs \
  --resource-id service/senzing-example-cluster/senzing-example \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-type StepScaling \
  --step-scaling-policy-configuration file://config_down.json
```

Create an alarm that triggers the scale down policy

```console
aws cloudwatch put-metric-alarm \
  --alarm-name Step-Scaling-AlarmLow-ECS:service/senzing-example-cluster/senzing-example
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 60 --evaluation-periods 2 --threshold 30 \
  --comparison-operator LessThanOrEqualToThreshold \
  --dimensions Name=ClusterName,Value=default Name=ServiceName,Value=sample-app-service \
  --alarm-actions PolicyARN
```

### Step 3: AWS Cognito



## References

https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-cli-tutorial-fargate.html
