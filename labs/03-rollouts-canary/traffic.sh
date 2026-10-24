#!/usr/bin/env bash
# Hammer the canary host and print which colour answered, so you can see the traffic split.
# Usage: ./traffic.sh [requests] [port]
n="${1:-50}"; port="${2:-8880}"
for _ in $(seq "$n"); do
  curl -s -o /dev/null -w '%{http_code} ' "http://canary.localhost:${port}/color" >/dev/null
  curl -s "http://canary.localhost:${port}/color"; echo
done | sort | uniq -c
