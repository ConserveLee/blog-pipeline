---
title: 快速创建 Kubernetes 集群教程
date: 2019-11-09 17:41:21
abstract: 如何快速上车
tags:
 - kubernetes
 - devops
---

# 快速创建 Kubernetes 集群教程

众所周知 Kubernetes 的手动部署比较麻烦而且坑很多，对入门非常不友好。而Rancher作为开源的生产级容器管理平台，足够稳定的同时，功能完整、UI丰富且操作文档化，更重要是支持中文，便于快速创建/管理 Kubernetes 集群。

最小主机环境

1. Kubernetes 集群:

- Ubuntu 18.04.1 LTS (64位)
- CPU: 2C *
- RAM: 4GB *

*硬件加起来达到即可

2. Rancher 服务端:

- Ubuntu 18.04.1 LTS (64位)
- CPU: 1C *
- RAM: 1G *

*更小的话大概率会出现错误

## STEP 1 安装Docker CE

确认以下每一步均正常执行

#### STEP 1.1 卸载旧版本

```shell
$ sudo apt-get remove docker docker-engine docker.io containerd runc
```

#### STEP 1.2 Apt install repository

```shell
# 1. 更新repo
$ sudo apt-get update
# 2. 允许通过 HTTPS 添加 repo
$ sudo apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    software-properties-common
# 3. 添加 Docker 官方 GPG 密钥
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
# 4. 添加 stable 版本 repo
$ sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

```

#### STEP 1.3 Apt install Docker Engine 

```shell
$ sudo apt-get update
$ sudo apt-get install docker-ce docker-ce-cli containerd.io
```

#### STEP 1.4 验证 Docker 版本

```shell
$ docker --version
Docker version 19.03.5, build 633a0ea838
```



## STEP 2 安装 Rancher

```SHEll
$ sudo docker run -d -v <主机路径>:/var/lib/rancher/ --restart=unless-stopped -p 80:80 -p 443:443 rancher/rancher:latest
```



## STEP 3 添加 Kubernetes

#### STEP 3.1 进入 Rancher UI

![login](/assets/pipeline/login.jpeg)



#### STEP 3.2 添加集群

##### STEP 3.2.1 点击添加集群按钮

![添加](/assets/pipeline/r-1.jpeg)

##### STEP 3.2.2 集群类型选择自定义

![自定义](/assets/pipeline/r-2.jpeg)

##### STEP 3.2.3 输入集群名

![集群名](/assets/pipeline/r-3.jpeg)

##### STEP 3.2.4 添加主机角色

如果只有一台机子的话，需要都选上，复制到 kubernetes 主机 bash 中执行

![主机角色](/assets/pipeline/r-4.jpeg)



##### 至此已成功创建 Kubernetes 集群