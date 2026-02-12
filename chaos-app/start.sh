#!/bin/sh
# Set the hostname to bind to all interfaces
export HOSTNAME=0.0.0.0
exec node server.js "$@"
