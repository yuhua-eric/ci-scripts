FROM openestuary/ubuntu

RUN apt-get update && apt-get install -yq nginx vim wget dialog net-tools procps

# Copy a configuration file from the current directory
RUN rm -v /etc/nginx/sites-enabled/*
ADD configs/fileserver /etc/nginx/sites-enabled/

RUN rm -v /etc/nginx/nginx.conf
ADD configs/nginx.conf /etc/nginx/

RUN mkdir -p /home/static/ && chmod -R 777 /home/static/ && chown -R www-data /home/static/
VOLUME ["/home/static/"]
EXPOSE 8083

COPY scripts/start-container.sh /usr/bin/

CMD ["/bin/bash", "--" , "/usr/bin/start-container.sh" ]
