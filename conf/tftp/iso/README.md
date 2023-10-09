# 下载镜像
## ubuntu-22.04.3
wget https://mirrors.aliyun.com/ubuntu-releases/jammy/ubuntu-22.04.3-live-server-amd64.iso

## CentOS-7.9.2009
wget https://mirrors.aliyun.com/centos/7.9.2009/isos/x86_64/CentOS-7-x86_64-DVD-2207-02.iso

## 复制镜像和内核
### 挂载镜像
#### Ubuntu 内核镜像挂载
mount -o loop ubuntu-22.04.3-live-server-amd64.iso /mnt <br/>
cp -av /mnt/casper/{initrd,vmlinuz} /srv/tftp/boot/ubuntu2204 <br/>
umount /mnt <br/>

#### Centos 内核镜像挂载 
mkdir -pv /srv/tftp/iso/centos7.9 <br/>
mount -o loop CentOS-7-x86_64-DVD-2009.iso /mnt <br/>
cp -av /mnt/isolinux/{initrd.img,vmlinuz} /srv/tftp/boot/centos792009/ <br/>
cp -av /mnt/* /srv/tftp/iso/centos7.9/ <br/>
umount /mnt <br/>

#### RHEL 内核镜像挂载
mkdir -pv /srv/tftp/iso/rhel7.4 <br/>
mount -o loop rhel-server-7.4-x86_64-dvd.iso /mnt <br/>
cp -av /mnt/isolinux/{initrd.img,vmlinuz} /srv/tftp/boot/rhel0704/ <br/>
cp -av /mnt/* /srv/tftp/iso/rhel7.4/ <br/>
umount /mnt <br/>
