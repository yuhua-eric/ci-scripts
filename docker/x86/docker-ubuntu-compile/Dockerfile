FROM ubuntu:14.04

MAINTAINER  "qinsl0106 zhangbp0704"

ENV http_proxy ${http_proxy:-}
ENV https_proxy ${https_proxy:-}
ENV no_proxy ${no_proxy:-}
ENV USER root

RUN apt-get -qq update

RUN echo "dash dash/sh boolean false" | debconf-set-selections && \
    dpkg-reconfigure -p critical dash

# install all of the tools and libraries that we need.
RUN apt-get update && \
    apt-get install -y git-core gnupg flex bison gperf build-essential \
  zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 \
  lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z-dev ccache \
  libgl1-mesa-dev libxml2-utils xsltproc unzip

# openjdk-8-jdk
RUN apt-get install -y -q openjdk-8-jdk

# Extras that android-x86.org and android-ia need
RUN apt-get update && apt-get install -y gettext python-libxml2 yasm bc
RUN apt-get update && apt-get install -y squashfs-tools genisoimage dosfstools mtools

# install useful tools
RUN apt-get install -y htop tig vim  zip unzip python-imaging ipmitool sshpass

# install en language for build BP
RUN apt-get install -y language-pack-en-base
ENV LANG en_US.UTF-8

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY repo /usr/local/bin/
RUN chmod 755 /usr/local/bin/*

RUN apt-get update && apt-get install -y software-properties-common python-software-properties

#fix TAB can't completion
RUN apt-get update && apt-get install -y bash-completion

# add sshd
RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
RUN echo 'root:screencast' | chpasswd
# for 14.04
RUN sed -i 's/PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# SSH login fix. Otherwise user is kicked off after login
RUN sed 's@session\s*required\s*pam_loginuid.so@session optional pam_loginuid.so@g' -i /etc/pam.d/sshd

ENV NOTVISIBLE "in users profile"
RUN echo "export VISIBLE=now" >> /etc/profile

VOLUME /home/ts

COPY gosu-amd64 /usr/local/bin/
COPY start.sh /start.sh
COPY template_home/* /tmp/

#cp usefull python scripts
COPY *.py /usr/bin/

#install usefull tool
RUN apt-get update && apt-get install -y msmtp mutt lftp gitk

RUN apt-get install -f -y
RUN apt-get autoclean
RUN apt-get autoremove
EXPOSE 22
CMD ["/start.sh"]
