#!/usr/bin/env bash

set -e

mkdir -p build

# Use devd for serving and reloading in browser
# Start devd here (and not as a modd daemon via modd.conf)
# Reason is we don't want to see verbose output
devd -olq . &

# Kill devd when this scripts exits.
# Warning: Will kill the browser too, it it is newly opened by "devd -o"
# http://stackoverflow.com/q/360201/2171779
devd_pid=$!
trap "echo 1; exit" INT TERM
trap "echo 2; kill -SIGHUP $devd_pid" EXIT

# Compile elm code. Configured in modd.conf
modd
