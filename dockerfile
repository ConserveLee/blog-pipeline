FROM node:13.1.0
WORKDIR /var/www/

RUN npm install hexo-cli -g

RUN hexo init blog

WORKDIR /var/www/blog
ADD . /var/www/blog/

RUN npm install \
&& npm install --save hexo-helper-live2d \
&& npm install hexo-renderer-pug --save

EXPOSE 4000