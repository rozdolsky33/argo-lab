#!/usr/bin/env bash
# Generate steady traffic so Prometheus has request-rate data for the analysis.
port="${1:-8880}"
echo "Sending traffic to analysis.localhost:${port} (Ctrl-C to stop)"
while true; do curl -s -o /dev/null "http://analysis.localhost:${port}/color"; sleep 0.1; done
