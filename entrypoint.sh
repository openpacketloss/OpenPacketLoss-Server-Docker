#!/bin/bash
set -e

# Start the WebRTC server in the background
webrtc-udp-test-server &
WEBRTC_PID=$!

# Start Nginx in the background
nginx -g 'daemon off;' &
NGINX_PID=$!

# Forward signals to both processes
trap 'kill $WEBRTC_PID $NGINX_PID 2>/dev/null; wait $WEBRTC_PID $NGINX_PID 2>/dev/null' TERM INT

# Wait for either process to exit
wait -n $WEBRTC_PID $NGINX_PID
EXIT_CODE=$?

# Clean up
kill $WEBRTC_PID $NGINX_PID 2>/dev/null
wait $WEBRTC_PID $NGINX_PID 2>/dev/null
exit $EXIT_CODE
