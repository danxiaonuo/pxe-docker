#!/bin/bash

# 导入环境变量
# PXE IP地址
PXE_IP=$(for e in $(ls -l /sys/class/net/ | grep -v virtual  | grep -v 'total' | awk '{print $9}'); do ifconfig | grep -1 $e | grep inet | awk '{print $2}';done)
# 接口名称
INTERFACE=$(ip route | grep -i 'via' | awk 'END {print $5}')''
# DHCP起始地址
DHCP_RANGE_LOW=$(for e in $(ls -l /sys/class/net/ | grep -v virtual  | grep -v 'total' | awk '{print $9}'); do ifconfig | grep -1 $e | grep inet | awk '{print $2}';done | awk 'BEGIN{ FS = "."} {print $1"."$2"."$3".10"}')
# DHCP起始结束地址
DHCP_RANGE_HIGH=$(for e in $(ls -l /sys/class/net/ | grep -v virtual  | grep -v 'total' | awk '{print $9}'); do ifconfig | grep -1 $e | grep inet | awk '{print $2}';done | awk 'BEGIN{ FS = "."} {print $1"."$2"."$3".245"}')
# 网关地址
GATEWAY_IP=$(ip route | grep -i 'via' |awk 'END {print $3}')

# 环境变量
# 接口名称
INTERFACE="${INTERFACE:=${INTERFACE}}"
# PXE IP地址
PXE_IP="${PXE_IP:=${PXE_IP}}"
# DHCP起始地址
DHCP_RANGE_LOW="${DHCP_RANGE_LOW:=${DHCP_RANGE_LOW}}"
# DHCP起始结束地址
DHCP_RANGE_HIGH="${DHCP_RANGE_HIGH:=${DHCP_RANGE_HIGH}}"
# 网关地址
GATEWAY_IP="${GATEWAY_IP:=${GATEWAY_IP}}"
# DHCP DNS地址
DHCP_DNS="${DHCP_DNS:=223.5.5.5}"
# PXE 路径
PXE_PATH="${PXE_PATH:=/srv/tftp}"
# 系统名称
OS_NAME="${OS_NAME:=Ubuntu Jammy}"
# 系统版本
OS_VER="${OS_VER:=(22.04.3)}"
# 系统编号
OS_NUM="${OS_NUM:=ubuntu22043}"
# ISO 下载地址
PXE_ISO_URL="${PXE_ISO_URL:=http://${PXE_IP}/get/iso/ubuntu-22.04.3-live-server-amd64.iso}"
# KS 配置文件下载地址
PXE_KS_URL="${PXE_KS_URL:=http://${PXE_IP}/get/ks/ubuntu22043/autoinstall/}"

echo "接口名称:" ${INTERFACE}
echo "PXE IP地址:" ${PXE_IP}
echo "DHCP起始地址:" ${DHCP_RANGE_LOW}
echo "DHCP起始结束地址:" ${DHCP_RANGE_HIGH}
echo "DHCP DNS地址:" ${DHCP_DNS}
echo "PXE 路径:" ${PXE_PATH}
echo "系统名称:" ${OS_NAME}
echo "系统版本:" ${OS_VER}
echo "系统编号:" ${OS_NUM}
echo "ISO 下载地址:" ${PXE_ISO_URL}
echo "KS 配置文件下载地址:" ${PXE_KS_URL}

## 创建相关目录文件
mkdir -pv ${PXE_PATH}/{bios,uefi,boot,iso,grub,ks,pxelinux.cfg} && chmod -R 775 ${PXE_PATH}

## 安装PXE BOOT文件
### BIOS system
cp -av /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/bios
cp -av /usr/lib/syslinux/modules/bios/{ldlinux.c32,libcom32.c32,libutil.c32,menu.c32,vesamenu.c32} ${PXE_PATH}/bios
### UEFI System
cp -av /usr/lib/syslinux/modules/efi64/{ldlinux.e64,libcom32.c32,libutil.c32,menu.c32,vesamenu.c32} ${PXE_PATH}/uefi
cp -av /usr/lib/SYSLINUX.EFI/efi64/syslinux.efi ${PXE_PATH}/uefi 
ln -sfd ${PXE_PATH}/pxelinux.cfg ${PXE_PATH}/bios
ln -sfd ${PXE_PATH}/pxelinux.cfg ${PXE_PATH}/uefi
ln -sfd ${PXE_PATH}/boot ${PXE_PATH}/bios
ln -sfd ${PXE_PATH}/boot ${PXE_PATH}/uefi

# 配置DNSMASQ
cat << EOF > /etc/dnsmasq.conf
# 用户
user=root
# 设置本服务器提供DHCP服务的网卡
interface=${INTERFACE},lo
bind-interfaces
# 提供DHCP服务的网卡,开始IP,结束IP
dhcp-range=${INTERFACE},${DHCP_RANGE_LOW},${DHCP_RANGE_HIGH}
# 网关选项
dhcp-option=3,${GATEWAY_IP}
# DNS 服务器选项
dhcp-option=6,${DHCP_DNS}
server=${DHCP_DNS}
# 启用tftp服务
enable-tftp
# 设置tftp服务目录
tftp-root=${PXE_PATH}
# pxeboot 文件的位置
dhcp-boot=/bios/pxelinux.0
# 引导加载程序文件
dhcp-match=set:efi-x86_64,option:client-arch,7 
dhcp-boot=tag:efi-x86_64,uefi/syslinux.efi
# 日志
log-facility=/var/log/dnsmasq.log
EOF

if [[ $OS_TYPE == debian ]]; then

	# pxe启动菜单选项
	cat <<EOF >${PXE_PATH}/pxelinux.cfg/default
MENU TITLE ########## PXE Boot Menu ##########
MENU COLOR TABMSG  37;40  #ffffffff #00000000
MENU COLOR TITLE   37;40  #ffffffff #00000000
MENU COLOR SEL      7     #ffffffff #00000000
MENU COLOR UNSEL    37;40 #ffffffff #00000000
MENU COLOR BORDER   37;40 #ffffffff #00000000

DEFAULT menu.c32
PROMPT 0
TIMEOUT 900

LABEL MENU LABEL Install ${OS_NAME}
        MENU LABEL ${OS_NAME} ${OS_VER} Automated Installer
        MENU DEFAULT
        KERNEL boot/${OS_NUM}/vmlinuz
        INITRD boot/${OS_NUM}/initrd
        APPEND root=/dev/ram0 ramdisk_size=1500000 ip=dhcp cloud-config-url=/dev/null fsck.mode=skip net.ifnames=0 biosdevname=0 url=${PXE_ISO_URL} autoinstall ds=nocloud-net;s=${PXE_KS_URL}

LABEL MENU LABEL Boot on Local Hard
      MENU LABEL Boot on Local Hard
      MENU DEFAULT
      localboot 0
EOF

elif

	[[ $OS_TYPE == redhat ]]
then

	# pxe启动菜单选项
	cat <<EOF >${PXE_PATH}/pxelinux.cfg/default
MENU TITLE ########## PXE Boot Menu ##########
MENU COLOR TABMSG  37;40  #ffffffff #00000000
MENU COLOR TITLE   37;40  #ffffffff #00000000
MENU COLOR SEL      7     #ffffffff #00000000
MENU COLOR UNSEL    37;40 #ffffffff #00000000
MENU COLOR BORDER   37;40 #ffffffff #00000000

DEFAULT menu.c32
PROMPT 0
TIMEOUT 900

LABEL MENU LABEL Install ${OS_NAME}
        MENU LABEL ${OS_NAME} ${OS_VER} Automated Installer
        MENU DEFAULT
        KERNEL boot/${OS_NUM}/vmlinuz
        INITRD boot/${OS_NUM}/initrd.img
        APPEND ip=dhcp fsck.mode=skip net.ifnames=0 biosdevname=0 inst.repo=${PXE_ISO_URL} ks=${PXE_KS_URL}

LABEL MENU LABEL Boot on Local Hard
      MENU LABEL Boot on Local Hard
      MENU DEFAULT
      localboot 0
EOF

fi

# 运行dnsmasq
exec dnsmasq -k
