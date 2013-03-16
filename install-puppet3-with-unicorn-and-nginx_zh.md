* 原文地址: <http://linuxmoz.com/rhel-centos-install-puppet-nginx-unicorn/>

# 基于CentOS配置Puppet 3 + Unicorn + Nginx

如何<b>基于CentOS/RHEL6 配置Puppet 3 + Unicorn + Nginx</b>达到最大性能. 你可以读到为什么[Unicorn因Unix而伟大][1], 简而言之这是比Webrick (非常慢)更好的选择，又不像Mongrel (在我看来)需要很多设置的。在此手册中，我利用<b>Unicorn</b>和<b>Nginx</b>实现puppet master单位美元最大性能。

## 在CentOS 6上安装Puppet Labs的RPM包

我使用Puppet Labs的源。你也可以使[EPEL][2]源，但这将安装老版的puppet而我想在服务器上使用新版本<b>Puppet 3</b>。
```
rpm -ivh http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-6.noarch.rpm
```

安装Puppet Master:
```
yum install puppet-server
```
这是Puppet在CentOS 6 x86_64系统最小化安装上的依赖:
```
Dependencies Resolved

======================================================================================================================================================
 Package                              Arch                       Version                                Repository                               Size
======================================================================================================================================================
Installing:
 puppet-server                        noarch                     3.0.1-1.el6                            puppetlabs-products                      22 k
Installing for dependencies:
 augeas-libs                          x86_64                     0.9.0-4.el6                            base                                    317 k
 compat-readline5                     x86_64                     5.2-17.1.el6                           base                                    130 k
 dmidecode                            x86_64                     1:2.11-2.el6                           base                                     71 k
 facter                               x86_64                     1:1.6.14-1.el6                         puppetlabs-products                      58 k
 hiera                                noarch                     1.1.1-1.el6                            puppetlabs-products                      19 k
 libselinux-ruby                      x86_64                     2.0.94-5.3.el6                         base                                     99 k
 pciutils                             x86_64                     3.1.4-11.el6                           base                                     83 k
 puppet                               noarch                     3.0.1-1.el6                            puppetlabs-products                     890 k
 ruby                                 x86_64                     1.8.7.352-7.el6_2                      base                                    532 k
 ruby-augeas                          x86_64                     0.4.1-1.el6                            puppetlabs-deps                          21 k
 ruby-irb                             x86_64                     1.8.7.352-7.el6_2                      base                                    311 k
 ruby-libs                            x86_64                     1.8.7.352-7.el6_2                      base                                    1.6 M
 ruby-rdoc                            x86_64                     1.8.7.352-7.el6_2                      base                                    375 k
 ruby-shadow                          x86_64                     1.4.1-13.el6                           puppetlabs-deps                          11 k
 rubygem-json                         x86_64                     1.4.6-1.el6                            puppetlabs-deps                         457 k
 rubygems                             noarch                     1.3.7-1.el6                            base                                    206 k

Transaction Summary
======================================================================================================================================================
Install      17 Package(s)

Total download size: 5.2 M
Installed size: 16 M
Is this ok [y/N]:
```
出现提示时安装key:
```
warning: rpmts_HdrFromFdno: Header V4 RSA/SHA1 Signature, key ID 4bd6ec30: NOKEY
Retrieving key from file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs
Importing GPG key 0x4BD6EC30:
 Userid : Puppet Labs Release Key (Puppet Labs Release Key) <info@puppetlabs.com>
 Package: puppetlabs-release-6-6.noarch (installed)
 From   : /etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs
Is this ok [y/N]:
```
安装完成后打开<b>/etc/puppet/puppet.conf</b> (如果没有可以从这里拷贝: /usr/share/puppet/ext/redhat/puppet.conf )添加你服务器的主机名, 注意这需要是FQDN或者像我一样在/etc/hosts中设置。

这是我的puppet.conf示例
```
[main]
    # The Puppet log directory.
    # The default value is '$vardir/log'.
    logdir = /var/log/puppet

    # Where Puppet PID files are kept.
    # The default value is '$vardir/run'.
    rundir = /var/run/puppet

    # Where SSL certificates are kept.
    # The default value is '$confdir/ssl'.
    ssldir = $vardir/ssl
    server = puppet.cloud.local

[agent]
    # The file in which puppetd stores a list of the classes
    # associated with the retrieved configuratiion.  Can be loaded in
    # the separate ``puppet`` executable using the ``--loadclasses``
    # option.
    # The default value is '$confdir/classes.txt'.
    classfile = $vardir/classes.txt

    # Where puppetd caches the local configuration.  An
    # extension indicating the cache format is added automatically.
    # The default value is '$confdir/localconfig'.
    localconfig = $vardir/localconfig
```

## 在Pupper Master上安装Unicorn

[unicorn][3]是一个Rack apps的HTTP服务器，充分利用了Unix / Linux的内核特性，简单来说远比Mongrel和WEBrick更有效率，你可能想要立即使用默认配置的Puppet，但为什么只做半截工作实现一个无法扩展的东西？

为了使用gem安装Unicorn、Rack及其依赖，要用YUM安装一些编译工具：
```
yum install make gcc ruby-devel
```
仔细检查依赖并接受.

使用gem安装Unicorn
```
gem install unicorn rack
```
拷贝config.ru到/etc/puppet/
```
cp /usr/share/puppet/ext/rack/files/config.ru /etc/puppet/
```
创建Unicorn配置文件:
```
touch /etc/puppet/unicorn.conf
```
```
 worker_processes 8
    working_directory "/etc/puppet"
    listen '/var/run/puppet/puppetmaster_unicorn.sock', :backlog => 512
    timeout 120
    pid "/var/run/puppet/puppetmaster_unicorn.pid"

    preload_app true
    if GC.respond_to?(:copy_on_write_friendly=)
      GC.copy_on_write_friendly = true
    end

    before_fork do |server, worker|
      old_pid = "#{server.config[:pid]}.oldbin"
      if File.exists?(old_pid) && server.pid != old_pid
        begin
          Process.kill("QUIT", File.read(old_pid).to_i)
        rescue Errno::ENOENT, Errno::ESRCH
          # someone else did our job for us
        end
      end
    end
```
测试Unicorn能够正常地运行puppet master:
```
cd /etc/puppet
unicorn -c unicorn.conf
```
你将得到类似以下输出:
```
[root@puppet puppet]# sudo unicorn -c unicorn.conf
I, [2012-12-01T17:06:10.961269 #3600]  INFO -- : Refreshing Gem list
I, [2012-12-01T17:06:12.108620 #3600]  INFO -- : unlinking existing socket=/var/run/puppet/puppetmaster_unicorn.sock
I, [2012-12-01T17:06:12.109171 #3600]  INFO -- : listening on addr=/var/run/puppet/puppetmaster_unicorn.sock fd=6
I, [2012-12-01T17:06:12.112182 #3604]  INFO -- : worker=0 spawned pid=3604
I, [2012-12-01T17:06:12.113449 #3605]  INFO -- : worker=1 spawned pid=3605
I, [2012-12-01T17:06:12.113944 #3604]  INFO -- : worker=0 ready
I, [2012-12-01T17:06:12.115137 #3605]  INFO -- : worker=1 ready
I, [2012-12-01T17:06:12.116153 #3606]  INFO -- : worker=2 spawned pid=3606
I, [2012-12-01T17:06:12.116878 #3607]  INFO -- : worker=3 spawned pid=3607
I, [2012-12-01T17:06:12.118506 #3606]  INFO -- : worker=2 ready
I, [2012-12-01T17:06:12.118879 #3607]  INFO -- : worker=3 ready
I, [2012-12-01T17:06:12.119553 #3608]  INFO -- : worker=4 spawned pid=3608
I, [2012-12-01T17:06:12.121228 #3609]  INFO -- : worker=5 spawned pid=3609
I, [2012-12-01T17:06:12.122360 #3608]  INFO -- : worker=4 ready
I, [2012-12-01T17:06:12.122711 #3610]  INFO -- : worker=6 spawned pid=3610
I, [2012-12-01T17:06:12.122829 #3609]  INFO -- : worker=5 ready
I, [2012-12-01T17:06:12.123426 #3600]  INFO -- : master process ready
I, [2012-12-01T17:06:12.124551 #3610]  INFO -- : worker=6 ready
I, [2012-12-01T17:06:12.125002 #3611]  INFO -- : worker=7 spawned pid=3611
I, [2012-12-01T17:06:12.126546 #3611]  INFO -- : worker=7 ready
```
按ctrl+c结束

## 创建用来启动/停止puppet maste的init脚本

以下是一个基本的init脚本，用来在CentOS上stop / start / restart puppet masters的unicorn进程,你可以从[我的Github][4]得到。

```
/etc/init.d/puppets-unicorn
#!/bin/bash
# unicorn-puppet
lockfile=/var/lock/puppetmaster-unicorn
pidfile=/var/run/puppet/puppetmaster_unicorn.pid

RETVAL=0
DAEMON=/usr/bin/unicorn
DAEMON_OPTS="-D -c /etc/puppet/unicorn.conf"


start() {
    sudo -u $USER $DAEMON $DAEMON_OPTS
    RETVAL=$?    [ $RETVAL -eq 0 ] && touch "$lockfile"
    echo
    return $RETVAL
}

stop() {
    sudo -u $USER kill `cat $pidfile`
    RETVAL=$?    echo
    [ $RETVAL -eq 0 ] && rm -f "$lockfile"
    return $RETVAL
}

restart() {
    stop
    sleep 1
    start
    RETVAL=$?    echo
    [ $RETVAL -ne 0 ] && rm -f "$lockfile"
    return $RETVAL
}

condrestart() {
    status
    RETVAL=$?    [ $RETVAL -eq 0 ] && restart
}

status() {
    ps ax | egrep -q "unicorn (worker|master)"
    RETVAL=$?    return $RETVAL
}

usage() {
    echo "Usage: $0 {start|stop|restart|status|condrestart}" >&2
    return 3
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        restart
        ;;
    condrestart)
        condrestart
        ;;
    status)
        status
        ;;
    *)
        usage
        ;;
esac

exit $RETVAL
```
你现在可以用以下命令停止, 启动, 重启puppet master的unicorn服务:
```
/etc/init.d/puppets-unicorn start
```
确认unicorn正在运行:
```
ps aux | grep unicorn
```
## 为Puppetmaster Unicorn安装Nginx
如果你没有根据我的[教程][5]安装Nginx, 在<b>/etc/nginx/conf.d/</b>下新建<b>puppets-unicorn.conf</b>文件，添加以下配置:
```
upstream puppetmaster_unicorn {
    server unix:/var/run/puppet/puppetmaster_unicorn.sock fail_timeout=0;
}

server {
    listen 8140;

    ssl on;
    ssl_session_timeout 5m;
    ssl_certificate /var/lib/puppet/ssl/certs/puppet.cloud.local.pem;
    ssl_certificate_key /var/lib/puppet/ssl/private_keys/puppet.cloud.local.pem;
    ssl_client_certificate /var/lib/puppet/ssl/ca/ca_crt.pem;
    ssl_ciphers SSLv2:-LOW:-EXPORT:RC4+RSA;
    ssl_verify_client optional;

    root /usr/share/empty;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Client-Verify $ssl_client_verify;
    proxy_set_header X-Client-DN $ssl_client_s_dn;
    proxy_set_header X-SSL-Issuer $ssl_client_i_dn;
    proxy_read_timeout 120;

    location / {
        proxy_pass http://puppetmaster_unicorn;
        proxy_redirect off;
    }
}
```
<em>你可能需要将证书文件名修改为你的FQDN.</em>

确认puppet unicorn正在运行并启动nginx

```
/etc/init.d/nginx start
```
## 安装Puppet客户端(Agent)

接下来在客户端机器(puppet Agent)上安装Puppet Labs YUM源，用以下命令来安装puppet客户端:

```
yum install puppet
```
## 配置puppets与服务器通信

确定你能够ping通puppetmaster，反过来也一样(如果不行，最有可能是iptables引起), 在<b>/etc/puppet/puppet.conf</b>中添加<b>server = puppet.your.com</b>到[agent]节.

这是我的puppet.conf示例:
```
puppet.conf
[main]
    # The Puppet log directory.
    # The default value is '$vardir/log'.
    logdir = /var/log/puppet

    # Where Puppet PID files are kept.
    # The default value is '$vardir/run'.
    rundir = /var/run/puppet

    # Where SSL certificates are kept.
    # The default value is '$confdir/ssl'.
    ssldir = $vardir/ssl

[agent]
    # The file in which puppetd stores a list of the classes
    # associated with the retrieved configuratiion.  Can be loaded in
    # the separate ``puppet`` executable using the ``--loadclasses``
    # option.
    # The default value is '$confdir/classes.txt'.
    classfile = $vardir/classes.txt

    # Where puppetd caches the local configuration.  An
    # extension indicating the cache format is added automatically.
    # The default value is '$confdir/localconfig'.
    localconfig = $vardir/localconfig
    server = puppet.cloud.local
```
## 为Puppet Agents证书签名

在Agent (客户端而不是服务器上)运行:

启动/重启puppet agent:

```
/etc/init.d/puppet restart
```
连接到puppet master(这将把agent证书发送到puppet master):

```
puppet agent puppet.cloud.local --test --waitforcert 60
```
将puppet.cloud.local替换成你自己puppet master的FQDN

通常puppet返回以下内容: <b>Did not receive certificate</b>

接下来在puppet master (不是agent或者client)上执行以下命令:

```
puppet agent -l
```
这将给出类似如下输出:
```
[root@puppet puppet]# puppet cert -l
  "agent.cloud.local" (SHA256) 18:7F:BE:EF:A2:C4:0A:14:BE:48:6F:85:2A:FA:82:7E:EF:CE:61:C2:D0:3B:AD:26:53:07:30:2A:83:2E:BD:B2
```
用以下命令给puppet证书签名:

```
puppet cert sign agent.cloud.local --waitforcert 60
```
这将给出类似如下输出:
```
Signed certificate request for agent.cloud.local
Removing file Puppet::SSL::CertificateRequest agent.cloud.local at '/var/lib/puppet/ssl/ca/requests/agent.cloud.local.pem'
```
## 测试Puppet Agent与Puppet Master正常工作

为了测试Puppet Agent，可以从Puppet Masters拉取catalog:


```
puppet agent --test
```
这将给出类似如下输出:
```
[root@agent puppet]# puppet agent --test 
Info: Caching certificate for agent.cloud.local
Info: Caching certificate_revocation_list for ca
Info: Retrieving plugin
Info: Caching catalog for agent.cloud.local
Info: Applying configuration version '1354510955'
Info: Creating state file /var/lib/puppet/state/state.yaml
Finished catalog run in 0.05 seconds
```
为了进一步测试，创建一些manifest并确认被正确部署到puppet agents。

享受运行Unicorn和Nginx的高性能Puppet 3服务器吧!

没有解决你的问题?得到你的[Linux Questions][6]的答案。

[1]: http://tomayko.com/writings/unicorn-is-unix
[2]: http://linuxmoz.com/centos-epel-repo-install-tutorial/
[3]: http://unicorn.bogomips.org/
[4]: https://gist.github.com/4195166
[5]: http://linuxmoz.com/how-to-install-nginx-on-centos-rhel/
[6]: http://ask.linuxmoz.com/
