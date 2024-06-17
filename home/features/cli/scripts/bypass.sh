#!/bin/bash

master_password="LokiBienchen651!"

# Run the pass command with the master password as input
echo "$master_password" | pass "$1"

