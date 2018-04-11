# nginx fileserver Docker Container

## Building
To build an image locally, execute the following from the directory you cloned the repo:

```
sudo docker build -t [your_docker_registry]/kernelci/fileserver .
```

## Running
To run the image from a host terminal / command line execute the following:

```
sudo docker run -d -v ~/fileserver_data:/home/static -p 8083:8083 [your_docker_registry]/kernelci/fileserver
```
