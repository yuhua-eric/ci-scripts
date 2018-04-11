# 自动部署

放自动部署相关脚本。主要针对 pxe 方式和 ISO方式

## 主要脚本
+ do_deploy.sh 自动部署入口脚本，由jenkins的部署任务调用

+ deploy.py 自动部署实现，通过ipmi/pexpect实现

## tftp/nfs目录结构
tftp和nfs 都对应同一个目录，也就是 ~/estuary/tftp_nfs_data

```
# iso 目录结构
root@ubuntu:~/estuary/tftp_nfs_data/iso_install/arm64/estuary# ls
daily_20180314  daily_20180316  daily_20180318  daily_20180321  estuary_284e2da  estuary_b650e39  v3.1  v5.1-rc0
daily_20180315  daily_20180317  daily_20180319  daily_20180322  estuary_a82aec7  estuary_c513701  v5.0

```
iso安装相对依赖较少，只需要将对应的自动安装的iso放到对应的版本目录中。

```
# pxe 目录结构
root@ubuntu:~/estuary/tftp_nfs_data/pxe_install/arm64/estuary# ls
daily_20180327  template  v3.1  v5.0
```

pxe安装依赖相对较多。http服务，源镜像，以及NBP文件，grub配置。这些都零散的放在各个机器上。  
因此有一个template目录用来存放这些文件的模版.
