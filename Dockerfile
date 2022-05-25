FROM php:apache

COPY src/ /var/www/html/

RUN apt-get update && apt-get upgrade -y

RUN chown www-data:www-data /var/www/html/upload

EXPOSE 80