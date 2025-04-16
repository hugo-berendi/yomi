#!/usr/bin/bash
nix shell .#packages."x86_64-linux".octodns-sync --command octodns-sync --doit
