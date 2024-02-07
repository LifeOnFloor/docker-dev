#!/bin/bash

# Laravelプロジェクトの作成
composer create-project --prefer-dist laravel/laravel laravel

# プロジェクトディレクトリに移動
cd laravel

# .envファイルを作成
cp .env.example .env

# アプリケーションキーの生成
php artisan key:generate

# .envファイルのMongoDB用の設定を追加
cat <<EOF >>.env
MONGO_DB_HOST=127.0.0.1
MONGO_DB_PORT=27018
MONGO_DB_DATABASE=laravel
MONGO_DB_USERNAME=root
MONGO_DB_PASSWORD=password
EOF

# ルートディレクトリに戻る
cd ..

# Docker関連のディレクトリを作成
mkdir -p docker/php docker/nginx

# PHPのDockerfileを作成
cat <<EOF >>docker/php/Dockerfile
FROM php:8.2-fpm

COPY --from=composer /usr/bin/composer /usr/bin/composer
COPY ./docker/php/php.ini /usr/local/etc/php/php.ini

RUN apt-get update \\
    && apt-get install -y git zip unzip \\
    && pecl install mongodb \\
    && docker-php-ext-enable mongodb

WORKDIR /var/www/html
EOF

# PHPの設定ファイルを作成
cat <<EOF >>docker/php/php.ini
zend.exception_ignore_args = off
expose_php = on
max_execution_time = 30
max_input_vars = 1000
upload_max_filesize = 64M
post_max_size = 128M
memory_limit = 256M
error_reporting = E_ALL
display_errors = on
display_startup_errors = on
log_errors = on
error_log = /var/log/php/php-error.log
default_charset = UTF-8
extension = 'mongodb.so'

[Date]
date.timezone = Asia/Tokyo

[Assertion]
zend.assertions = 1

[mbstring]
mbstring.language = Japanese
EOF

# NginxのDockerfileを作成
cat <<EOF >docker/nginx/Dockerfile
FROM nginx:1.21-alpine

COPY ./docker/nginx/default.conf /etc/nginx/conf.d/default.conf

ENV TZ Asia/Tokyo

WORKDIR /var/www/html
EOF

# Nginxの設定ファイルを作成
cat <<EOF >docker/nginx/default.conf
server {
    listen 80;
    index index.php index.html;
    server_name localhost;
    error_log  /var/log/nginx/error.log;
    access_log /var/log/nginx/access.log;
    root /var/www/html/public;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass php:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
    }
}
EOF

# docker-compose.ymlファイルを作成
cat <<EOF >docker-compose.yml
version: '3.8'

services:
  php:
    container_name: php
    build:
      context: .
      dockerfile: ./docker/php/Dockerfile
    ports:
      - 8080:80
    volumes:
      - ./laravel:/var/www/html
      - /var/www/html
    networks:
      - net

  nginx:
    container_name: nginx
    depends_on:
      - php
    build:
      context: .
      dockerfile: ./docker/nginx/Dockerfile
    ports:
      - 8081:80
    volumes:
      - ./laravel:/var/www/html
      - /var/www/html
      - ./docker/nginx/default.conf:/etc/nginx/conf.d/default.conf
    networks:
      - net
  
  mongo:
    container_name: mongo
    image: mongo:7.0-jammy
    environment:
      TZ: Asia/Tokyo
      LANG: ja_JP.UTF-8
      MONGO_INITDB_ROOT_USERNAME: root
      MONGO_INITDB_ROOT_PASSWORD: password
    ports:
      - 27018:27017
    volumes:
      - ./laravel/mongodb:/data/db
      - /data/db
    working_dir: /data/db
    networks:
      - net

networks:
  net:
    driver: bridge
EOF

# dockerコンテナを起動
docker-compose up -d --build

# MongoDB用のパッケージをインストール
docker-compose exec php composer require --prefer-dist mongodb/laravel-mongodb

# セットアップ完了メッセージを表示
echo "Setup complete! Access to http://localhost:8081/ to check the Laravel application."
