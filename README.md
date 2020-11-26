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
export AWS_DEFAULT_REGION=<Replace with AWS Default Region e.g. us-east-1>
docker build -t senzing-awscli:latest  --build-arg AWS_ACCESS_KEY_ID --build-arg AWS_SECRET_ACCESS_KEY --build-arg AWS_DEFAULT_REGION .
docker run -it senzing-awscli:latest /bin/bash
```

Edit the following files
1. docker-compose.yml
1. ecs-params.yml
1. task-execution-assume-role.json

## Setup

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
export VPC=<insert vpc>
export SUBNET1=<insert subnet id 1>
export SUBNET2=<insert subnet id 2>
```

Get the cluster's security group id and use it to open a port (typically port 80) in the cluster.

```console
aws ec2 describe-security-groups --filters Name=vpc-id,Values=<cluster-vpc-id> --region <aws-region>
export SEC_GRP_ID=<cluster-security-group-id>
aws ec2 authorize-security-group-ingress --group-id <cluster-security-group-id> --protocol tcp --port <port-to-open> --cidr 0.0.0.0/0 --region <aws-region>
```

Example

```console
ecs-cli up --cluster-config senzing-example-cluster-config --ecs-profile senzing-profile
export VPC=vpc-007**************
export SUBNET1=subnet-0c9**************
export SUBNET2=subnet-0e6**************
aws ec2 describe-security-groups --filters Name=vpc-id,Values=$VPC --region us-east-1
export SEC_GRP_ID=sg-065**************
aws ec2 authorize-security-group-ingress --group-id $SEC_GRP_ID --protocol tcp --port 80 --cidr 0.0.0.0/0 --region us-east-1
```

### Step 2: Create Application Load Balancer

Create application load balancer (ALB), record down arn

```console
aws elbv2 create-load-balancer \
  --name $loadBalancerName --type application \
  --subnets $SUBNET1 $SUBNET2 \
  --security-groups sg-07e8ffd50fEXAMPLE
export ALB_ARN=<app-load-balancer-arn>
```

Example

```console
aws elbv2 create-load-balancer \
  --name $loadBalancerName --type application \
  --subnets $SUBNET1 $SUBNET2 \
  --security-groups $SEC_GRP_ID
export ALB_ARN=arn:aws:elasticloadbalancing:us-east-1:************:loadbalancer/app/senzing-lb/****************
```

create target group, record down arn

```console
aws elbv2 create-target-group --name senzing-target-group --protocol HTTP --port 80 --vpc-id <insert cluster vpc id> --target-type ip
export TG_ARN=<target-group-arn>
```

Example

```console
aws elbv2 create-target-group --name senzing-target-group --protocol HTTP --port 80 --vpc-id $VPC --target-type ip
export TG_ARN=arn:aws:elasticloadbalancing:us-east-1:************:targetgroup/senzing-target-group/****************
```

Create listener

```console
aws elbv2 create-listener --load-balancer-arn <insert ALB ARN> \
  --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=<insert target group ARN>
```

Example

```console
aws elbv2 create-listener --load-balancer-arn <insert ALB ARN> \
  --protocol HTTP --port 80 \
  --default-actions Type=forward,TargetGroupArn=$TG_ARN
```

### Step 3: Deploy Service to cluster

Add subnet ids and security group id to [ecs-params.yml](ecs-params.yml), then deploy compose to Cluster

```console
ecs-cli compose --project-name <compose-service-name> service up --create-log-groups --cluster-config <cluster-config-name> --ecs-profile <ecs-profile-name> --target-groups "targetGroupArn=<insert target group arn>,containerName=senzing,containerPort=80"
```

example

```console
ecs-cli compose --project-name senzing-example service up --create-log-groups --cluster-config senzing-example-cluster-config --ecs-profile senzing-profile --target-groups "targetGroupArn=$TG_ARN,containerName=senzing,containerPort=80"
```

To check if containers are running

```console
ecs-cli compose --project-name <compose-service-name> service ps --cluster-config <cluster-config-name> --ecs-profile <ecs-profile-name>
```

Example

```console
ecs-cli compose --project-name senzing-example service ps --cluster-config senzing-example-cluster-config --ecs-profile senzing-profile
```

### Step 4: Add Autoscale policies

Register your ECS service as a scalable target

```console
aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --scalable-dimension ecs:service:DesiredCount \
    --resource-id service/<cluster-name>/<project-name> \
    --min-capacity <minimum-tasks-in-service> \
    --max-capacity <maximum-tasks-in-service>
```

Example

```console
aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --scalable-dimension ecs:service:DesiredCount \
    --resource-id service/senzing-example-cluster/senzing-example \
    --min-capacity 2 \
    --max-capacity 10
```

Create a scale up policy which takes [config_up.json](config_up.json) in as the policy configuration. [config_up.json](config_up.json) scales the ecs service's number of task up based on the cpu utilization. Take note of the PolicyARN and use it in the metric alarm

```console
aws application-autoscaling put-scaling-policy \
  --policy-name <scaling-policy-name> \
  --service-namespace ecs \
  --resource-id service/<cluster-name>/<project-name> \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-type StepScaling \
  --step-scaling-policy-configuration file://<policy-configuration-json>
Export POLICY_ARN=<scaling-up-policy-arn>
```

Example

```console
aws application-autoscaling put-scaling-policy \
  --policy-name senzing-scale-up \
  --service-namespace ecs \
  --resource-id service/senzing-example-cluster/senzing-example \
  --scalable-dimension ecs:service:DesiredCount \
  --policy-type StepScaling \
  --step-scaling-policy-configuration file://config_up.json
Export POLICY_ARN=arn:aws:autoscaling:us-east-1:************:scalingPolicy:************:resource/ecs/service/senzing-example-cluster/senzing-example:policyName/senzing-scale-up
```

Create an alarm that triggers the scale up policy when the service's tasks average CPU utilization exceeds 70% over 2 1-minute periods.

```console
aws cloudwatch put-metric-alarm \
  --alarm-name Step-Scaling-AlarmHigh-ECS:service/<cluster-name>/<project-name> \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 60 --evaluation-periods 2 --threshold 70 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=ClusterName,Value=<cluster-nmae> Name=ServiceName,Value=<service-name> \
  --alarm-actions <scaling-up-policy-arn>
```

Example

```console
aws cloudwatch put-metric-alarm \
  --alarm-name Step-Scaling-AlarmHigh-ECS:service/senzing-example-cluster/senzing-example \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 60 --evaluation-periods 2 --threshold 70 \
  --comparison-operator GreaterThanOrEqualToThreshold \
  --dimensions Name=ClusterName,Value=senzing-example Name=ServiceName,Value=sample-app-service \
  --alarm-actions $POLICY_ARN
```

Create a scale down policy (similar to the scale up policy), take note of the PolicyARN and use it in the metric alarm

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
  --alarm-name Step-Scaling-AlarmLow-ECS:service/senzing-example-cluster/senzing-example \
  --metric-name CPUUtilization \
  --namespace AWS/ECS \
  --statistic Average \
  --period 60 --evaluation-periods 2 --threshold 30 \
  --comparison-operator LessThanOrEqualToThreshold \
  --dimensions Name=ClusterName,Value=default Name=ServiceName,Value=sample-app-service \
  --alarm-actions PolicyARN
```

### Step 5: AWS Cognito

TBD

## Clean Up

TBD

## References

https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-cli-tutorial-fargate.html
