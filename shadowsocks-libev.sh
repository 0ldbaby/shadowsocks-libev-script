#!/usr/bin/env bash
##########################################
#
#
#       针对Centos7+系统，交互式安装！
#
#
##########################################

# 与用户交互获得ss配置信息
getSsInfo(){
    ss_method=(
		"-----Bin-----"
		camellia-128-cfb
		camellia-192-cfb
		camellia-256-cfb
		bf-cfb
		salsa20
		chacha20
		chacha20-ietf
		chacha20-ietf-poly1305
		xchacha20-ietf-poly1305
	)
	for((i=1;i<${#ss_method[@]};i++))
	do
		echo -e "$i：\e[31m ${ss_method[i]} \e[0m"
	done
    read -p "请选择加密方式(1-9回车默认xchacha20-ietf-poly1305)：" method
	read -p "请输入ss端口号(1024-65535回车默认12345)：" port
	read -p "请输入ss密码(回车默认123456)：" password
	if [ ! -n "$method" ];then
		method=9
	fi
	if [ ! -n "$port" ];then
		port=12345
	fi
	if [ ! -n "$password" ];then
		password=123456
	fi
    which "curl" > /dev/null
    if [ $? -ne 0 ]
    then
      yum install curl
    fi
      #获取本机外网ip
    ip=`curl -s icanhazip.com`
}

installNeed(){
    yum install -y epel-release
    yum install -y git gcc gettext autoconf libtool automake make pcre-devel asciidoc xmlto c-ares-devel libev-devel libsodium-devel mbedtls-devel
}

installShadowsocks(){
    cd /usr/local/src
    git clone https://github.com/shadowsocks/shadowsocks-libev.git
    cd /usr/local/src/shadowsocks-libev
    git submodule update --init --recursive
    sh autogen.sh
    ./configure --disable-documentation
    make
    make install
}

createConfig(){
    mkdir -p /etc/shadowsocks-libev
    mkdir -p ~/shadowsocks
    echo '{' > /etc/shadowsocks-libev/config.json
    echo "\"server\":[\"::1\", \"0.0.0.0\"]," >> /etc/shadowsocks-libev/config.json
    echo '"mode":"tcp_and_udp",' >> /etc/shadowsocks-libev/config.json
    echo "\"server_port\":$port," >> /etc/shadowsocks-libev/config.json
    echo '"local_port":1080,' >> /etc/shadowsocks-libev/config.json
    echo "\"password\":\"$password\"," >> /etc/shadowsocks-libev/config.json
    echo '"timeout":86400,' >> /etc/shadowsocks-libev/config.json
    echo "\"method\":\"${ss_method[method]}\"" >> /etc/shadowsocks-libev/config.json
    echo '}' >> /etc/shadowsocks-libev/config.json
    echo "本机IP：$ip" > ~/shadowsocks/ss.config
    echo "连接端口：$port" >> ~/shadowsocks/ss.config
    echo "连接密码：$password" >> ~/shadowsocks/ss.config
    echo "加密方式：${ss_method[method]}" >> ~/shadowsocks/ss.config
    echo 'ss链接：↓↓↓↓↓复制下方' >> ~/shadowsocks/ss.config
    echo -n 'ss://' >> ~/shadowsocks/ss.config
    echo "${ss_method[method]}:$password@$ip:$port" | echo -n `base64` | sed 's/=//g' >> ~/shadowsocks/ss.config
    echo '#'`curl -s freeapi.ipip.net/$ip` | sed 's/"//g' | sed 's/\[//g' | sed 's/,//g' | sed 's/\]//g' >> ~/shadowsocks/ss.config
}

createStartUp(){
    sed -i 's/ExecStart=\/usr\/bin\/ss-server/ExecStart=\/usr\/local\/bin\/ss-server/g' /usr/local/src/shadowsocks-libev/rpm/SOURCES/systemd/shadowsocks-libev.service
    cp /usr/local/src/shadowsocks-libev/rpm/SOURCES/systemd/shadowsocks-libev.service /usr/lib/systemd/system/
    cp /usr/local/src/shadowsocks-libev/rpm/SOURCES/systemd/shadowsocks-libev.default /etc/sysconfig/shadowsocks-libev
    systemctl enable shadowsocks-libev
    if [ $? -eq 0 ]
    then
        echo '添加开机自启成功'
    else
        echo '添加开机自启失败'
    fi
}

firewall(){
    # 将一个标准错误输出重定向到标准输出 注释:1 可能就是代表 标准输出
    systemctl status firewalld --no-page > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
        if [ $1 == 'open' ]
        then
            echo "开放端口：$port"
            firewall-cmd --add-port=$port/tcp --permanent
        else
            firewall-cmd --remove-port=$oPort/tcp --permanent
            echo "删除端口：$oPort"
        fi
    firewall-cmd --reload
    fi
    ssystemctl status iptables --no-page > /dev/null 2>&1
    if [ $? -eq 0 ]
    then
        if [ $1 == 'open' ]
        then
            echo "开放端口：$port"
            iptables -I INPUT -p tcp --dport $port -j ACCEPT
        else
            echo "删除端口：$oPort"
            iptables -D INPUT -p tcp --dport $oPort -j ACCEPT
        fi
        service iptables save
    fi
}

startShadowsocks(){
    systemctl start shadowsocks-libev
    if [ $? -eq 0 ]
    then
        echo '启动成功'
    else
        echo '启动失败'
    fi
}

stopShadowsocks(){
    systemctl stop shadowsocks-libev
    if [ $? -eq 0 ]
    then
        echo 'Shadowsocks-libev服务已停止'
    else
        echo 'Shadowsocks-libev服务停止失败'
    fi
}

uninstallShadowsocks(){
    systemctl disable shadowsocks-libev
    systemctl stop shadowsocks-libev
    rm -rf /usr/local/src/shadowsocks-libev
    rm -rf /etc/shadowsocks-libev
    rm -rf ~/shadowsocks
    rm -f /usr/local/bin/ss-local
    rm -f /usr/local/bin/ss-manager
    rm -f /usr/local/bin/ss-nat
    rm -f /usr/local/bin/ss-redir
    rm -f /usr/local/bin/ss-server
    rm -f /usr/local/bin/ss-tunnel
    rm -f /usr/lib/systemd/system/shadowsocks-libev.service
    rm -f /etc/sysconfig/shadowsocks-libev
    echo '删除成功'
}

printInfo(){
    echo -e '\e[31m 您的ss链接信息如下： \e[0m'
    cat ~/shadowsocks/ss.config
    echo -e '\e[31m 可直接使用该命令查看：\e[32m cat ~/shadowsocks/ss.config \e[0m'
}

server_list=(
	"-----Bin-----"
	安装shadowsocks-libev服务端
	启动shadowsocks服务端
	停止shadowsocks服务端
	更改shadowsocks配置
	卸载shadowsocks服务
	"-----Bin-----"
)
for((i=1;i<${#server_list[@]};i++))
do
	echo -e "\e[33m $i \e[0m： \e[31m ${server_list[i]} \e[0m"
done
read -p "请选择需要的服务(选择数字)：" server_confirm
case "$server_confirm" in
	[1])
        getSsInfo
        installNeed
        installShadowsocks
        createConfig
        createStartUp
        firewall open
        startShadowsocks
        printInfo
	;;
	[2])
        startShadowsocks
	;;
	[3])
        stopShadowsocks
	;;
	[4])
        oPort=`cat /etc/shadowsocks-libev/config.json | sed -n '/server_port/p' | sed 's/"server_port"://g' | sed 's/,//g'`
        stopShadowsocks
        getSsInfo
        createConfig
        firewall del
        firewall open
        startShadowsocks
        printInfo
	;;
	[5])
        oPort=`cat /etc/shadowsocks-libev/config.json | sed -n '/server_port/p' | sed 's/"server_port"://g' | sed 's/,//g'`
        stopShadowsocks
        firewall del
        uninstallShadowsocks
	;;
	* )
		echo -e "\e[31m Select error? \e[0m"
	;;
esac
