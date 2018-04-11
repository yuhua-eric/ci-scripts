FROM [your_docker_registry]/public/ubuntu:14.04
MAINTAINER Qin Shulei <qinsl0106@thundersoft.com>

COPY binarys/dumb-init /usr/local/bin/

RUN cd /etc/apt/ && mv sources.list sources.list.old
COPY configs/sources.list /etc/apt/sources.list

RUN apt-get update && apt-get install -yq nginx vim wget dialog net-tools

# Copy a configuration file from the current directory
RUN rm -v /etc/nginx/sites-enabled/*
# ADD default /etc/nginx/sites-enabled/
ADD configs/fileserver /etc/nginx/sites-enabled/

# RUN rm -v /etc/nginx/nginx.conf
# ADD nginx.conf /etc/nginx/

RUN mkdir -p /home/static/ && chmod -R 777 /home/static/ && chown -R www-data /home/static/
VOLUME ["/home/static/"]
EXPOSE 8083

COPY scripts/start-container.sh /usr/bin
CMD ["/usr/local/bin/dumb-init", "--" , "/usr/bin/start-container.sh" ]
