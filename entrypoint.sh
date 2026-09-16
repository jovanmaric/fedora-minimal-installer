#!/usr/bin/env bash

# mkksiso needs loop devices existing, which are
# ephemeral and not bakeable into the Dockerfile.
for i in $(seq 0 7); do
  [ -e /dev/loop$i ] || mknod -m 660 /dev/loop$i b 7 $i
  chown root:disk /dev/loop$i
done

exec "$@"
