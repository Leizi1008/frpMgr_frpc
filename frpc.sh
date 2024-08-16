#!/bin/bash  
  
# 定义安装目录和临时文件路径  
INSTALL_DIR="/root/frpc"  
TEMP_FILE="/tmp/frp.zip"  
SERVICE_FILE="/etc/systemd/system/frpc.service"  
  
# 检查unzip是否已安装  
if ! command -v unzip &> /dev/null; then  
    echo "unzip未安装，正在安装..."  
  
    # 尝试使用lsb_release来确定Debian/Ubuntu系统  
    if [ -f /etc/lsb-release ] && grep -qi ubuntu /etc/lsb-release; then  
        sudo apt-get update  # 更新包索引，可选但推荐  
        sudo apt-get install -y unzip  
        if [ $? -ne 0 ]; then  
            echo "使用apt-get安装unzip失败，请手动安装后重试。"  
            exit 1  
        fi  
    # 对于RedHat系列，检查yum或dnf  
    elif command -v yum &> /dev/null; then  
        sudo yum install -y unzip  
        if [ $? -ne 0 ]; then  
            echo "使用yum安装unzip失败，请手动安装后重试。"  
            exit 1  
        fi  
    # 对于使用dnf的系统（如Fedora），虽然yum通常仍然可用，但可以直接调用dnf  
    elif command -v dnf &> /dev/null; then  
        sudo dnf install -y unzip  
        if [ $? -ne 0 ]; then  
            echo "使用dnf安装unzip失败，请手动安装后重试。"  
            exit 1  
        fi  
    else  
        echo "无法确定系统类型或不支持的包管理器，请手动安装unzip。"  
        exit 1  
    fi  
fi 
  
# 提示用户输入下载链接  
echo "【请输入Frpc文件下载地址：】"  
read DOWNLOAD_URL  
  
# 检查环境  
if [ ! -d "$INSTALL_DIR" ]; then  
    echo "创建目录 $INSTALL_DIR"  
    sudo mkdir -p "$INSTALL_DIR"  
else  
    echo "目录 $INSTALL_DIR 已存在"  
fi  
  
# 下载FRP压缩包  
echo "正在下载FRP压缩包..."  
wget -O "$TEMP_FILE" "$DOWNLOAD_URL"  
  
# 检查下载是否成功  
if [ $? -ne 0 ] || [ ! -f "$TEMP_FILE" ]; then  
    echo "下载失败，请检查URL是否正确或网络连接是否正常。"  
    exit 1  
fi  
  
# 解压并提取必要的文件  
echo "解压并提取必要的文件..."  
unzip -o "$TEMP_FILE" client/frpc client/frpc.ini -d "$INSTALL_DIR"  
  
# 检查是否成功解压了需要的文件  
if [ ! -f "$INSTALL_DIR/frpc" ] || [ ! -f "$INSTALL_DIR/frpc.ini" ]; then  
    echo "解压失败或未找到必要的文件。"  
    exit 1  
fi  
  
# 清理临时文件  
echo "清理临时文件..."  
rm "$TEMP_FILE"  
  
# 创建systemd服务文件  
cat > "$SERVICE_FILE" <<EOF  
[Unit]  
Description=FRP Client Service  

# 指定服务启动顺序，在network.target和syslog.target之后启动  
After=network.target syslog.target  
# 表示这个服务想要启动network.target，但并不会等待它完成  
Wants=network.target 
  
[Service]  
Type=simple  
User=root  # 修改用户为root  
ExecStart=$INSTALL_DIR/frpc -c $INSTALL_DIR/frpc.ini  
Restart=on-failure  
 
 # 监控服务是否成功启动，如果失败则等待5秒后重新启动  
Restart=always  
# 重启之间的等待时间为5秒  
RestartSec=5  
# 取消启动尝试的限制，即不限制服务在特定时间间隔内的重启次数  
StartLimitInterval=0  

[Install]  
WantedBy=multi-user.target  
EOF  
  
# 给予systemd服务文件适当的权限（755可能对于服务文件来说过于宽松，但这里按要求设置）  
sudo chmod 755 "$SERVICE_FILE"  
# 注意：通常服务文件权限设置为644更合适，但这里保持为755以满足特定要求  
  
# 重新加载systemd配置  
echo "重新加载systemd配置..."  
sudo systemctl daemon-reload  
  
# 启动FRP服务  
echo "启动FRP服务..."  
sudo systemctl start frpc  
  
# 设置开机自启  
echo "设置FRP服务开机自启..."  
sudo systemctl enable frpc  
  
# 检查FRP服务状态  
echo "检查FRP服务状态..."  
sudo systemctl status frpc  
  
# 脚本结束  
echo "FRP客户端安装、配置、启动和开机自启设置完成。"