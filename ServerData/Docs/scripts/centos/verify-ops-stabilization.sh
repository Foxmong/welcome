#!/bin/bash
# CentOS VM — 운영 안정화 검증 (SSHFS + Docker Kuma)
set -euo pipefail

OK=0
WARN=0

check() {
  local name="$1"
  shift
  if "$@"; then
    echo "[OK]   ${name}"
  else
    echo "[FAIL] ${name}"
    OK=1
  fi
}

warn() {
  local name="$1"
  shift
  if "$@"; then
    echo "[OK]   ${name}"
  else
    echo "[WARN] ${name}"
    WARN=1
  fi
}

echo "=== 운영 안정화 검증 (VM) ==="

check "SSHFS 마운트" mountpoint -q /mnt/serverdata
check "serverdata 목록" test -d /mnt/serverdata/Shared
check "SSHFS systemd active" systemctl --user is-active --quiet serverdata-sshfs.service
warn "linger foxmong" bash -c '[[ "$(loginctl show-user foxmong -p Linger --value 2>/dev/null)" == "yes" ]]'

check "docker 실행" systemctl is-active --quiet docker
check "uptime-kuma 컨테이너" docker ps --format '{{.Names}}' | grep -qx uptime-kuma
warn "Kuma HTTP" curl -sf -o /dev/null -w '' --max-time 5 http://127.0.0.1:3001/

echo ""
mount | grep serverdata || echo "(SSHFS 마운트 없음)"
docker ps --filter name=uptime-kuma --format 'table {{.Names}}\t{{.Status}}' 2>/dev/null || true

echo ""
if [[ ${OK} -eq 0 ]]; then
  echo "=== VM 검증 통과 ==="
  exit 0
else
  echo "=== VM 검증 실패 — ops-stabilization.md 참고 ==="
  exit 1
fi
