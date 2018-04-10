# CI 脚本库

本库为CI的脚本库，包含CI流程脚本。以及安装相关的一些配置.

```
.
├── test-scripts              # 测试任务相关脚本
├── build-iso-scripts             # 自动安装ISO相关脚本
├── build-scripts                 # 编译任务相关脚本
├── configs                       # CI环境配置文件
├── deploy-scripts                # 部署相关脚本
├── docker                        # 主要服务的dockerfile
├── jenkins-job-config            # jenkins任务配置备份
├── lava_config                   # lava 关键配置备份
├── pipeline                      # jenkins pipeline 任务脚本
├── README.md
└── scripts                       # 一些其他工具脚本
```


# CI访问入口:

+ jenkins: http://120.31.149.194:18080

+ lava : http://120.31.149.194:180

# 版本相关内容

CI 中包含部分和开发版本耦合内容:

+ 编译依赖源mirror (192.168.1.107)，部署依赖源mirror(192.168.1.107)

+ iso和pxe安装的配置文件 [auto-install](configs/auto-install), 其中包含了自动安装的kickstart文件，随着版本的变化，以及依赖的包的变化，可能需要调整
