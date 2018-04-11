#!/bin/bash
sudo docker build -t [your_docker_registry]/kernelci/fileserver .

echo "start container command :"
echo "  sudo docker run -d -v ~/fileserver_data:/home/static -p 8083:8083 [your_docker_registry]/kernelci/fileserver"
