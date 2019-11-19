---
title: 从零开始搭建一个完整的Kubernetes集群（一）   
date: 2019-02-21 19:48:24
categories: kubernetes
tags:
 - develop
 - kubernetes
 - kubeadm
 - dashboard
---

# 从零开始搭建一个完整的 Kubernetes 集群（一 部署集群）



## 前言

### 项目背景

作为开发者，这几年我们见证了云计算时代的到来。而 kubernetes 在容器世界里，已然成为技术的事实标准，掌握 kubernetes 独有的编程范式和基础知识成为一件非常重要的事情。

学习 kubernetes 是一个漫长的过程，但是在学习期间，我发现搭建一个 Kubernetes（K8S）尤其是完整的集群不是一件容易的事情，主要困难有几个：

> - GFW
> - Kubernetes 基本概念和知识，以及对工具使用的不熟悉
> - 网络上文档资料的过时，中文文档的缺乏，以及茫茫文档海里的不全面
> - 非 kubernetes 的知识点缺失，也就是分布式系统、网络、存储等方方面面的知识点缺失

### 初衷

之前一直使用 docker-compose 以及 dockerfile 编排 docker 容器。也部署了不少网站，因为一直感到种种不完善以及不灵活的地方，特别是涉及到CI。所以便开始重新采用新的 kubernetes 架构，直到目前重新部署完这个博客。

鉴于这些天踩了不少坑，为了填坑，也为了自己查漏补缺，出于这些种种原因，写了这篇文章。希望对踌躇无措的人能有所帮助。

> 这里所说的“完整”，指的是这个集群具备 Kubernetes 在 GitHub 上已经发布的所有功能，并能够接近生产环境的所有使用需求，而不是 Minikube 这种单节点的尝鲜版本。



## 准备工作

#### **知识**

了解 kubernetes 的基本概念，比如 CLI（[kubectl](https://k8smeetup.github.io/docs/user-guide/kubectl/)）和资源（[pods](https://k8smeetup.github.io/docs/user-guide/pods)，[services](https://k8smeetup.github.io/docs/user-guide/services)等）。

#### **环境**

我准备的环境如下

若干个（2个或以上）2 核 CPU、 4 GB 内存的VPS服务器，我用的是腾讯云；

机器之间网络互通，我用的是对等网络；

每台服务器50G以上云硬盘，用于 dokcer 镜像和日志的存储；

一块独立的若干大小数据盘，用于挂载PV；

64位的 Ubuntu 18.04；

便于使用，我全部采取 root 用户。ps，最好不要用Centos（用了你就知道那酸爽），Ubuntu 对 kubernetes的支持要相对好得多；

修改默认 static hostname 为自定义（你喜欢的名字），比如 node0，node1，node2…；

每台机器均能科学上网（至少 master 节点能访问），否则要装一大堆镜像源，等等；



## 开始部署

### STEP 1 安装 kubeadm 和 Docker

```shell
$ curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
$ cat <<EOF > /etc/apt/sources.list.d/kubernetes.list
deb http://apt.kubernetes.io/ kubernetes-xenial main
EOF
$ apt-get update
$ apt-get install -y docker.io kubeadm

```

直接使用 Ubuntu 的 docker.io 的安装源，因为 docker CE 和最新的 Kubernetes 可能会有兼容问题，和 Ubuntu 最新的发行版也可能会有这个问题。

在上述安装 kubeadm 的过程中，kubeadm 和 kubelet、kubectl、kubernetes-cni 这几个二进制文件都会被自动安装好。



### STEP 2 部署 Kubernetes 的 Master 节点

### kuberadm

kuberadm是一个HA级别（能用于生产环境）的独立部署工具，极大的节省了使用复杂的脚本、运维工具的成本。

> 为了方便部署，我对 kuberadm 写了一份 yaml 文文件。并且所有需要用到的文件，都在[这里](https://github.com/ConserveLee/quick-kubernetes-deploy)可以找到。
>

```shell
$ git clone https://github.com/ConserveLee/quick-kubernetes-deploy.git quick-k8s
$ cd quick-k8s/kubernetes
```

修改 <your ip> 和 <your hostname> 为正确数据

```shell
$ kubeadm init --config kubeadm.yaml
```



### ps

#### 如果出错，请使用

```shell
$ kubeadm reset
```

或者

```shell
$ kubectl reset -f
```

进行重置

之后的过程出错，可以使用

```shell
$ kubectl delet -f <FileName>.yaml
```



#### 好了继续

如果没有问题，现在已经完成 Kubernetes Master 的部署了，kubeadm会提示 kubeadm join 命令，用于给这个 Master 节点添加更多worker节点。

在后面部署 Worker 节点的时候马上会用到，所以请记录下来。

```shell
kubeadm join <master IP>:6443 --token 5n9s47.cmo7gunvt95ingh2 --discovery-token-ca-cert-hash sha256:d3321b231e55706a9283fffcb99e8c9491f1cda0e8a8bc8893f03731c95952db
```

此外，kubeadm 还会提示我们第一次使用 Kubernetes 集群所需要的配置命令：

```shell
$ mkdir -p $HOME/.kube
$ sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
$ sudo chown $(id -u):$(id -g) $HOME/.kube/config
```



### STEP 3 部署网络插件

```shell
$ kubectl get nodes
...
$ kubectl describe node <node name>
...
Conditions:
...
Ready   False ... KubeletNotReady  runtime network not ready: NetworkReady=false reason:NetworkPluginNotReady message:docker: network plugin is not ready: cni config uninitialized
```

这里是因为未部署任何网络插件，接下来部署weave

```shell
kubectl apply -f weave-daemonset.yaml
kubectl get pods -n kube-system
```

可以看到所有的系统 Pod 都成功启动了。



### STEP 4 部署worker节点

在其余所有服务器执行 **STEP 2** 保存的join命令

```shell
$ kubeadm join <master IP>:6443 --token 5n9s47.cmo7gunvt95ingh2 --discovery-token-ca-cert-hash sha256:d3321b231e55706a9283fffcb99e8c9491f1cda0e8a8bc8893f03731c95952db
```



### STEP 5 通过 Taint/Toleration 调整 Master 节点

Taint/Toleration 机制允许 Master 节点 运行用户 Pod （默认是不允许的）

```shell
$ kubectl taint node <master node name> foo=bar:NoSchedule
```

如果你就是想要一个单节点的 Kubernetes，删除这个 Taint 才是正确的选择：

```shell
$ kubectl taint nodes --all node-role.kubernetes.io/master-
```

### STEP 6 部署 Dashboard 可视化插件

Dashboard 是官方的一个可视化工具，可以给用户提供一个可视化的 Web UI 界面来查看当前集群的各种信息

```shell
$ kubectl apply -f dashboard.yaml
# 查看 admin-user的token
$ kubectl -n kube-system describe secret $(kubectl -n kube-system get secret | grep admin-user | awk '{print $1}')
```

记录出现的token

使用firefox访问https://<YourIP>:30000/#!/login，选择令牌登陆，输入记录的token，即可访问dashboard

![image-20190221230431143](/assets/kubernetes/dashboard.jpeg)



### STEP 7 故障排除

到这一步，检查之前的步骤是否有出错

```shell
# 查看所有基本类型资源
$ kuberctl get all --all-namespeaces 
```

如果有异常的资源


```shell
# 查看单个资源
$ kuberctl describe <type> <name> -n <namespace>
# 查看单个yaml
$ kuberctl get -o yaml <type> <name> -n <namespace>
# 查看pod日志
$ kubectl logs --tail=20 <name> -n <namespace>
```

逐一排查，这里不一一细说



### STEP 8 布置ETCD集群

kubeadm 安装的集群，默认 etcd 是一个单机的容器化的 etcd，并且 kubernetes 和 etcd 通信没有经过ssl加密和认证，这是可以改的。

（可选）例如部署一个三节点的etcd集群，二进制部署，systemd守护进程，并且需要生成ca证书。



### STEP 9 部署完成

重复 **STEP 7** ，直到全部running则表示集群正常。至此，我们的 kubernetes 集群所有基本资源宣告搭建成功了。



章节：

- [从零开始搭建一个完整的 Kubernetes 集群（一 部署集群）](/2019/02/21/create-full-kubernetes-1/)
- [从零开始搭建一个完整的 Kubernetes 集群（二 持续化存储）](/2019/02/22/create-full-kubernetes-2/)
- [从零开始搭建一个完整的 Kubernetes 集群（三 helm）]()
- [从零开始搭建一个完整的 Kubernetes 集群（四 ingress以及nginx）]()



#### **[github地址](https://github.com/ConserveLee/quick-kubernetes-deploy) **

#### **如果对你有帮助，记得 fork 和 star， 欢迎留言**

