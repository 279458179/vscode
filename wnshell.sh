#!/bin/bash

# 检测操作系统类型
detect_os() {
    if grep -q "AlmaLinux" /etc/os-release; then
        OS="AlmaLinux"
    elif grep -q "CentOS" /etc/os-release; then
        OS="CentOS"
    elif grep -q "Ubuntu" /etc/os-release; then
        OS="Ubuntu"
    else
        echo "Unsupported OS."
        exit 1
    fi
}

# 配置YUM或APT源
configure_source() {
    echo "Configuring package manager source..."
    if [ "$OS" == "CentOS" ]; then
        # CentOS YUM源配置为阿里云镜像源
        echo "Configuring YUM source for CentOS..."
        sudo mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.bak
        sudo curl -o /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
        sudo yum clean all && sudo yum makecache
    elif [ "$OS" == "AlmaLinux" ]; then
        # AlmaLinux 8 YUM源配置为阿里云镜像源
        echo "Configuring YUM source for AlmaLinux 8..."
        sed -e 's|^mirrorlist=|#mirrorlist=|g' \
            -e 's|^# baseurl=https://repo.almalinux.org|baseurl=https://mirrors.aliyun.com|g' \
            -i.bak \
            /etc/yum.repos.d/almalinux*.repo
        dnf makecache

    elif [ "$OS" == "Ubuntu" ]; then
        # Ubuntu APT源配置为阿里云镜像源
        echo "Configuring APT source for Ubuntu..."
        sudo mv /etc/apt/sources.list /etc/apt/sources.list.bak
        sudo bash -c 'cat > /etc/apt/sources.list <<EOF
deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -sc) main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -sc)-security main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -sc)-updates main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -sc)-proposed main restricted universe multiverse
deb http://mirrors.aliyun.com/ubuntu/ $(lsb_release -sc)-backports main restricted universe multiverse
EOF'
        sudo apt update
    else
        echo "Unsupported OS."
    fi
}

# 安装Docker
install_docker() {
    echo "Installing Docker..."

    if [ "$OS" == "CentOS" ]; then
        # CentOS 的 Docker 安装步骤
        sudo yum install -y yum-utils
        sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        sudo yum install -y docker-ce docker-ce-cli containerd.io
        echo "Docker installed on CentOS."

    elif [ "$OS" == "AlmaLinux" ]; then
        # AlmaLinux 的 Docker 安装步骤
        sudo dnf install -y dnf-utils
        sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
        sudo dnf install -y docker-ce docker-ce-cli containerd.io
        echo "Docker installed on AlmaLinux."

    elif [ "$OS" == "Ubuntu" ]; then
        # Ubuntu 的 Docker 安装步骤
        sudo apt update
        sudo apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io
        echo "Docker installed on Ubuntu."

    else
        echo "Unsupported OS."
        exit 1
    fi

    # 启动并设置 Docker 开机自启
    sudo systemctl enable docker
    sudo systemctl start docker
}

# 配置网卡
configure_network() {
    echo "Configuring network interface..."

    read -p "Enter the network interface name (e.g., ens19): " IFACE
    read -p "Enter the IP address (e.g., 192.168.1.199): " IP_ADDR
    read -p "Enter the gateway (e.g., 192.168.1.1): " GATEWAY
    read -p "Enter the netmask (e.g., 255.255.255.0): " NETMASK

    if [ "$OS" == "CentOS" ]; then
        # 配置 CentOS 的网卡
        CONFIG_FILE="/etc/sysconfig/network-scripts/ifcfg-$IFACE"
        sudo bash -c "cat > $CONFIG_FILE <<EOF
DEVICE=$IFACE
BOOTPROTO=static
ONBOOT=yes
IPADDR=$IP_ADDR
NETMASK=$NETMASK
GATEWAY=$GATEWAY
EOF"
        echo "Network configuration for $IFACE has been updated on CentOS."

        # 重启网络服务
        sudo systemctl restart network.service

    elif [ "$OS" == "AlmaLinux" ]; then
        # 配置 AlmaLinux 的网卡
        CONFIG_FILE="/etc/sysconfig/network-scripts/ifcfg-$IFACE"
        sudo bash -c "cat > $CONFIG_FILE <<EOF
DEVICE=$IFACE
BOOTPROTO=static
ONBOOT=yes
IPADDR=$IP_ADDR
NETMASK=$NETMASK
GATEWAY=$GATEWAY
EOF"
        echo "Network configuration for $IFACE has been updated on AlmaLinux."

        # 重启 NetworkManager 服务
        sudo systemctl restart NetworkManager

    elif [ "$OS" == "Ubuntu" ]; then
        # 配置 Ubuntu 的网卡
        CONFIG_FILE="/etc/netplan/01-netcfg.yaml"
        sudo bash -c "cat > $CONFIG_FILE <<EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $IFACE:
      dhcp4: no
      addresses:
        - $IP_ADDR/24
      gateway4: $GATEWAY
      nameservers:
        addresses:
          - 8.8.8.8
          - 8.8.4.4
EOF"
        echo "Network configuration for $IFACE has been updated on Ubuntu."

        # 应用网卡配置并重启网络
        sudo netplan apply
    else
        echo "Unsupported OS."
        exit 1
    fi
}

# 关闭防火墙
disable_firewall() {
    echo "Disabling firewall..."

    if [ "$OS" == "CentOS" ]; then
        # 对 CentOS 进行防火墙禁用操作
        sudo systemctl stop firewalld
        sudo systemctl disable firewalld
        echo "Firewall disabled on CentOS."

    elif [ "$OS" == "AlmaLinux" ]; then
        # 对 AlmaLinux 进行防火墙禁用操作
        sudo systemctl stop firewalld
        sudo systemctl disable firewalld
        echo "Firewall disabled on AlmaLinux."

    elif [ "$OS" == "Ubuntu" ]; then
        # 对 Ubuntu 进行防火墙禁用操作
        sudo ufw disable
        echo "Firewall disabled on Ubuntu."

    else
        echo "Unsupported OS."
        exit 1
    fi
}

# 关闭SELinux
disable_selinux() {
    if [ "$OS" == "CentOS" ] || [ "$OS" == "AlmaLinux" ]; then
        echo "Disabling SELinux..."
        # 设置 SELinux 为宽容模式 (Permissive)
        sudo setenforce 0
        # 禁用 SELinux
        sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        echo "SELinux has been disabled on $OS."

    elif [ "$OS" == "Ubuntu" ]; then
        echo "SELinux is not available on Ubuntu. No action needed."

    else
        echo "Unsupported OS."
        exit 1
    fi
}

#配置ssh_互信
configure_ssh_trust() {
    echo "Configuring SSH mutual trust..."

    # 检查本地是否已经生成了 SSH 密钥
    if [ ! -f ~/.ssh/id_rsa ]; then
        echo "SSH key not found. Generating a new SSH key..."
        ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -N ""
    else
        echo "SSH key already exists."
    fi

    # 提示用户输入目标机器的 IP 地址
    read -p "Enter the IP address of the target machine: " target_ip

    # 将 SSH 公钥拷贝到目标机器
    ssh-copy-id -i ~/.ssh/id_rsa.pub "$USER@$target_ip"

    if [ $? -eq 0 ]; then
        echo "SSH mutual trust configured successfully with $target_ip."
    else
        echo "Failed to configure SSH mutual trust with $target_ip."
    fi
}


#部署VSftpd服务
deploy_vsftpd() {
    echo "Deploying vsftpd service in passive mode..."

    # 根据系统判断安装 vsftpd
    if [ "$OS" == "CentOS" ] || [ "$OS" == "AlmaLinux" ]; then
        # CentOS 和 AlmaLinux 安装 vsftpd
        sudo yum install -y vsftpd
        echo "vsftpd installed on $OS."

    elif [ "$OS" == "Ubuntu" ]; then
        # Ubuntu 安装 vsftpd
        sudo apt update
        sudo apt install -y vsftpd
        echo "vsftpd installed on Ubuntu."

    else
        echo "Unsupported OS."
        exit 1
    fi

    # 启动并设置 vsftpd 开机自启
    sudo systemctl start vsftpd
    sudo systemctl enable vsftpd

    # 配置 vsftpd
    sudo sed -i 's/anonymous_enable=YES/anonymous_enable=NO/' /etc/vsftpd/vsftpd.conf
    sudo sed -i 's/#local_enable=YES/local_enable=YES/' /etc/vsftpd/vsftpd.conf
    sudo sed -i 's/#write_enable=YES/write_enable=YES/' /etc/vsftpd/vsftpd.conf
    sudo sed -i 's/listen=NO/listen=YES/' /etc/vsftpd/vsftpd.conf
    sudo sed -i 's/listen_ipv6=YES/listen_ipv6=NO/' /etc/vsftpd/vsftpd.conf

    # 配置被动模式和指定端口范围
    echo "pasv_enable=YES" | sudo tee -a /etc/vsftpd/vsftpd.conf
    echo "pasv_min_port=30000" | sudo tee -a /etc/vsftpd/vsftpd.conf
    echo "pasv_max_port=31000" | sudo tee -a /etc/vsftpd/vsftpd.conf
    echo "pasv_address=$(ip a |grep "inet " |grep brd |awk '{print $2}' |cut -d / -f 1)" | sudo tee -a /etc/vsftpd/vsftpd.conf  # 获取服务器公网IP
    # echo "pasv_address=192.168.100.2" | sudo tee -a /etc/vsftpd/vsftpd.conf  # 获取服务器公网IP

    # 配置 vsftpd 使用 22001 端口
    echo "listen_port=22001" | sudo tee -a /etc/vsftpd/vsftpd.conf

    # 创建并配置 ftpuser 用户
    if ! id "ftpuser" &>/dev/null; then
        sudo useradd -m -d /home/ftpuser ftpuser
        echo "ftpuser:ftpuser" | sudo chpasswd  # 设置 ftpuser 用户的密码为 "ftpuser"
        echo "ftpuser created with home directory /home/ftpuser"
    else
        echo "User ftpuser already exists."
    fi

    # 设置用户家目录权限，确保 ftpuser 可以访问
    sudo chown ftpuser:ftpuser /home/ftpuser

    # 配置 vsftpd 允许用户登录
    echo "userlist_enable=YES" | sudo tee -a /etc/vsftpd/vsftpd.conf
    echo "userlist_deny=NO" | sudo tee -a /etc/vsftpd/vsftpd.conf
    echo "ftpuser" | sudo tee -a /etc/vsftpd/user_list

    # 重启 vsftpd 以应用配置
    sudo systemctl restart vsftpd

    echo "vsftpd service deployed in passive mode on $OS."
    echo "ftpuser can now log in via port 22001 with the password 'ftpuser'."
}

#磁盘挂载lvm
lvm_partition_and_mount() {
    # 提示用户输入磁盘名称和挂载点
    read -p "Enter the disk to partition (e.g., /dev/sdb): " disk
    read -p "Enter the mount point directory (e.g., /mnt/data): " mount_point

    # 检查磁盘是否存在
    if [ ! -b "$disk" ]; then
        echo "Disk $disk does not exist."
        exit 1
    fi

    # 创建物理卷 (PV)
    echo "Creating physical volume on $disk..."
    sudo pvcreate "$disk"

    # 创建卷组 (VG)，命名为 lvm_vg
    echo "Creating volume group lvm_vg..."
    sudo vgcreate lvm_vg "$disk"

    # 创建逻辑卷 (LV)，命名为 lvm_lv，占用所有空间
    echo "Creating logical volume lvm_lv..."
    sudo lvcreate -l 100%FREE -n lvm_lv lvm_vg

    # 格式化逻辑卷为 ext4
    echo "Formatting logical volume as ext4..."
    sudo mkfs.ext4 /dev/lvm_vg/lvm_lv

    # 创建挂载点目录（如果不存在）
    if [ ! -d "$mount_point" ]; then
        echo "Creating mount point directory $mount_point..."
        sudo mkdir -p "$mount_point"
    fi

    # 挂载逻辑卷到指定的挂载点
    echo "Mounting logical volume to $mount_point..."
    sudo mount /dev/lvm_vg/lvm_lv "$mount_point"

    # 确保挂载点在重启后仍然有效，添加到 /etc/fstab
    echo "Updating /etc/fstab to make the mount persistent..."
    UUID=$(sudo blkid -s UUID -o value /dev/lvm_vg/lvm_lv)
    echo "UUID=$UUID $mount_point ext4 defaults 0 0" | sudo tee -a /etc/fstab

    echo "Disk $disk has been partitioned, formatted, and mounted to $mount_point."
}



# 显示菜单
show_menu() {
    echo -e "\033[32m请选择要执行的操作（可以输入多个序号，如1,2,3）：\033[0m"
    echo -e "\033[32m1. 配置YUM/APT源\033[0m"
    echo -e "\033[32m2. 配置网卡\033[0m"
    echo -e "\033[32m3. 关闭防火墙\033[0m"
    echo -e "\033[32m4. 关闭SELinux\033[0m"
    echo -e "\033[32m5. 安装docker\033[0m"
    echo -e "\033[32m6. 配置ssh互信\033[0m"
    echo -e "\033[32m7. 部署vsftpd服务\033[0m"
    echo -e "\033[32m8. 磁盘挂载LVM\033[0m"
    echo -e "\033[32m0. 退出\033[0m"
}

# 主函数
main() {
    detect_os
    show_menu
    read -p "输入选项: " choices
    IFS=',' read -ra ADDR <<<"$choices"
    for choice in "${ADDR[@]}"; do
        case $choice in
        1) configure_source ;;
        2) configure_network ;;
        3) disable_firewall ;;
        4) disable_selinux ;;
        5) install_docker ;;
        6) configure_ssh_trust ;;
        7) deploy_vsftpd ;;
        8) lvm_partition_and_mount ;;
        0) exit 0 ;;
        *) echo "无效的选项: $choice" ;;
        esac
    done
}

main
