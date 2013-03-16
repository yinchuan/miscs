* 原文地址: <http://linuxmoz.com/rhel-centos-install-puppet-nginx-unicorn/>

# 基于CentOS配置Puppet 3 + Unicorn + Nginx

How to <b>install Puppet 3 on CentOS / RHEL 6 with Unicorn & Nginx</b> for maximum efficiency. You can read more about why [Unicorn is great because it’s Unix][1], in short it’s a much better option than Webrick (very slow) and no more work to setup than Mongrel (in my opinion). In this tutorial I couple <b>Unicorn</b> with <b>Nginx</b> for optimial puppet master performance per dollar spent.

## Installing Puppet Labs RPM for CentOS 6

I use the Puppet Labs repo, you might want to use the [EPEL][2] Repo however this will install an older version of puppet and I am rolling out <b>Puppet 3</b> for my servers.
```
rpm -ivh http://yum.puppetlabs.com/el/6/products/i386/puppetlabs-release-6-6.noarch.rpm
```

Install the Puppet Master:
```
yum install puppet-server
```
Here is an example of Puppet deps on a CentOS 6 x86_64 minimal install:
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
Install the key when prompted:
```
warning: rpmts_HdrFromFdno: Header V4 RSA/SHA1 Signature, key ID 4bd6ec30: NOKEY
Retrieving key from file:///etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs
Importing GPG key 0x4BD6EC30:
 Userid : Puppet Labs Release Key (Puppet Labs Release Key) <info@puppetlabs.com>
 Package: puppetlabs-release-6-6.noarch (installed)
 From   : /etc/pki/rpm-gpg/RPM-GPG-KEY-puppetlabs
Is this ok [y/N]:
```
At this point open up <b>/etc/puppet/puppet.conf</b> (if it’s not there copy it from: /usr/share/puppet/ext/redhat/puppet.conf ) and add your server name, note this needs to be a FQDN or /etc/hosts hack like I have done in this lab.

Here is an example of my puppet.conf
puppet.conf
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

## Install Unicorn for the Pupper Master

[unicorn][3] is a HTTP server for Rack apps that utilizes features in Unix / Linux Kernels and in short is far more efficient than Mongrel / WEBrick, you can probably get away with using the Puppet default for now but why do half a job and implement something that is not going to scale?

In order for gem to build Unicorn, Rack & it’s deps you need to install some build tools using YUM:
```
yum install make gcc ruby-devel
```
Check the deps look sane and accept.

Install Unicorn via gem
```
gem install unicorn rack
```
Copy over the config.ru to /etc/puppet/
```
cp /usr/share/puppet/ext/rack/files/config.ru /etc/puppet/
```
Create the Unicorn config file:
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
Test that Unicorn us running the puppet master correctly:
```
cd /etc/puppet
unicorn -c unicorn.conf
```
You should get an output similar to:
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
Kill the above with ctrl+c

## Create an init script to start / stop the puppet master

Below is a basic init script to stop / start / restart the puppet masters unicorn process on CentOS, you can grab it from [my Github here][4].

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
    RETVAL=$?
    [ $RETVAL -eq 0 ] && touch "$lockfile"
    echo
    return $RETVAL
}

stop() {
    sudo -u $USER kill `cat $pidfile`
    RETVAL=$?
    echo
    [ $RETVAL -eq 0 ] && rm -f "$lockfile"
    return $RETVAL
}

restart() {
    stop
    sleep 1
    start
    RETVAL=$?
    echo
    [ $RETVAL -ne 0 ] && rm -f "$lockfile"
    return $RETVAL
}

condrestart() {
    status
    RETVAL=$?
    [ $RETVAL -eq 0 ] && restart
}

status() {
    ps ax | egrep -q "unicorn (worker|master)"
    RETVAL=$?
    return $RETVAL
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
You can now stop, start, restart the puppet master’s unicorn service with:
```
/etc/init.d/puppets-unicorn start
```
Confirm unicorn is running:
```
ps aux | grep unicorn
```
## Install Nginx for Puppetmaster Unicorn
If you don’t have it installed follow my [CentOS Nginx install][5] instructions, then drop the following config file in <b>/etc/nginx/conf.d/</b> and call it <b>puppets-unicorn</b>:
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
<em>You will need to change the cert file names to match your FQDN.</em>

Make sure the puppet unicorn service is running and start nginx:

```
/etc/init.d/nginx start
```
## Install Puppet client (Agent)

Next on a client (puppet Agent) machine install the Puppet Labs YUM repo and enter the following command to install the puppet client:

```
yum install puppet
```
## Configure the puppets to talk to the server

Make sure you can ping the puppetmaster & vice verse (if it’s not working the most likely cause is iptables), open up <b>/etc/puppet/puppet.conf</b> and add <b>server = puppet.your.com</b> to the [agent] section.

Here is an example of my puppet.conf:
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
## Sign the Puppet Agents Certificate

From the Agent (the client not the server) run:

Start / Restart puppet agent:

```
/etc/init.d/puppet restart
```
Say Hello to the puppet master (this sends the agent cert to the puppet master):

```
puppet agent puppet.cloud.local --test --waitforcert 60
```
replace puppet.cloud.local with your puppet master FQDN

Normally puppet returns the following: <b>Did not receive certificate</b>

Next on the puppet master (NOT the agent / client) run the following command:

```
puppet agent -l
```
This should give you an output like:
```
[root@puppet puppet]# puppet cert -l
  "agent.cloud.local" (SHA256) 18:7F:BE:EF:A2:C4:0A:14:BE:48:6F:85:2A:FA:82:7E:EF:CE:61:C2:D0:3B:AD:26:53:07:30:2A:83:2E:BD:B2
```
Sign the puppet certificate with:

```
puppet cert sign agent.cloud.local --waitforcert 60
```
This should return a message similar to:
```
Signed certificate request for agent.cloud.local
Removing file Puppet::SSL::CertificateRequest agent.cloud.local at '/var/lib/puppet/ssl/ca/requests/agent.cloud.local.pem'
```
## Test the Puppet Agent is working with the Puppet Master

To test the Puppet Agent can pull down the Puppet Masters catalog enter:

```
puppet agent --test
```
This should give you an output similar to:
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
To test this futher create some manifests and confirm they deploy to your puppet agents correctly.

Enjoy your highly efficient Puppet 3 server running Unicorn & Nginx!

Didn't answer your question? Get your [Linux Questions][6] answered.

[1]: http://tomayko.com/writings/unicorn-is-unix
[2]: http://linuxmoz.com/centos-epel-repo-install-tutorial/
[3]: http://unicorn.bogomips.org/
[4]: https://gist.github.com/4195166
[5]: http://linuxmoz.com/how-to-install-nginx-on-centos-rhel/
[6]: http://ask.linuxmoz.com/
