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

AWS Fargate to host the senzing api containers

Load balancer in front of the fargate containers

Some kind of production level authentication at the front
