FROM python:3.8.6-buster

# Installing ECS CLI
RUN curl -Lo /usr/local/bin/ecs-cli https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest

RUN apt-get install gpg

RUN gpg --keyserver hkp://keys.gnupg.net --recv BCE9D9A42D51784F

RUN curl -Lo ecs-cli.asc https://amazon-ecs-cli.s3.amazonaws.com/ecs-cli-linux-amd64-latest.asc

RUN chmod +x /usr/local/bin/ecs-cli

# Installing AWS CLI
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

RUN unzip awscliv2.zip

RUN ./aws/install

ENTRYPOINT ["/bin/bash"]
