# docker compile server

```
PORT=10106
USER=qinsl0106
USER_DIR=~/estuary/qinsl0106

docker run -d -p ${PORT}:22 \
       --memory="16g" --cpus="8" \
       --name ${USER}-hp-docker \
       --restart=always \
       -v ${USER_DIR}:/home/ts \
       [your_docker_registry]/kernelci/estuary-build

echo "Please login by this command:"
echo "ssh ts@192.168.67.123 -p ${PORT}"
```

# change source list
```
vi /etc/apt/source.list

remove 192.168.67.107 mirror info
```

# install package
```
apt-get install -yq ipmitool
```
