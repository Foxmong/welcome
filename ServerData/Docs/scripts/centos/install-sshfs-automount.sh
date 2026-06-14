#!/bin/bash
# CentOS VM (foxmong) — SSHFS 자동 마운트 설치
# 맥미니 ServerData → /mnt/serverdata, 부팅 시 자동 연결
#
# 사용법 (VM에서):
#   curl -O .../install-sshfs-automount.sh   # 또는 SFTP로 복사
#   chmod +x install-sshfs-automount.sh
#   ./install-sshfs-automount.sh
#
# 사전 조건:
#   - fuse-sshfs 설치됨 (epel-release → fuse-sshfs)
#   - /mnt/serverdata 존재, foxmong 쓰기 가능
#   - kimi@192.168.0.100 SSH 키 인증 완료 (ssh-copy-id)

set -euo pipefail

MAC_HOST="${MAC_HOST:-192.168.0.100}"
MAC_USER="${MAC_USER:-kimi}"
REMOTE_PATH="${REMOTE_PATH:-/Volumes/ServerData}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/serverdata}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519_serverdata}"
SSH_ALIAS="${SSH_ALIAS:-macmini-serverdata}"
SERVICE_NAME="serverdata-sshfs.service"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# CentOS Stream 10: fusermount3 (fuse3), 구버전: fusermount
if command -v fusermount3 &>/dev/null; then
  FUSERMOUNT="$(command -v fusermount3)"
elif command -v fusermount &>/dev/null; then
  FUSERMOUNT="$(command -v fusermount)"
else
  echo "오류: fusermount3/fusermount 없음. sudo dnf install -y fuse fuse-sshfs"
  exit 1
fi

echo "==> SSHFS 자동 마운트 설치"
echo "    원격: ${MAC_USER}@${MAC_HOST}:${REMOTE_PATH}"
echo "    마운트: ${MOUNT_POINT}"

# 1) 패키지
if ! command -v sshfs &>/dev/null; then
  echo "==> fuse-sshfs 설치"
  sudo dnf install -y epel-release
  sudo dnf install -y fuse-sshfs
fi

# 2) 마운트 포인트
if [[ ! -d "${MOUNT_POINT}" ]]; then
  sudo mkdir -p "${MOUNT_POINT}"
  sudo chown "$(whoami):$(whoami)" "${MOUNT_POINT}"
fi

# 3) SSH 키 (없으면 생성)
if [[ ! -f "${SSH_KEY}" ]]; then
  echo "==> SSH 키 생성: ${SSH_KEY}"
  ssh-keygen -t ed25519 -f "${SSH_KEY}" -N "" -C "foxmong-serverdata-sshfs"
  echo ""
  echo ">>> 다음 명령을 실행해 맥미니에 공개키를 등록하세요:"
  echo "    ssh-copy-id -i ${SSH_KEY}.pub ${MAC_USER}@${MAC_HOST}"
  echo ""
  read -r -p "ssh-copy-id 완료 후 Enter..." _
fi

# 4) SSH config
mkdir -p ~/.ssh
chmod 700 ~/.ssh
if ! grep -q "Host ${SSH_ALIAS}" ~/.ssh/config 2>/dev/null; then
  cat >> ~/.ssh/config <<EOF

Host ${SSH_ALIAS}
    HostName ${MAC_HOST}
    User ${MAC_USER}
    IdentityFile ${SSH_KEY}
    IdentitiesOnly yes
    ServerAliveInterval 15
    ServerAliveCountMax 3
EOF
  chmod 600 ~/.ssh/config
  echo "==> ~/.ssh/config 에 Host ${SSH_ALIAS} 추가"
fi

# 5) 연결 테스트
echo "==> SSH 연결 테스트"
ssh -o BatchMode=yes -o ConnectTimeout=10 "${SSH_ALIAS}" "echo OK: $(hostname)" \
  || { echo "오류: SSH 키 인증 실패. ssh-copy-id 먼저 실행하세요."; exit 1; }

# 6) 기존 마운트 해제 후 테스트 마운트
if mountpoint -q "${MOUNT_POINT}"; then
  fusermount -u "${MOUNT_POINT}" 2>/dev/null || sudo umount "${MOUNT_POINT}" 2>/dev/null || true
fi

echo "==> 테스트 마운트"
sshfs "${SSH_ALIAS}:${REMOTE_PATH}" "${MOUNT_POINT}" \
  -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,uid="$(id -u)",gid="$(id -g)"
ls "${MOUNT_POINT}" >/dev/null
echo "    마운트 OK: $(df -h "${MOUNT_POINT}" | tail -1)"
fusermount -u "${MOUNT_POINT}"

# 7) systemd user 서비스 설치
mkdir -p ~/.config/systemd/user
sed \
  -e "s|@SSH_ALIAS@|${SSH_ALIAS}|g" \
  -e "s|@REMOTE_PATH@|${REMOTE_PATH}|g" \
  -e "s|@MOUNT_POINT@|${MOUNT_POINT}|g" \
  "${SCRIPT_DIR}/serverdata-sshfs.service" > ~/.config/systemd/user/"${SERVICE_NAME}"

systemctl --user daemon-reload
systemctl --user enable "${SERVICE_NAME}"
systemctl --user start "${SERVICE_NAME}"

# 로그인 없이 부팅 시 user 서비스 실행
sudo loginctl enable-linger "$(whoami)" 2>/dev/null || true

echo ""
echo "==> 설치 완료"
systemctl --user status "${SERVICE_NAME}" --no-pager || true
echo ""
echo "유용한 명령:"
echo "  systemctl --user status ${SERVICE_NAME}"
echo "  systemctl --user restart ${SERVICE_NAME}"
echo "  mount | grep serverdata"
echo "  ls ${MOUNT_POINT}"
