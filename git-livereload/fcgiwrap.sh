#!/usr/bin/env bash
set -eou pipefail

echo "Ensuring no stale socket exists..."
rm -f /var/run/fcgiwrap.socket

# Start fcgiwrap
fcgiwrap -s unix:/var/run/fcgiwrap.socket &

# Wait for the socket to be created
while [ ! -S /var/run/fcgiwrap.socket ]; do
  sleep 0.1
done

# Keep the script running to not exit and hence keep the service running
wait
