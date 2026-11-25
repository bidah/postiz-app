#!/usr/bin/env bash
pm2 delete all >/dev/null 2>&1 || true
nginx -s stop 2>/dev/null || true
pkill -f "temporal server" || true
redis-cli shutdown 2>/dev/null || true
pg_ctlcluster 15 main stop 2>/dev/null || true
