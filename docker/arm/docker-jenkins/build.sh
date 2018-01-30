#!/bin/bash
sudo docker build -t [your_docker_registry]/kernelci/jenkins .

echo "start container command :"
echo "  sudo docker run -d -v ~/jenkins_data:/home/static -p 8083:8083 [your_docker_registry]/kernelci/jenkins"
