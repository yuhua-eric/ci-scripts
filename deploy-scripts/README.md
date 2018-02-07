# 自动部署

放自动部署相关脚本。主要针对 pxe 方式和 ISO方式

## 主要脚本
+ do_deploy.sh 自动部署入口脚本，由jenkins的部署任务调用

+ deploy.py 自动部署实现，通过ipmi/pexpect实现
