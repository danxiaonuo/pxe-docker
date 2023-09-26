#!/bin/bash

# 导入环境变量
export 'PXE_IP='$(for e in $(ls -l /sys/class/net/ | grep -v virtual  | grep -v 'total' | awk '{print $9}'); do ifconfig | grep -1 $e | grep inet | awk '{print $2}';done)
export 'INTERFACE='$(ls -l /sys/class/net/ | grep -v virtual  | grep -v 'total' | awk '{print $9}')''
export 'DHCP_RANGE_LOW='$(for e in $(ls -l /sys/class/net/ | grep -v virtual  | grep -v 'total' | awk '{print $9}'); do ifconfig | grep -1 $e | grep inet | awk '{print $2}';done | awk 'BEGIN{ FS = "."} {print $1"."$2"."$3".10"}')
export 'DHCP_RANGE_HIGH='$(for e in $(ls -l /sys/class/net/ | grep -v virtual  | grep -v 'total' | awk '{print $9}'); do ifconfig | grep -1 $e | grep inet | awk '{print $2}';done | awk 'BEGIN{ FS = "."} {print $1"."$2"."$3".245"}')


## 创建相关目录文件
mkdir -pv ${PXE_PATH}/{bios,uefi,boot,iso,grub,ks} && chmod -R 775 ${PXE_PATH}

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
# NTP 服务器选项
dhcp-option=42,${DHCP_NTP}
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

# pxe启动菜单选项
cat << EOF > ${PXE_PATH}/pxelinux.cfg/default
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

