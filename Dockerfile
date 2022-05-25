FROM php:apache

COPY src/ /var/www/html/

RUN chown www-data:www-data /var/www/html/upload

EXPOSE 80