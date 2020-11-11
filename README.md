# senzing-api-gateway

## Overview

AWS instructions on how to create a fully functioning api gateway with load balancers and scaleable servers

## Pre-requisite

Install AWS ECS CLI by following these [instructions](https://docs.aws.amazon.com/AmazonECS/latest/developerguide/ECS_CLI_installation.html)

Install AWS CLI by following these [instructions](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2-linux.html)

Can use this Dockerfile which does the same thing

```console
docker build -t senzing-awscli:latest .
docker run -it senzing-awscli:latest
```

## Setup

AWS Fargate to host the senzing api containers

Load balancer in front of the fargate containers

Some kind of production level authentication at the front
