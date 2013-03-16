# 用bash写apache cgi程序
## 修改apache配置

    vi httpd.conf
        /var/www/html
            Options ExecCGI
        AddHandler 取消注释
        DirectoryIndex index.cgi
## 编辑显示主机名的测试代码

    vi /var/www/html/index.cgi
    
    #!/bin/bash
    #
    
    echo "Content-type: text/plain"
    echo ""
    
    hostname
    
    exit 0
