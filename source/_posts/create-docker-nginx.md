---
title:  使用laradock在一台服务器部署多个Web Server
date: 2018-11-30 19:06:47
abstract: 10分钟如何利用容器搭建一个多软件环境服务器
categories: docker
tags:
 - develop
 - docker
 - laradock
 - nginx
 - laraval

---

# 	前言



### 为什么使用docker？

部署快 性能好



### 安全性高

容器与宿主机完全隔离，默认情况下不能相互访问。



### 同时支持多版本软件



可以支持多版本PHP、Node等环境共存



# 	目的：

## 搭建laravel和node环境，部署多个web server并上线

话不多说，直接上步骤。



### STEP 1 安装docker

```
curl -sSL https://get.daocloud.io/docker | sh
## 安装docker
```

Centos7 请执行这步

```
yum install -y docker-engine 
```

ubuntu 请执行这步​                   

```
sudo apt-get install -y -q docker-engine
```



### STEP 2 安装docker-compose （ubuntu 请注意权限问题）

```
curl -L https://get.daocloud.io/docker/compose/releases/download/1.13.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose
```



### STEP 3 下载laradock 

请确保git 可用

```
git clone https://github.com/Laradock/laradock.git
mkdir -p wwwroot/data  # 创建网站目录
cd laradock
cp env-example .env
vi .env
```

#### .env 配置说明

APP_CODE_PATH_HOST=../wwwroot

DATA_PATH_HOST=../wwwroot/data

#### WORKSPACE 配置项

```
NODE=true
YARN=true
```

#### PHP_FPM配置说明

```
PHP_FPM_INSTALL_XDEBUG=false
PHP_FPM_INSTALL_MONGO=false
PHP_FPM_INSTALL_MSSQL=false
PHP_FPM_INSTALL_SOAP=false
PHP_FPM_INSTALL_ZIP_ARCHIVE=true
PHP_FPM_INSTALL_BCMATH=true
PHP_FPM_INSTALL_PHPREDIS=true
PHP_FPM_INSTALL_MEMCACHED=false
PHP_FPM_INSTALL_OPCACHE=false
PHP_FPM_INSTALL_EXIF=true
PHP_FPM_INSTALL_AEROSPIKE=false
PHP_FPM_INSTALL_MYSQLI=false
PHP_FPM_INSTALL_TOKENIZER=false
PHP_FPM_INSTALL_INTL=false
PHP_FPM_INSTALL_GHOSTSCRIPT=false
PHP_FPM_INSTALL_LDAP=false
PHP_FPM_INSTALL_SWOOLE=false
```



### STEP 4 修改dns以及端口

因为node的原因，没法全挂在80端口上。所以每个项目使用一个端口，再用 Nginx  配置了一个多服务结构，根据访问域名转发请求，达到通过不同的域名来访问不同的Web Server的效果。

> example structure

![大概流程,网上抄的](/assets/docker-nginx/大概流程,网上抄的.png)



去域名管理商那里分配你的域名，当然都是 A 记录并全部解析到你的 云主机公网 IP 上。

另外一个准备就是修改你所有的 Web Server 的端口，可以按你的爱好设置，但是不要占用 80 以及 443 端口



### STEP 5 新建forward.conf

切换到你的**nginx 配置目录**

> cd nginx/sites

这里要说明 nginx 是拥有 Include 机制的，他会自动加载 sites 目录下的所有 _.conf_（默认配置下）  ，所以我们并不需要修改 nginx.conf 文件。我们接下来需要在 sites 目录下创建一系列的配置文件，文件名请使用你相应的工程名

**example:  yourname.conf**

让我们编写详细的转发规则

**新建一份forward.conf**

```
// 假设我已经将这个服务的端口改成了5000端口
// 当nginx捕获到访问域名为lees.work的时候
// 就会转发到本地的5000端口
server{
    listen 80;
    listen [::]:80;

    # For https
    # listen 443 ssl;
    # listen [::]:443 ssl ipv6only=on;
    # ssl_certificate /etc/nginx/ssl/default.crt;
    # ssl_certificate_key /etc/nginx/ssl/default.key;

    server_name lees.work www.lees.work;
    location / {
        # proxy_http_version 1.1;
        proxy_set_header Connection "";
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_set_header X-NginX-Proxy true;
        proxy_pass http://127.0.0.1:5000$request_uri;
        proxy_redirect off;
    }
}
```

如果你需要转发 HTTPS，请复制一份上面的内容粘贴到下面，修改监听端口为 443，转发端口就是你监听的 https 端口！



### STEP 6 修改yourname.conf

**新建一份yourname.conf然后修改成**

```
server {

    listen 5000;
    listen [::]:5000;

    # For https
    # listen 443 ssl;
    # listen [::]:443 ssl ipv6only=on;
    # ssl_certificate /etc/nginx/ssl/default.crt;
    # ssl_certificate_key /etc/nginx/ssl/default.key;

    server_name localhost:5000;
    root /var/www/yourname(你的项目目录名)/public;
    index index.php index.html index.htm;

    location / {
         try_files $uri $uri/ /index.php$is_args$args;
    }

    location ~ \.php$ {
        try_files $uri /index.php =404;
        fastcgi_pass php-upstream;
        fastcgi_index index.php;
        fastcgi_buffers 16 16k;
        fastcgi_buffer_size 32k;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        #fixes timeouts
        fastcgi_read_timeout 600;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    location /.well-known/acme-challenge/ {
        root /var/www/letsencrypt/;
        log_not_found off;
    }

    error_log /var/log/nginx/laravel_error.log;
    access_log /var/log/nginx/laravel_access.log;
}

```

> TIPS:一个坑

laradock下docker-compose运行nginx 和 FPM 的默认启动用户都是 1000,所以你的网站根目录请务必修改所属者为 1000，否则laravel会出现权限问题！



### STEP 7 Repeat

重复 6 7 步骤，创建所有你需要的项目配置



### STEP 8 修改dockerfile、docker-composer.yml、.env

> cd ..
>
> vi  dockerfile

```
EXPOSE 80 443 5000
```

> cd ..
>
> vi  docker-compose.yml

```
### NGINX Server #########################################
ports:
        - "${NGINX_HOST_新端口名_PORT}:5000"
```

> vi  .env

```
### NGINX #################################################
NGINX_HOST_新端口名_PORT=5000

最后添加
DB_HOST=mysql
REDIS_HOST=redis
QUEUE_HOST=beanstalkd
```



### STEP 9 启动 nginx redis mysql

```
docker-compose up -d --build nginx redis mysql
```

如果出现报错，仔细查看信息

```
docker-compose logs nginx
```

一般都是因为配置文件格式错误。

只重启nginx（比如修改了配置文件）

```
docker-compose restart nginx
```

可以根据自己需要自行启动 nginx/apache/mysql/phpmyadmin/redis 等   



### STEP 10 工作空间

进入工作空间前，请确认环境已经启动     ​                

```
docker-compose exec workspace bash
composer global require "laravel/installer"
laravel new yourname
...
#修改你的lavavel配置、连接数据库、新建hexo项目、新建vue项目等

```

#### 需要注意的是：

由于数据库的数据是映射到 `wwwroot/data` 目录，    

所以在`.env` 修改数据库密码，即使重新构建也无效。 

如需强制更改 请删除`wwwroot/data` 里面对应数据库的数据。

日常修改密码，请使用`bash` 或者 `phpmyadmin`



### STEP 11 运行网页

打开你的网站吧，应该可以正常运行了！以后新增 Server 其实也只要增加一个对应的 conf 文件,可以很方便的横向扩展，并且整个网站访问起来也会比较美观！



example:http://lees.work

