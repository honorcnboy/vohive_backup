VoHive 是一个面向移远 4G 模组的管理平台，适合拿移远 EC20 这类 USB 模组做：
- 网页/Bot收发短信
- 多卡统一管理
- 实体 ESIM/eUICC 管理（加卡，切卡，删卡）
- 基于手机卡流量的代理池
- TelegramBot / 飞书Bot / QQBot 远程控制
- 在条件满足时启用 VoWiFi
- 通过 /vocall 发起 VoWiFi 模拟外呼
- 更重要的是，这些功能免费
/vocall 这个功能比较适合：
- CTE UK/CMLINK UK 这类需要本地拨打运营商电话才能激活的号码
- 其他需要定期拨打一通电话做保号的海外号码

# 一、适用环境
硬件
推荐：
> EC20CEFAG
> EC20CEFHLG
可以小黄鱼几十块买到


要求：

> 设备具备 SIM 卡槽
> 或搭配带SIM卡槽的USB底板


系统：
建议使用 Linux：
> Debian / Ubuntu
> 树莓派
> NAS


# 二、部署前先禁用宿主机 ModemManager
这一步很重要。


很多发行版会默认启动 ModemManager，它会抢占 /dev/ttyUSB* AT端口，导致模组识别、短信、AT 口访问异常。


先检查：
```
systemctl status ModemManager
```
如果它在运行，直接禁用：
```
sudo systemctl stop ModemManager
sudo systemctl disable ModemManager
sudo systemctl mask ModemManager
```
再次确认：
```
systemctl status ModemManager
```


注意：


即使你后面使用 Docker，这一步也必须在宿主机上做。

# 三、可选：把模组切到更合适的 USBNET 模式


如果你确认模组当前模式不对，可以执行：
```
sudo apt update
sudo apt install -y socat
```
```
echo 'AT+QCFG="usbnet",0;+CFUN=1,1' | sudo socat - /dev/ttyUSB2,crnl
```
说明：


AT+QCFG="usbnet",0：切到常见的 QMI 模式


AT+CFUN=1,1：重启模组


/dev/ttyUSB2 只是示例，实际 AT 口请按你的设备调整


# 四、部署方式一

一键安装：
```
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/install.sh | bash
```
指定版本：
```
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/install.sh | bash -s -- --version v1.0.0
```
仅安装二进制（不安装 systemd）：
```
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/install.sh | bash -s -- --no-systemd
```
卸载：
```
curl -fsSL https://raw.githubusercontent.com/iniwex5/vohive-release/master/uninstall.sh | bash
```


默认安装目录（便携部署）


二进制：/opt/vohive/bin/vohive


配置：/opt/vohive/config/config.yaml


数据：/opt/vohive/data


日志目录：/opt/vohive/logs

# 五、部署方式二：
Docker / Docker Compose
1. 创建目录
```
mkdir -p vohive/{config,data,logs}
cd vohive
```
2. 创建配置文件
新建 config/config.yaml：
```
server:
  port: 7575
  debug: false

web:
  username: admin
  password: admin123
```
3. 创建 docker-compose.yml
```
services:
  vohive:
    image: iniwex/vohive:latest
    container_name: vohive
    restart: unless-stopped
    network_mode: host
    privileged: true
    volumes:
      - ./config:/app/config
      - ./data:/app/data
      - ./logs:/app/logs
    environment:
      - TZ=Asia/Shanghai
      - CONFIG_PATH=/app/config/config.yaml
    devices:
      - /dev:/dev
```
4. 启动
```
docker compose up -d
```
5. 访问后台
http://你的服务器IP:7575


注意：


Docker 部署也要先禁用宿主机 ModemManager


这里用了 privileged、/dev 透传和 host network，这是因为程序需要直接接管模组设备

# 六、机器人常用命令

/list：查看设备列表
/sms 设备ID：查看最近短信
/send 设备ID 号码 内容：发送短信
/rotate 设备ID：切换 IP
/esim 设备ID：查看 eSIM profile
/switch 设备ID 序号或 ICCID：切换 eSIM profile
/vocall 设备ID 号码：发起 VoWiFi 模拟呼叫

# 七、补充说明


VoWiFi 不是只要有网就一定能用，还取决于运营商、号码状态和网络环境要求


如果你的需求只是短信、代理池、多模组管理，不折腾 VoWiFi 也可以先用起来


本程序已禁止国内运营商卡发起VoWifi，请遵纪守法。
