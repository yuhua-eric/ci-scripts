FROM debian:9

# Add services helper utilities to start and stop LAVA
COPY scripts/* ./
COPY patches/* /usr/local/bin/

# perpare for postgressql
# explicitly set user/group IDs
RUN groupadd -r postgres --gid=999 && useradd -r -g postgres --uid=999 postgres
RUN mkdir -p /var/run/postgresql && chown -R postgres:postgres /var/run/postgresql && chmod 2777 /var/run/postgresql
ENV PGDATA /var/lib/postgresql/data
RUN mkdir -p "$PGDATA" && chown -R postgres:postgres "$PGDATA" && chmod 777 "$PGDATA" # this 777 will be replaced by 700 at runtime (allows semi-arbitrary "--user" values)
VOLUME /var/lib/postgresql/data

RUN apt-key adv --recv-key --keyserver keyserver.ubuntu.com E13D88F7E3C1D56C 

RUN apt-get update

# Install debian packages used by the container
# Configure apache to run the lava server
# Log the hostname used during install for the slave name
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    locales \
    postgresql \
    screen \
    sudo \
    wget \
    gnupg \
    vim \
    apt-transport-https \
    apache2 
 
RUN wget https://images.validation.linaro.org/staging-repo/staging-repo.key.asc && \
    sudo apt-key add staging-repo.key.asc && \
    echo 'deb https://images.validation.linaro.org/production-repo stretch-backports main' > /etc/apt/sources.list.d/lava.list && \
    apt-get clean && apt-get update 

RUN /etc/init.d/apache2 start && \
    /etc/init.d/postgresql start && \
    DEBIAN_FRONTEND=noninteractive aptitude install -y -t stretch-backports python-magic && \
    DEBIAN_FRONTEND=noninteractive aptitude install -y -t stretch-backports python-django-kvstore=1.0-2 && \
    DEBIAN_FRONTEND=noninteractive aptitude install -y -t stretch-backports lava-server=2016.12-2 && \
    DEBIAN_FRONTEND=noninteractive aptitude install -y -t stretch-backports lava=2016.12-2 && \
    a2enmod proxy && \
    a2enmod proxy_http  && \
    a2dissite 000-default && \ 
    a2ensite lava-server

RUN DEBIAN_FRONTEND=noninteractive apt-get install -y \
    ser2net \
    u-boot-tools \
    python-setproctitle \
    expect \
    ipmitool \
    ntp \
    tree \
    sshpass \
    htop \
    openjdk-8-jdk

RUN /start.sh \
    && echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'admin@localhost.com', 'admin12#$')" | lava-server manage shell \
    && /stop.sh

# Install latest
RUN DEBIAN_FRONTEND=noninteractive git clone -b master https://github.com/Linaro/lava-dispatcher.git /root/lava-dispatcher && \
    cd /root/lava-dispatcher && \
    git checkout 2017.6 && \
    git clone -b master https://github.com/Linaro/lava-server.git /root/lava-server &&\
    cd /root/lava-server && \
    git checkout 2017.6 && \
    echo "cd \${DIR} && dpkg -i *.deb" >> /root/lava-server/share/debian-dev-build.sh 

COPY patches/pre_connect.diff /usr/local/bin/
RUN cd /root/lava-dispatcher && patch -p1 /usr/local/bin/pre_connect.diff

RUN DEBIAN_FRONTEND=noninteractive /start.sh \
    && cd /root/lava-dispatcher && /root/lava-server/share/debian-dev-build.sh -p lava-dispatcher -b 2017.6 \
    && cd /root/lava-server && /root/lava-server/share/debian-dev-build.sh -p lava-server -b 2017.6 \
    && /stop.sh


# workaround to tell lava we have nfs
#RUN mkdir -p /usr/sbin/exportfs

COPY configs/tftpd-hpa /etc/default/tftpd-hpa

RUN sed -i 's/LAVA_DB_SERVER="localhost"/LAVA_DB_SERVER="ci-db"/g' /etc/lava-server/instance.conf

EXPOSE 69/udp 80 5555 5556 3079

CMD /start.sh && /check.sh
