FROM nginx:1.28-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY public/ /usr/share/nginx/html/
COPY entrypoint.sh /docker-entrypoint.d/40-web-config.sh
RUN chmod +x /docker-entrypoint.d/40-web-config.sh
EXPOSE 80
