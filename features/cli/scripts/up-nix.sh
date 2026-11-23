#!/usr/bin/env bash

export NIXPKGS_ALLOW_INSECURE=1
nh os switch
home-manager switch --impure -b backup --flake .#hugob@amaterasu
