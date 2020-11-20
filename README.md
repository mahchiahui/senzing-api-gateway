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

### Step 1: Load Balancer



### Step 2: ECS Fargate Service Cluster

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

Retrieve the default security group ID

```console
aws ec2 describe-security-groups --filters Name=vpc-id,Values=<cluster-vpc-id> --region <aws-region>
```

Using the security group ID from the last command, add a security group rule to allow inbound access on port 80

```console
aws ec2 authorize-security-group-ingress --group-id <cluster-security-group-id> --protocol tcp --port 80 --cidr 0.0.0.0/0 --region us-east-1
```

Example
```console
ecs-cli up --cluster-config senzing-example-cluster-config --ecs-profile senzing-profile
aws ec2 describe-security-groups --filters Name=vpc-id,Values=<cluster-vpc-id> --region us-east-1
aws ec2 authorize-security-group-ingress --group-id <cluster-security-group-id> --protocol tcp --port 80 --cidr 0.0.0.0/0 --region us-east-1
```

deploy compose to Cluster

```console
ecs-cli compose --project-name <compose-service-name> service up --create-log-groups --cluster-config <cluster-config-name> --ecs-profile <ecs-profile-name>
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

### Step 3: AWS Cognito



## References

https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ecs-cli-tutorial-fargate.html
