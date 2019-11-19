---
title: 从零开始搭建一个完整的Kubernetes集群（二）   
date: 2019-02-22 16:39:18
categories: kubernetes
tags:
 - develop
 - kubernetes
 - pv
 - pvc
---

# 从零开始搭建一个完整的 Kubernetes 集群（二 持续化存储）

在上一篇[部署集群](/2019/02/21/create-full-kubernetes-1/)中部署的集群，距离完整的 kubernetes 集群，还缺乏持续化存储（也叫持久化数据卷）。pod可以声明单点的挂载目录，但是这样明显不适合集群的管理。所以在后续的部署中，可能会用到使用插件把复杂的数据卷（Volume）挂载进 namespace 里，比如 Ceph、NFS 、GlusterFS和对应的 rook、hankbook 等。为了避免过多的部署成本和因此造成的不熟悉，先使用 kubernetes 的原生pv声明模式。

## 概念

pv - PersistentVolume

PersistentVolume 是集群中已配置的一段网络存储。 pv是基于pod的存储机制，但具有独立于pod的生命周期。 

pvc - PersistentVolumeClaim

PersistentVolumeClaim 是用户存储的请求。 它类似于pod。 pods消耗节点资源，pvcs消耗pv资源。 可以请求特定的资源如cpu、内存等，也可以请求特定的大小和访问模式（读/写或只读等）。

StorageClass

StorageClass是存储类型，诸如 Ceph、GlusterFS、NFS 等等的网络存储插件，它是网络存储具体实现的声明。

## 简单例子

pv-pvc.yaml

```shell
apiVersion: v1
kind: PersistentVolume
metadata:
  name: www-root
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  hostPath:
    path: /var/www/wwwroot
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nginx-conf
spec:
  capacity:
    storage: 2Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  hostPath:
    path: /var/www/wwwroot/conf
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: www-root-c
spec:
  accessModes:
  - ReadWriteOnce
  dataSource: null
  resources:
    requests:
      storage: 5Gi
  volumeMode: Filesystem
  volumeName: www-root
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nginx-conf-c
spec:
  accessModes:
  - ReadWriteOnce
  dataSource: null
  resources:
    requests:
      storage: 1Gi
  volumeMode: Filesystem
  volumeName: nginx-conf
```

这里声明了两个个简单的local的pv，以wwwroot和wwwroot/conf为挂载点（因为wwwroot是我数据盘的挂载点），并且声明了对应的pvc

app.yaml

```shell l
apiVersion: v1
kind: Pod
metadata:
  name: frist-app
spec:
  containers:
  - image: nginx
    name: frist-app
    ports:
    - containerPort: 80
      protocol: TCP
    volumeMounts:
    - name: www-root
      mountPath: /var/www
    - name: nginx-conf
      mountPath: /etc/nginx/conf.d
  volumes:
  - name: www-root
    persistentVolumeClaim:
     claimName: www-root-c
  - name: nginx-conf
    persistentVolumeClaim:
     claimName: nginx-conf-c
```



## 开始部署

以部署一个简单的nginx pod为例

### STEP 1 创建

进入worker节点下的服务器

```shell
$ mkdir -p /var/www/wwwroot
$ cd /var/www/wwwroot
$ cat << EOF > index.html
> First App
> EOF
$ mkdir conf
$ cat << EOF > default.conf
> server {

    listen 80 default_server;
    listen [::]:80 default_server ipv6only=on;

    server_name localhost;
    root /var/www;
    index index.html index.htm;

    location / {
         try_files $uri $uri/ /index.php$is_args$args;
    }

    location ~ /\.ht {
        deny all;
    }
}
> EOF
```

### STEP 2 部署

把**例子**中保存的yaml文件部署起来

```shell
$ kubectl apply -f pv-pvc.yaml
$ kubectl apply -f app.yaml
```

### STEP 3 验证

```shell
$ kubectl exec -it frist-app -- /bin/bash
...
# 因为pod的ip是变化的，为了发现pod的集群内真实ip，需要使用下面的flag
$ kubectl get pods -o wide
...
frist-app 1/1  Running 0 26h  10.36.0.5   node1   <none>   <none>
...
# 其中10.36.0.5就是pod的ip，访问这个ip
$ curl 10.36.0.5
First App
```

至此完成了一个简单的nginx应用部署



章节：

- [从零开始搭建一个完整的 Kubernetes 集群（一 部署集群）](/2019/02/21/create-full-kubernetes-1/)
- [从零开始搭建一个完整的 Kubernetes 集群（二 持续化存储）](/2019/02/21/create-full-kubernetes-2/)
- [从零开始搭建一个完整的 Kubernetes 集群（三 helm）]()
- [从零开始搭建一个完整的 Kubernetes 集群（四 ingress以及nginx）]()



#### **[github地址](https://github.com/ConserveLee/quick-kubernetes-deploy) **

#### **如果对你有帮助，记得 fork 和 star， 欢迎留言**