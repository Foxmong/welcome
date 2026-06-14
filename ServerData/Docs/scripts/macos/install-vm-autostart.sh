#!/bin/bash
# 맥미니 — CentOS VM 부팅 시 자동 시작 (launchd)
set -euo pipefail

LABEL="com.kimi.centos-vm-autostart"
VM_NAME="${VM_NAME:-centos-server}"
LOG_DIR="/Volumes/ServerBackup/logs"
LOG_FILE="${LOG_DIR}/vm-autostart.log"
PLIST_DEST="${HOME}/Library/LaunchAgents/${LABEL}.plist"

# VBoxManage 찾기
if command -v VBoxManage &>/dev/null; then
  VBOX="$(command -v VBoxManage)"
elif [[ -x /Applications/VirtualBox.app/Contents/MacOS/VBoxManage ]]; then
  VBOX="/Applications/VirtualBox.app/Contents/MacOS/VBoxManage"
else
  echo "오류: VBoxManage를 찾을 수 없습니다. VirtualBox 설치 확인."
  exit 1
fi

echo "==> VBoxManage: ${VBOX}"
"${VBOX}" list vms | grep -q "\"${VM_NAME}\"" || {
  echo "오류: VM '${VM_NAME}' 없음. VBoxManage list vms 로 이름 확인."
  exit 1
}

mkdir -p "${LOG_DIR}" "${HOME}/Library/LaunchAgents"

cat > "${PLIST_DEST}" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${VBOX}</string>
    <string>startvm</string>
    <string>${VM_NAME}</string>
    <string>--type</string>
    <string>headless</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StartInterval</key>
  <integer>300</integer>
  <key>StandardOutPath</key>
  <string>${LOG_FILE}</string>
  <key>StandardErrorPath</key>
  <string>${LOG_FILE}</string>
</dict>
</plist>
EOF

# 기존 로드 해제 후 재로드
launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || \
  launchctl unload "${PLIST_DEST}" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "${PLIST_DEST}" 2>/dev/null || \
  launchctl load "${PLIST_DEST}"

echo "==> plist 설치: ${PLIST_DEST}"
echo "==> VM 시작 시도..."
"${VBOX}" startvm "${VM_NAME}" --type headless 2>/dev/null || true
sleep 2
"${VBOX}" list runningvms

echo ""
echo "완료. 확인:"
echo "  launchctl list | grep centos"
echo "  tail ${LOG_FILE}"
