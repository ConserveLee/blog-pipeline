---
title: 通过 Kubernetes 自动化构建 Blog
date: 2019-11-19 18:31:15
abstract: 自动化构建的一个演示 demo
tags:
 - kubernetes
 - hexo
 - devops
---



# 通过 Kubernetes 自动化构建部署 Blog

正所谓工欲善其事，必先利其器。根据费曼学习法，写博客可以很好的技术积累。而 Kubernetes 可以让你自动化部署各种应用，下面以 Hexo 作为示例。



## 技术栈

- Hexo & Node.js
- Git
- Docker Engine
- Docker Image
- Jenkis
- Kubenetes
- Rancher
- Rancher-pipeline

选择 Hexo 的原因是颜值高，扩展性强，操作简单。因为简单，用 Kubernetes 构建时可以避免很多复杂性的错误。~~而且作为 MarkDown Coder，Hexo是不二选择。~~



## STEP 1 创建 Kubenetes 集群

因为篇幅问题，详细请参考

[快速创建 Kubernetes 集群]: /2019/11/19/build-rancher-kubernetes/



## STEP 2 添加 Docker Hub 凭证

#### STEP 2.1 注册 Docker Hub

![Docker Hub](/assets/pipeline/a-1.png)

#### STEP 2.2 添加凭证

![添加凭证](/assets/pipeline/a-2.png)

在 集群->default->资源->密文->镜像库凭证列表 中添加 Docker Hub 凭证，账号密码为刚注册的账号密码。



## STEP 3 编写自动化构建样本

#### STEP 3.1 样本文件目录

- **source**  Hexo 的资源目录
- **themes** Hexo 的主题目录
  - **ochuunn** ochuunn主题目录
  - **_config.yml** 主题配置文件
- **.rancher-pipeline.yml** Rancher-pipeline 配置文件
- **_config.yml** Hexo 配置文件
- **deployment.yaml** Pods 配置文件
- **dockerfile** 自定义镜像构建文件



#### STEP 3.2 编写配置文件

##### 目的：

在本地写好 MarkDown 文件，Git 推送即可自动化构建&部署到 kubernetes 集群中。



##### pipeline 术语：

- **Pipeline** 定义了构建、测试和部署代码的一个过程

- **Stages** Pipeline 阶段

- **Step** 阶段内的 Pipeline 步骤

- **Workspace** 所有 Pipeline 步骤共享的目录

  

##### pipeline 思路：

1. 监听 Master 分支上的推送动作

2. 使用 Dockerfile 推送 Docker 镜像

3. 通过 deployment.yaml 在 Kubernetes 上部署 Hexo 的 Kubernetes Pod

   > 本来打算用 Nginx + Hexo 共享 blog 的公共目录，但比起构建单个 Hexo Container，构建多个 Container 性能其实更差一些。



#### step 3.3 添加 Git 项目

**dockerfile**

```dockerfile
FROM node:13.1.0 
# 拉取官方node镜像，注意要指定tag，不要用latest
WORKDIR /var/www/
# 指定工作目录
RUN npm install hexo-cli -g
# 安装hexo脚手架
RUN hexo init blog
# 新建hexo项目
WORKDIR /var/www/blog
ADD . /var/www/blog/
# 切换blog工作目录，添加文件至镜像内
RUN npm install \
&& npm install --save hexo-helper-live2d \
&& npm install hexo-renderer-pug --save
# 安装npm依赖
EXPOSE 4000
# hexo server默认端口为4000
```



**.rancher-pipeline.yml**

```yaml
stages:
# 这里还可以写分支和行为，因为示例比较简单就不写了
- name: build # 构建镜像
  steps:
  - publishImageConfig:
      dockerfilePath: ./dockerfile
      buildContext: .
      tag: quanzhilong/hexo:v1.0.1
      pushRemote: true
      registry: index.docker.io # Docker Hub地址
- name: deploy # 部署实例
  steps:
  - applyYamlConfig:
      path: ./deployment.yaml
timeout: 60
notification: {}

```



**deployment.yaml**

```yaml
# 篇幅较长不详细说明，详见kuberntes文档
# svc of hexo
kind: Service
apiVersion: v1
metadata:
  name: hexo-service
spec:
  selector:
    app: hexo
  type: NodePort
  ports:
    - protocol: TCP
      port: 80
      targetPort: 4000
---
#deploy of hexo
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hexo
  labels:
    app: hexo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hexo
  template:
    metadata:
      labels:
        app: hexo
    spec:
      imagePullSecrets:
        - name: pipeline-docker-registry
      containers:
        - name: hexo
          image: quanzhilong/hexo:v1.0.1
          ports:
            - containerPort: 4000
          command: ["/bin/sh"]
          args: ["-c", "hexo server"]
```



> 其余详见 Github 地址



#### STEP 3.4 新建 pipeline

##### STEP 3.4.1 配置版本控制应用

![认证](/assets/pipeline/a-3.png)

在 集群->default->资源->流水线中添加 github 应用凭证

##### STEP 3.4.2 设置代码仓库 & 运行示例 Pipeline

![代码库](/assets/pipeline/a-4.png)

![运行](/assets/pipeline/a-5.png)

验证后选择相应的代码库，点击运行



## STEP 4 验证

访问 http://PUBLIC_IP:NODE_PORTS 验证

我的是 http://lizhongyuan.net



#### 参考：

[Kubernetes 中文文档]: https://kubernetes.io/zh/
[Github 地址]: https://github.com/ConserveLee/blog-pipeline
[Rancher  中文手册]: https://www.bookstack.cn/read/rancher-v2.x/0de5eb5c4056b8f6.md

