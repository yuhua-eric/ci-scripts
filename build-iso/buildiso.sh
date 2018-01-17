#!/bin/bash -ex
# depends:
# ubuntu
# apt-get install genisoimage
# apt-get install xorriso
# centos
# yum install genisoimage mkisofs
# wget https://www.gnu.org/software/xorriso/xorriso-1.4.8.tar.gz
# tar -xzvf xorriso-1.4.8.tar.gz
# ./configure && make && make install


./centos_mkautoiso.sh
./ubuntu_mkautoiso.sh
