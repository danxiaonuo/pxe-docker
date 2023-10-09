#!/bin/bash
set -x

# 更新源
sudo -E yum -y remove epel-release
# 更换基础镜像
rm -rf /etc/yum.repos.d/*
tee /etc/yum.repos.d/CentOS-Base.repo<<-'EOF'
[base]
name=CentOS-$releasever - Base - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/os/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
 
#released updates 
[updates]
name=CentOS-$releasever - Updates - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/updates/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
 
#additional packages that may be useful
[extras]
name=CentOS-$releasever - Extras - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/extras/$basearch/
gpgcheck=1
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
 
#additional packages that extend functionality of existing packages
[centosplus]
name=CentOS-$releasever - Plus - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/centosplus/$basearch/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
 
#contrib - packages by Centos Users
[contrib]
name=CentOS-$releasever - Contrib - mirrors.aliyun.com
failovermethod=priority
baseurl=http://mirrors.aliyun.com/centos/$releasever/contrib/$basearch/
gpgcheck=1
enabled=0
gpgkey=http://mirrors.aliyun.com/centos/RPM-GPG-KEY-CentOS-7
EOF
# 更新源
yum clean all && yum makecache
# 安装EPEL源
sudo -E yum -y remove epel-release
sudo -E yum -y install epel-release
tee /etc/yum.repos.d/epel.repo<<-'EOF'
[epel]
name=Extra Packages for Enterprise Linux 7 - $basearch
baseurl=http://mirrors.aliyun.com/epel/7/$basearch
failovermethod=priority
enabled=1
gpgcheck=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
 
[epel-debuginfo]
name=Extra Packages for Enterprise Linux 7 - $basearch - Debug
baseurl=http://mirrors.aliyun.com/epel/7/$basearch/debug
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
gpgcheck=0
 
[epel-source]
name=Extra Packages for Enterprise Linux 7 - $basearch - Source
baseurl=http://mirrors.aliyun.com/epel/7/SRPMS
failovermethod=priority
enabled=0
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-EPEL-7
gpgcheck=0
EOF
cat >/etc/yum.conf<<-EOF
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=True
fastestmirror=True
keepcache=True
EOF

# 更新源
yum clean all && yum makecache

# 安装软件
sudo -E yum -y install bash-completion conntrack-tools ipset ipvsadm libseccomp nfs-utils psmisc rsync socat jq perl gcc gcc-c++ glibc-headers glibc-headers glibc-headers glibc-headers make cmake autoconf automake openssl openssl-devel pcre pcre-devel zlib zlib-devel mlocate ncurses-devel gnutls gnutls-devel gnutls-utils gnutls-utils gnutls-utils libidn libaio libtool net-tools crontabs sysstat tar zip unzip chrony tcpdump telnet lsof nload strace iftop htop wget curl vim device-mapper-persistent-data lvm2 tree supervisor bind-utils lrzsz ntpdate

# 设置主机名称
hostnamectl set-hostname xiaonuo

# 语言设置与键盘设置
localectl set-locale LANG="zh_CN.UTF-8" LANGUAGE="zh_CN:zh"
localectl set-keymap cn
localectl set-x11-keymap cn

# 更新时区
timedatectl set-local-rtc 1
timedatectl set-timezone Asia/Shanghai

# 时间同步
crontab -l | { cat; echo "* * * * * /usr/sbin/ntpdate -b -u ntp.aliyun.com && /sbin/hwclock -w"; } | crontab -

# 时间同步
cat > /etc/chrony.conf<<EOF
# 指定上层NTP服务器为阿里云提供的公网NTP服务器
server ntp.aliyun.com iburst minpoll 4 maxpoll 10
server ntp1.aliyun.com iburst minpoll 4 maxpoll 10
server ntp2.aliyun.com iburst minpoll 4 maxpoll 10
server ntp3.aliyun.com iburst minpoll 4 maxpoll 10
server ntp4.aliyun.com iburst minpoll 4 maxpoll 10
server ntp5.aliyun.com iburst minpoll 4 maxpoll 10
server ntp6.aliyun.com iburst minpoll 4 maxpoll 10
server ntp7.aliyun.com iburst minpoll 4 maxpoll 10
# 记录系统时钟获得/丢失时间的速率至drift文件中
driftfile /var/lib/chrony/drift
# 如果系统时钟的偏移量大于1秒，则允许在前三次更新中步进调整系统时钟
makestep 1.0 3
# 启用RTC（实时时钟）的内核同步
rtcsync
# 允许所有网段的客户端进行时间同步
allow 0.0.0.0/0
allow ::/0
# 阿里云提供的公网NTP服务器不可用时，采用本地时间作为同步标准
local stratum 10
# 指定包含NTP验证密钥的文件
keyfile /etc/chrony.keys
# 指定存放日志文件的目录
logdir /var/log/chrony
# 让chronyd在选择源时忽略源的层级
stratumweight 0
# 禁用客户端访问的日志记录
noclientlog
# 如果时钟调整大于0.5秒，则向系统日志发送消息
logchange 0.5
EOF
systemctl enable chronyd && systemctl restart chronyd

# 修改root密码
echo '@admin123'| passwd --stdin root 

# 密码永不过期
chage -M 99999 root && chage -l root

# 文件描述符设置
cat > /etc/security/limits.conf<<EOF
root soft nofile 655360
root hard nofile 655360
root soft nproc 655360
root hard nproc 655360
root soft core unlimited
root hard core unlimited
root soft stack unlimited
root hard stack unlimited
* soft nofile 655360
* hard nofile 655360
* soft nproc 655360
* hard nproc 655360
* soft core unlimited
* hard core unlimited
* soft stack unlimited
* hard stack unlimited
EOF
rm -rf /etc/security/limits.d/*
sed -i '/DefaultLimitCORE/c DefaultLimitCORE=infinity' /etc/systemd/*.conf
sed -i '/DefaultLimitSTACK/c DefaultLimitSTACK=infinity' /etc/systemd/*.conf
sed -i '/DefaultTasksMax/c DefaultTasksMax=infinity' /etc/systemd/*.conf
sed -i '/DefaultLimitNOFILE/c DefaultLimitNOFILE=655360' /etc/systemd/*.conf
sed -i '/DefaultLimitNPROC/c DefaultLimitNPROC=655360' /etc/systemd/*.conf
systemctl daemon-reexec

# ssh设置
sed -ie 's/^#\?ClientAliveInterval.*/ClientAliveInterval 600/g' /etc/ssh/sshd_config
sed -ie 's/^#\?ClientAliveCountMax.*/ClientAliveCountMax 2/g' /etc/ssh/sshd_config
sed -ie 's/^#\?AddressFamily.*/AddressFamily inet/g' /etc/ssh/sshd_config
sed -ie 's/^#\?PermitRootLogin.*/PermitRootLogin yes/g' /etc/ssh/sshd_config
sed -ie 's/^#\?PermitEmptyPasswords.*/PermitEmptyPasswords no/g' /etc/ssh/sshd_config
sed -ie 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
sed -ie 's/^#\?GSSAPIAuthentication.*/GSSAPIAuthentication no/g' /etc/ssh/sshd_config
systemctl restart sshd

# 开机引导设置
sed -ie 's/GRUB_CMDLINE_LINUX=.*/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0"/' /etc/default/grub
grubby --grub2

# 把SCTP列入内核模块黑名单
cat > /etc/modprobe.d/sctp.conf<<EOF
# put sctp into blacklist
install sctp /bin/true
EOF

# 开启ipvs
cat << EOF > /etc/sysconfig/modules/ipvs.modules
#!/bin/bash
ipvs_modules_dir="/usr/lib/modules/\`uname -r\`/kernel/net/netfilter/ipvs"
for i in \`ls \$ipvs_modules_dir | sed  -r 's#(.*).ko.xz#\1#'\`; do
    /sbin/modinfo -F filename \$i  &> /dev/null
    if [ \$? -eq 0 ]; then
        /sbin/modprobe \$i
    fi
done
EOF
chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules

# 设置vim
perl -pi -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim

# 禁用系统 swap
swapoff -a && sysctl -w vm.swappiness=0

# 系统优化
cat << EOF >  /etc/sysctl.conf
vm.swappiness = 0
vm.overcommit_memory = 1
vm.panic_on_oom = 0
vm.dirty_background_ratio = 5
vm.dirty_ratio = 60
vm.max_map_count = 655360
fs.file-max = 655360
fs.nr_open = 655360
fs.suid_dumpable = 0
fs.inotify.max_user_instances = 655360
fs.inotify.max_user_watches = 655360
fs.inotify.max_queued_events = 655360
net.core.wmem_default = 25165824
net.core.rmem_default = 25165824
net.core.wmem_max = 25165824
net.core.rmem_max = 25165824
net.ipv4.tcp_wmem = 20480 12582912 25165824
net.ipv4.tcp_rmem = 20480 12582912 25165824
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_wmem = 20480 12582912 25165824
net.ipv4.tcp_rmem = 20480 12582912 25165824
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.udp_mem = 94500000 915000000 927000000
net.ipv4.udp_wmem_min = 16384
net.ipv4.udp_rmem_min = 16384
net.ipv4.tcp_max_syn_backlog = 655360
net.core.netdev_max_backlog = 655360
net.core.dev_weight = 600
net.core.optmem_max = 25165824
net.ipv4.tcp_synack_retries = 3
net.ipv4.tcp_syn_retries = 3
net.ipv4.ip_local_port_range = 2048 65535
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_fin_timeout = 15
net.core.somaxconn = 65535
net.ipv4.tcp_syncookies = 1
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_window_scaling = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.tcp_max_orphans = 655360
net.ipv4.ipfrag_low_thresh = 196608
net.ipv6.ip6frag_low_thresh = 196608
net.unix.max_dgram_qlen = 655350
net.ipv4.route.gc_timeout = 100
net.ipv4.tcp_no_metrics_save = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_frto = 2
net.ipv4.tcp_moderate_rcvbuf = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_max_tw_buckets = 655360
net.ipv4.tcp_tw_reuse = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.neigh.default.base_reachable_time_ms = 600000
net.ipv4.neigh.default.mcast_solicit = 20
net.ipv4.neigh.default.retrans_time_ms = 250
net.ipv4.conf.all.route_localnet = 1
net.ipv4.ip_forward = 1
net.ipv4.conf.default.forwarding = 1
net.ipv4.conf.all.forwarding = 1
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.forwarding = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.disable_ipv6 = 0
net.ipv6.conf.all.disable_ipv6 = 0
net.ipv6.conf.lo.disable_ipv6 = 0
net.ipv6.conf.all.proxy_ndp = 1
net.ipv6.conf.all.accept_ra = 2
net.ipv6.conf.default.router_solicitations = 0
net.ipv6.conf.default.accept_ra_rtr_pref = 0
net.ipv6.conf.default.accept_ra_pinfo = 0
net.ipv6.conf.default.accept_ra_defrtr = 0
net.ipv6.conf.default.autoconf = 0
net.ipv6.conf.default.dad_transmits = 0
net.ipv6.conf.default.max_addresses = 1
net.ipv6.conf.lo.accept_ra = 2
net.ipv6.conf.lo.accept_ra_defrtr = 1
net.ipv6.conf.lo.accept_ra_pinfo = 1
net.ipv6.conf.lo.router_solicitations = 1
net.ipv4.neigh.default.gc_thresh1 = 2048
net.ipv4.neigh.default.gc_thresh2 = 4096
net.ipv4.neigh.default.gc_thresh3 = 8192
net.ipv4.neigh.default.gc_interval = 30
net.ipv4.neigh.default.proxy_qlen = 96
net.ipv4.neigh.default.unres_qlen = 6
net.ipv4.tcp_reordering = 6
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.route.flush = 1
net.ipv6.route.flush = 1
net.ipv4.tcp_keepalive_time = 0
net.ipv4.tcp_keepalive_intvl = 3
net.ipv4.tcp_keepalive_probes = 10
net.ipv4.tcp_ecn = 1
kernel.sysrq = 0
kernel.unknown_nmi_panic = 0
kernel.core_uses_pid = 1
kernel.pid_max = 655360
kernel.threads-max = 655360
kernel.msgmnb = 655360
kernel.msgmax = 655360
kernel.shmmax = 135291469824
kernel.shmall = 33822867456
kernel.randomize_va_space = 2
kernel.core_pattern = core
kernel.softlockup_all_cpu_backtrace = 1
kernel.softlockup_panic = 1
EOF
sysctl -p
rm -rf *.sh
