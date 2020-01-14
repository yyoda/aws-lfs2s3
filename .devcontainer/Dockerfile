FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    wget \
    unzip \
    git \
    vim \
    libicu[0-9][0-9]

# terraform
ARG TF_VERSION=0.12.6
RUN cd ./bin \
 && wget https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip \
 && unzip *.zip \
 && rm terraform_*.zip
