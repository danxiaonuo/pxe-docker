# 下载镜像
## ubuntu-22.04.3
wget https://mirrors.aliyun.com/ubuntu-releases/jammy/ubuntu-22.04.3-live-server-amd64.iso

## CentOS-7.9.2009
wget https://mirrors.aliyun.com/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-DVD-2207-02.iso

## 复制镜像和内核
### 挂载镜像
#### Ubuntu 内核镜像挂载
mount -o loop ubuntu-22.04.3-live-server-amd64.iso /mnt
cp -av /mnt/casper/{initrd,vmlinuz} /srv/tftp/boot/ubuntu2204
umount /mnt

#### Fedora/RHEL/Centos 内核镜像挂载
mount -o loop CentOS-7-x86_64-DVD-2009.iso /mnt
cp -av /mnt/isolinux/{initrd.img,vmlinuz} /srv/tftp/boot/centos792009/
umount /mnt
