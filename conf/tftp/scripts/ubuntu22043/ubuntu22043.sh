#!/bin/bash
set -x

export DEBIAN_FRONTEND=noninteractive

# 更换为阿里云镜像
sed -i s@http://*.*ubuntu.com@https://mirrors.aliyun.com@g /etc/apt/sources.list
sed -i 's?# deb-src?deb-src?g' /etc/apt/sources.list

# 设置主机名称
hostnamectl set-hostname xiaonuo

# 语言设置与键盘设置
localectl set-locale LANG="zh_CN.UTF-8" LANGUAGE="zh_CN:zh"
localectl set-x11-keymap cn

# 更新时区
timedatectl set-local-rtc 1
timedatectl set-timezone Asia/Shanghai

# 时间同步
cat > /etc/chrony/chrony.conf<<EOF
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
systemctl enable chrony && systemctl restart chrony

# 修改root密码
echo 'root:@admin123' | chpasswd
# 密码永不过期
chage -m 0 -M 99999 -I -1 -E -1 root && chage -l root

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
update-grub2

# 把SCTP列入内核模块黑名单
cat > /etc/modprobe.d/sctp.conf<<EOF
# put sctp into blacklist
install sctp /bin/true
EOF
# 开启ipvs
tee > /lib/systemd/system/rc-local.service<<-'EOF'
[Unit]
Description=/etc/rc.local Compatibility
Documentation=man:systemd-rc-local-generator(8)
ConditionFileIsExecutable=/etc/rc.local
After=network.target

[Service]
Type=forking
ExecStart=/etc/rc.local start
TimeoutSec=0
RemainAfterExit=yes
GuessMainPID=no

[Install]
WantedBy=multi-user.target
Alias=rc-local.service
EOF
tee > /etc/rc.local <<-'EOF'
#!/bin/sh -e
ls /lib/modules/$(uname -r)/kernel/net/netfilter/ipvs|grep -o "^[^.]*" > /etc/modules-load.d/ipvs.conf
echo "ip6table_security\nip6table_raw\nip6table_nat\nip6table_mangle\nip6table_filter" > /etc/modules-load.d/ipv6.conf
EOF
chmod 775 /etc/rc.local
ln -snf /lib/systemd/system/rc-local.service /etc/systemd/system/
systemctl daemon-reload && systemctl enable --now rc-local.service
systemctl daemon-reload && systemctl restart systemd-modules-load.service
lsmod | grep ip_vs

# 设置vim
perl -pi -e 's/mouse=/mouse-=/g' /usr/share/vim/vim*/defaults.vim

# 禁用系统 swap
swapoff -a && sysctl -w vm.swappiness=0

# 系统优化
cat << EOF >  /etc/sysctl.conf
# https://www.kernel.org/doc/Documentation/sysctl/
#############################################################################################
# 调整虚拟内存
#############################################################################################
# Default: 30
# 0 - 任何情况下都不使用swap。
# 1 - 除非内存不足（OOM），否则不使用swap。
vm.swappiness = 0
# 内存分配策略
#0 - 表示内核将检查是否有足够的可用内存供应用进程使用；如果有足够的可用内存，内存申请允许；否则，内存申请失败，并把错误返回给应用进程。
#1 - 表示内核允许分配所有的物理内存，而不管当前的内存状态如何。
#2 - 表示内核允许分配超过所有物理内存和交换空间总和的内存
vm.overcommit_memory = 1
# OOM时处理
# 1关闭，等于0时，表示当内存耗尽时，内核会触发OOM killer杀掉最耗内存的进程。
vm.panic_on_oom = 0
# vm.dirty_background_ratio 用于调整内核如何处理必须刷新到磁盘的脏页。
# Default value is 10.
# 该值是系统内存总量的百分比，在许多情况下将此值设置为5是合适的。
# 此设置不应设置为零。
vm.dirty_background_ratio = 5
# 内核强制同步操作将其刷新到磁盘之前允许的脏页总数
# 也可以通过更改 vm.dirty_ratio 的值（将其增加到默认值30以上（也占系统内存的百分比））来增加
# 推荐 vm.dirty_ratio 的值在60到80之间。
vm.dirty_ratio = 60
# vm.max_map_count 计算当前的内存映射文件数。
# mmap 限制（vm.max_map_count）的最小值是打开文件的ulimit数量（cat /proc/sys/fs/file-max）。
# 每128KB系统内存 map_count应该大约为1。 因此，在126GB系统上，max_map_count为4128768。
# Default: 655360
vm.max_map_count = 655360
#############################################################################################
# 调整文件
#############################################################################################
# 增加文件句柄和inode缓存的大小，并限制核心转储。
fs.file-max = 655360
fs.nr_open = 655360
fs.suid_dumpable = 0
# 文件监控
fs.inotify.max_user_instances = 655360
fs.inotify.max_user_watches = 655360
fs.inotify.max_queued_events = 655360
#############################################################################################
# 调整网络设置
#############################################################################################
# 为每个套接字的发送和接收缓冲区分配的默认内存量。
net.core.wmem_default = 25165824
net.core.rmem_default = 25165824
# 为每个套接字的发送和接收缓冲区分配的最大内存量。
net.core.wmem_max = 25165824
net.core.rmem_max = 25165824
# 除了套接字设置外，发送和接收缓冲区的大小
# 必须使用net.ipv4.tcp_wmem和net.ipv4.tcp_rmem参数分别设置TCP套接字。
# 使用三个以空格分隔的整数设置这些整数，分别指定最小，默认和最大大小。
# 最大大小不能大于使用net.core.wmem_max和net.core.rmem_max为所有套接字指定的值。
# 合理的设置是最小4KiB，默认64KiB和最大2MiB缓冲区。
net.ipv4.tcp_wmem = 20480 12582912 25165824
net.ipv4.tcp_rmem = 20480 12582912 25165824
# 增加最大可分配的总缓冲区空间
# 以页为单位（4096字节）进行度量
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.udp_mem = 94500000 915000000 927000000
# 为每个套接字的发送和接收缓冲区分配的最小内存量。
net.ipv4.udp_wmem_min = 16384
net.ipv4.udp_rmem_min = 16384
# 提高同时接受连接数。
net.ipv4.tcp_max_syn_backlog = 655360
# 将net.core.netdev_max_backlog的值增加到大于默认值1000
# 可以帮助突发网络流量，特别是在使用数千兆位网络连接速度时，
# 通过允许更多的数据包排队等待内核处理它们。
net.core.netdev_max_backlog = 655360
# 每个CPU一次NAPI中断能够处理网络包数量的最大值
net.core.dev_weight = 600
# 增加选项内存缓冲区的最大数量
net.core.optmem_max = 25165824
# 被动TCP连接的SYNACK次数。
net.ipv4.tcp_synack_retries = 3
# 在内核放弃建立连接之前发送SYN包的数量
net.ipv4.tcp_syn_retries = 3
# 允许的本地端口范围。
net.ipv4.ip_local_port_range = 2048 65535
# 防止TCP时间等待
# Default: net.ipv4.tcp_rfc1337 = 0
net.ipv4.tcp_rfc1337 = 1
# 减少tcp_fin_timeout连接的时间默认值
net.ipv4.tcp_fin_timeout = 15
# 积压套接字的最大数量。
net.core.somaxconn = 655350
# 打开syncookies以进行SYN洪水攻击保护。
net.ipv4.tcp_syncookies = 1
# 检查过期多久邻居条目
net.ipv4.neigh.default.gc_stale_time = 120
# 避免Smurf攻击
# 发送伪装的ICMP数据包，目的地址设为某个网络的广播地址，源地址设为要攻击的目的主机，
# 使所有收到此ICMP数据包的主机都将对目的主机发出一个回应，使被攻击主机在某一段时间内收到成千上万的数据包
net.ipv4.icmp_echo_ignore_broadcasts = 1
# 为icmp错误消息打开保护
net.ipv4.icmp_ignore_bogus_error_responses = 1
# 启用自动缩放窗口。
# 如果延迟证明合理，这将允许TCP缓冲区超过其通常的最大值64K。
net.ipv4.tcp_window_scaling = 1
# 打开并记录欺骗，源路由和重定向数据包
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
# 告诉内核有多少个未附加的TCP套接字维护用户文件句柄。 万一超过这个数字，
# 孤立的连接会立即重置，并显示警告。
# Default: net.ipv4.tcp_max_orphans = 655360
net.ipv4.tcp_max_orphans = 655360
# 表示用于重组IP分段的内存分配最低值
net.ipv4.ipfrag_low_thresh = 196608
net.ipv6.ip6frag_low_thresh = 196608
# 允许域套接字中数据包的最大个数，在初始化unix域套接字时的默认值.
net.unix.max_dgram_qlen = 655350
# 路由缓存刷新频率,当一个路由失败后多长时间跳到另一个路由
net.ipv4.route.gc_timeout = 100
# 不要在关闭连接时缓存指标
net.ipv4.tcp_no_metrics_save = 1
# 启用RFC1323中定义的时间戳记：
# Default: net.ipv4.tcp_timestamps = 1
# 是否启用TCP时间戳
net.ipv4.tcp_timestamps = 1
# 启用选择确认。
# Default: net.ipv4.tcp_sack = 1
# 是否启用有选择的应答
net.ipv4.tcp_sack = 1
# 表示是否打开FACK拥塞避免和快速重传功能
net.ipv4.tcp_fack = 1
# 它是一个加强版的 TCP 重传超时的 recovery 算法. 0 表示禁用. 非 0 表示开启. 它是 sender only, 不要求对方也支持.
net.ipv4.tcp_frto = 2
# 接收数据时是否调整接收缓存
net.ipv4.tcp_moderate_rcvbuf = 1
# 开启TFO
net.ipv4.tcp_fastopen = 3
# 增加 tcp-time-wait 存储桶池大小，以防止简单的DOS攻击。
# net.ipv4.tcp_tw_recycle 已从Linux 4.12中删除。请改用net.ipv4.tcp_tw_reuse。
net.ipv4.tcp_max_tw_buckets = 655360
# 是否允许将处于TIME-WAIT状态的socket（TIME-WAIT的端口）用于新的TCP连接
net.ipv4.tcp_tw_reuse = 1
# accept_source_route 选项使网络接口接受设置了严格源路由（SSR）或松散源路由（LSR）选项的数据包。
# 以下设置将丢弃设置了SSR或LSR选项的数据包。
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
# 关闭反向路径过滤
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
# 禁用ICMP重定向接受
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
# 禁止发送所有IPv4 ICMP重定向数据包。
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
# 一旦发现相邻记录，至少在一段介于 base_reachable_time/2和3*base_reachable_time/2之间的随机时间内,该记录是有效的
net.ipv4.neigh.default.base_reachable_time_ms = 600000
# 在把记录标记为不可达之前,用多播/广播方式解析地址的最大次数
net.ipv4.neigh.default.mcast_solicit = 20
# 重发一个arp请求前的等待的毫秒数
net.ipv4.neigh.default.retrans_time_ms = 250
# 系统内核支持本地路由功能
net.ipv4.conf.all.route_localnet = 1
# IPVS相关设置
# SYN数据包会直接丢弃,等待客户端重新发送SYN
net.ipv4.vs.conntrack = 0
# 新连接进行重新调度
net.ipv4.vs.conn_reuse_mode = 1
# 后端rs不可用,会立即结束掉该连接,使客户端重新发起新的连接请求
net.ipv4.vs.expire_nodest_conn = 1
# 开启IPv4路由转发
net.ipv4.ip_forward = 1
net.ipv4.conf.default.forwarding = 1
net.ipv4.conf.all.forwarding = 1
# IPv6设置
#开启IPv6路由转发
net.ipv6.conf.default.forwarding = 1
net.ipv6.conf.all.forwarding = 1
# 禁用ICMP重定向接受
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
# 启用IPv6
# 默认是否在lo接口上禁用IPv6
net.ipv6.conf.default.disable_ipv6 = 0
# 是否在所有接口上禁用IPv6
net.ipv6.conf.all.disable_ipv6 = 0
# 是否在lo接口上禁用IPv6
net.ipv6.conf.lo.disable_ipv6 = 0
# 启用ipv6令居发现
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
# arp缓存
# 存在于 ARP 高速缓存中的最少层数，如果少于这个数，垃圾收集器将不会运行。缺省值是 128
net.ipv4.neigh.default.gc_thresh1 = 2048
# 保存在 ARP 高速缓存中的最多的记录软限制。垃圾收集器在开始收集前，允许记录数超过这个数字 5 秒。缺省值是 512
net.ipv4.neigh.default.gc_thresh2 = 4096
# 保存在 ARP 高速缓存中的最多记录的硬限制，一旦高速缓存中的数目高于此，垃圾收集器将马上运行。缺省值是 1024
net.ipv4.neigh.default.gc_thresh3 = 8192
# 垃圾收集器收集相邻层记录和无用记录的运行周期(单位 秒)
net.ipv4.neigh.default.gc_interval = 30
# 能放入代理 ARP 地址队列的数据包最大数目
net.ipv4.neigh.default.proxy_qlen = 96
# 最大挂起arp请求的数量
net.ipv4.neigh.default.unres_qlen = 6
# TCP流中重排序的数据报最大数量
net.ipv4.tcp_reordering = 6
# 如果设置满足RFC2861定义的行为,在从新开始计算拥塞窗口前延迟一些时间,这延迟的时间长度由当前rto决定
net.ipv4.tcp_slow_start_after_idle = 0
# 写这个文件就会刷新路由高速缓冲
net.ipv4.route.flush = 1
net.ipv6.route.flush = 1
# 持久连接
# 开启keepalive的闲置时长
net.ipv4.tcp_keepalive_time = 0
# keepalive探测包的发送间隔
net.ipv4.tcp_keepalive_intvl = 3
# 如果对方不予应答,探测包的发送次数
net.ipv4.tcp_keepalive_probes = 10
# conntrack表
# CONNTRACK_MAX 允许的最大跟踪连接条目，是在内核内存中netfilter可以同时处理的"任务"（连接跟踪条目）
# 以126G的64位操作系统为例,CONNTRACK_MAX = 126*1024*1024*1024/16384/2 = 4128768
net.nf_conntrack_max = 4128768
net.netfilter.nf_conntrack_max = 4128768
net.netfilter.nf_conntrack_buckets = 4128768
net.netfilter.nf_conntrack_tcp_timeout_fin_wait = 5
net.netfilter.nf_conntrack_tcp_timeout_time_wait = 5
net.netfilter.nf_conntrack_tcp_timeout_close_wait = 10
net.netfilter.nf_conntrack_tcp_timeout_established = 1200
# ECN : Explicit Congestion Notification . 显式拥塞通知. 只有两端都支持才起作用.
# 0 为禁用. 1 当接收ECN 时开启, 并且尝试也发送一个 ECN 出去. 2: 与 1 相似, 但不发送一个 ECN 出去.
net.ipv4.tcp_ecn = 1
# 当内核检测到一个错误有 ECN 行为, 则返回到非 ECN. 当上面的 tcp_ecn 开启的时候才起作用.
# net.ipv4.tcp_ecn_fallback = 1
# 启用BBRPLUS算法
# net.core.default_qdisc = fq
# net.ipv4.tcp_congestion_control = bbrplus
#############################################################################################
# 调整内核参数
#############################################################################################
# 使用sysrq组合键是了解系统目前运行情况，为安全起见设为0关闭
kernel.sysrq = 0
# 非屏蔽中断处理
kernel.unknown_nmi_panic = 0
# 控制core文件的文件名是否添加pid作为扩展
kernel.core_uses_pid = 1
# 允许更多的PID (减少滚动翻转问题)
kernel.pid_max = 655360
# 最大线程数
kernel.threads-max = 655360
# 每个消息队列的大小（单位：字节）限制
kernel.msgmnb = 655360
# 整个系统最大消息队列数量限制
kernel.msgmax = 655360
# 单个共享内存段的大小（单位：字节）限制，计算公式126G*1024*1024*1024(字节)
kernel.shmmax = 135291469824
# 所有内存大小（单位：页，1页 = 4Kb），计算公式126G*1024*1024*1024/4KB(页)
kernel.shmall = 33822867456
# 地址空间布局随机化（ASLR）是一种用于操作系统的内存保护过程，可防止缓冲区溢出攻击。
# 这有助于确保与系统上正在运行的进程相关联的内存地址不可预测，
# 因此，与这些流程相关的缺陷或漏洞将更加难以利用。
# Accepted values: 0 = 关闭, 1 = 保守随机化, 2 = 完全随机化
kernel.randomize_va_space = 2
# coredump
kernel.core_pattern = core
# 决定了检测到soft lockup时是否自动panic，缺省值是0
kernel.softlockup_all_cpu_backtrace = 1
kernel.softlockup_panic = 1
EOF
sysctl -p

# 卸载服务
apt-get -y purge --quiet=2 ufw
apt-get -y --purge --quiet=2 autoremove
apt-get clean

# 安装软件
DEBIAN_FRONTEND=noninteractive yes 'Y' | dpkg --configure -a
DEBIAN_FRONTEND=noninteractive yes 'Y' | apt-get -y update --fix-missing 
DEBIAN_FRONTEND=noninteractive yes 'Y' | apt-get -y dist-upgrade --fix-missing
DEBIAN_FRONTEND=noninteractive yes 'Y' | apt-get -y autoclean
DEBIAN_FRONTEND=noninteractive yes 'Y' | apt-get -y autoremove
