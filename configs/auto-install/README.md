# 自动安装 kickstart 和 preseed 配置

CI 环境中部署系统，依赖与pxe或者 iso的自动安装。因此需要针对性的编写 kickstart 或 preseed 配置。

> pxe 配置和 iso 配置类似，但存在区别。

ISO 配置会用于编译生成自动安装的 ISO. 

PXE 配置只用于参考,具体pxe配置在对应的 tftp 配置
