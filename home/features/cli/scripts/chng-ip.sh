#!/bin/bash

if [ `id -u` != 0 ] ; then
    echo "Please run this as root"
    exit 1
fi

if [ `sudo systemctl is-enabled tor` != "enabled" ] ; then
    sudo systemctl enable tor
fi

if [ `sudo systemctl status tor | grep -q "active (running)"` ] ; then
    sudo systemctl reload tor
else
    sudo systemctl start tor
fi


