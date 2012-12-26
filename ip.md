# ip
查看ip信息

    ip addr
    ip addr show dev p2p1
添加ip

    ip addr del 192.168.100.100/24 dev p2p1
删除ip

    ip addr del 192.168.100.100/32 dev p2p1
查看路由

    ip route 
添加路由

    ip route add default via 192.168.0.1
    ip route add 8.8.8.8 via 192.168.0.1
    ip route add 8.8.8.0/24 via 192.168.0.1
删除路由

    ip route del    删除默认网关
    ip route del 8.8.8.0/24
设置MTU 

    ip link set dev p2p1 mtu 1500
