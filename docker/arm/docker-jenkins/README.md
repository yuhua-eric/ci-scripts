# jenkins run

```
WORK_HOME=~/estuary
docker run --rm -d -p 2002:8080 -p 2003:50000 --name myjenkins -v ${WORK_HOME}/jenkins_home/:/var/jenkins_home [your_docker_registry]/public/jenkins:2.32.3
```
