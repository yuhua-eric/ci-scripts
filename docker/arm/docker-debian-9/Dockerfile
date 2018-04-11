FROM openestuary/debian
RUN wget -q http://drbl.nchc.org.tw/GPG-KEY-DRBL -O- | apt-key add -
RUN aptitude update && aptitude upgrade -y
RUN sed s/jessie/stretch/ /etc/apt/sources.list | tee /etc/apt/sources.list 
RUN aptitude update && aptitude dist-upgrade -y
