#!/usr/bin/env bash

mv "$1" "$1"_tmp
sudo git submodule deinit "$1"
sudo git rm -r --cached "$1"
mv "$1"_tmp "$1"
sudo git add "$1"
