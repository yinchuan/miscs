#!/bin/bash
# mkvm
# 根据传入的name建立lv，vm
#

# 目标，根据提供的名字建立虚拟机，进行虚拟机初始化设置(hostname ip repo)

# 常量定义
LV_SIZE='4G'
LV_BASE='/dev/fedora/vm_base'
USAGE="$0 NAME"
EXIT_NO_NAME=1

# $1将作为kvm domain及lv的名字

if [ -z $1 ] ;then
    echo "$USAGE"
    exit "$EXIT_NO_NAME"
fi

NAME="$1"
LV_NAME="lv$NAME"

lvcreate -n "$LV_NAME" -s "$LV_BASE" -L "$LV_SIZE"

# if lvcreate succes
#   virsh create domain
# else 
#   echo "couldn't create lv"
