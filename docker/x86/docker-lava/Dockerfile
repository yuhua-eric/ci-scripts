#FROM bitnami/minideb:unstable
#FROM centos:7
FROM bitnami/minideb
# need install jdk
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

# Install debian packages used by the container
# Configure apache to run the lava server
# Log the hostname used during install for the slave name
RUN echo 'lava-server lava-server/instance-name string lava-docker-instance' | debconf-set-selections \
 && echo 'locales locales/locales_to_be_generated multiselect C.UTF-8 UTF-8, en_US.UTF-8 UTF-8 ' | debconf-set-selections \
 && echo 'locales locales/default_environment_locale select en_US.UTF-8' | debconf-set-selections \
 && DEBIAN_FRONTEND=noninteractive install_packages \
 locales \
 postgresql \
 screen \
 sudo \
 wget \
 gnupg \
 vim \
 && service postgresql start \
 && wget http://images.validation.linaro.org/production-repo/production-repo.key.asc \
 && apt-key add production-repo.key.asc \
 && echo 'deb http://images.validation.linaro.org/production-repo/ sid main' > /etc/apt/sources.list.d/lava.list \
 && apt-get clean && apt-get update \
 && DEBIAN_FRONTEND=noninteractive install_packages \
 lava \
 && a2enmod proxy \
 && a2enmod proxy_http \
 && a2dissite 000-default \
 && a2ensite lava-server \
 && /stop.sh

RUN DEBIAN_FRONTEND=noninteractive install_packages \
    ser2net \
    u-boot-tools \
    python-setproctitle

RUN DEBIAN_FRONTEND=noninteractive install_packages \
    expect \
    ipmitool \
    ntp \
    tree \
    sshpass \
    htop \
    openjdk-8-jdk \
    nfs-common

# Create a admin user (Insecure note, this creates a default user, username: admin/admin)
RUN /start.sh \
 && echo "from django.contrib.auth.models import User; User.objects.create_superuser('admin', 'admin@localhost.com', 'admin12#$')" | lava-server manage shell \
 && /stop.sh

# Install latest
# RUN git config --global user.name "Docker Build" \
#  && git config --global user.email "qinsl0106@thundersoft.com" \
#  && git clone -b master http://192.168.67.56/qinsl0106/lava-dispatcher.git /root/lava-dispatcher \
#  && cd /root/lava-dispatcher \
#  && git checkout 2017.6 \
#  && git clone -b master http://192.168.67.56/qinsl0106/lava-server.git /root/lava-server \
#  && cd /root/lava-server \
#  && git checkout 2017.6 \
#  && echo "cd \${DIR} && dpkg -i *.deb" >> /root/lava-server/share/debian-dev-build.sh \
#  && sed -i "s#https://github.com/Linaro/#http://192.168.67.56/qinsl0106/#g" /root/lava-server/share/debian-dev-build.sh

# cherrypick our changes, but don't commit.
# RUN cd /root/lava-dispatcher && git cherry-pick 528f6a621602412e90c95a3d1eb327d0887a9b06 && git reset HEAD^

RUN DEBIAN_FRONTEND=noninteractive git clone -b master https://github.com/Linaro/lava-dispatcher.git /root/lava-dispatcher && \
    cd /root/lava-dispatcher && \
    git checkout 2017.6 && \
    git clone -b master https://github.com/Linaro/lava-server.git /root/lava-server &&\
    cd /root/lava-server && \
    git checkout 2017.6 && \
    echo "cd \${DIR} && dpkg -i *.deb" >> /root/lava-server/share/debian-dev-build.sh

COPY patches/pre_connect.diff /usr/local/bin/
RUN cd /root/lava-dispatcher && patch -p1 /usr/local/bin/pre_connect.diff

RUN /start.sh \
    && cd /root/lava-dispatcher && /root/lava-server/share/debian-dev-build.sh -p lava-dispatcher -b 2017.6 \
    && cd /root/lava-server && /root/lava-server/share/debian-dev-build.sh -p lava-server -b 2017.6 \
    && /stop.sh

# workaround to tell lava we have nfs
RUN mkdir /usr/sbin/exportfs

COPY configs/tftpd-hpa /etc/default/tftpd-hpa

RUN sed -i 's/LAVA_DB_SERVER="localhost"/LAVA_DB_SERVER="ci-db"/g' /etc/lava-server/instance.conf

EXPOSE 69/udp 80 5555 5556 3079

CMD /start.sh && /check.sh
