# 맥미니 홈서버 — 운영 안정화 완료 일지

- **작성일:** 2026-06-14 (저녁 세션)
- **서버:** kimiui-Macmini + centos-server VM
- **작업자:** kimi
- **이전 일지:** [2026-06-15-macmini-server-setup.md](./2026-06-15-macmini-server-setup.md) (스크립트 준비), [2026-06-14-macmini-server-setup.md](./2026-06-14-macmini-server-setup.md) (Docker/Kuma)

---

## 1. 오늘 목표 · 결과

```text
목표   운영 안정화 (SSHFS 자동화, VM autostart, restic 확인)
결과   ████████████████████  100% 완료
```

| # | 작업 | 결과 |
|---|---|---|
| 1 | Uptime Kuma `~/docker` 이전 | ✅ |
| 2 | SSHFS 부팅 자동 마운트 | ✅ |
| 3 | VM 재부팅 검증 | ✅ |
| 4 | 맥 VM autostart (launchd) | ✅ |
| 5 | restic backup.log + 스냅샷 | ✅ |

---

## 2. Uptime Kuma — SSHFS 경로 이슈 해결

### 문제

`/mnt/serverdata/appdata/uptime-kuma` 에서 `docker compose up -d` 실패:

```text
error while creating mount source path '.../data':
mkdir /mnt/serverdata: file exists
```

**원인:** Docker bind mount는 SSHFS(FUSE) 경로에서 동작하지 않음.

### 해결

기존 data 유지, VM 로컬로 이전:

```bash
mkdir -p ~/docker/uptime-kuma/data
cp -a /mnt/serverdata/appdata/uptime-kuma/data/. ~/docker/uptime-kuma/data/
cd ~/docker/uptime-kuma && docker compose up -d
```

- **운영 경로:** `~/docker/uptime-kuma/` (compose + data)
- **백업/원본:** `/mnt/serverdata/appdata/uptime-kuma/` (삭제하지 않음)
- **접속:** `http://100.69.135.104:3001` — 기존 모니터·계정 유지

### 알림

Email/SMTP 알림 **사용 안 함** — 대시보드 모니터링만.

---

## 3. SSHFS 자동 마운트

### 스크립트 배포 (맥 → VM)

맥미니 `ServerData`에 스크립트 없음 → GitHub에서 curl 후 scp:

```bash
mkdir -p /Volumes/ServerData/Docs/scripts/centos
BASE="https://raw.githubusercontent.com/Foxmong/welcome/cursor/sshfs-automation-app-server-1fd4/ServerData/Docs/scripts/centos"
curl -fsSL "$BASE/install-sshfs-automount.sh" -o .../install-sshfs-automount.sh
curl -fsSL "$BASE/serverdata-sshfs.service" -o .../serverdata-sshfs.service
scp ... foxmong@192.168.0.113:~/
```

### VM 설치

```bash
sed -i 's/\r$//' ~/install-sshfs-automount.sh ~/serverdata-sshfs.service   # CRLF 제거
ssh-copy-id -i ~/.ssh/id_ed25519_serverdata.pub kimi@192.168.0.100
~/install-sshfs-automount.sh
```

### 이슈: `fusermount: 명령어를 찾을 수 없음`

CentOS Stream 10 → **`fusermount3`** 사용. 스크립트 중단 후 수동으로 systemd unit 작성:

```ini
ExecStop=/usr/bin/fusermount3 -u /mnt/serverdata
```

```bash
systemctl --user enable --now serverdata-sshfs.service
sudo loginctl enable-linger foxmong
```

### 재부팅 검증 (2026-06-14 18:09 KST)

```text
mount | grep serverdata
  → macmini-serverdata:/Volumes/ServerData on /mnt/serverdata type fuse.sshfs

serverdata-sshfs.service
  → active (running)
  → 부팅 직후 1회 실패(18:09:06) → 13초 후 재시작 성공(18:09:19) — Restart=on-failure 정상
```

---

## 4. 맥 VM autostart (launchd)

```bash
curl -fsSL .../install-vm-autostart.sh -o ~/install-vm-autostart.sh
sed -i '' 's/\r$//' ~/install-vm-autostart.sh    # macOS CRLF 제거
~/install-vm-autostart.sh
```

**결과:**

```text
VBoxManage: /usr/local/bin/VBoxManage
plist: ~/Library/LaunchAgents/com.kimi.centos-vm-autostart.plist
launchctl: com.kimi.centos-vm-autostart 등록
VBoxManage list runningvms → centos-server running
```

**참고:** VM이 이미 켜진 상태에서 `startvm` 실행 시 launchd exit 78 — 정상(무시).

---

## 5. restic 백업

### cron (기존)

```cron
0 3 * * * /Users/kimi/scripts/backup.sh >> /Volumes/ServerBackup/logs/backup.log 2>&1
```

### 오늘 확인

```bash
mkdir -p /Volumes/ServerBackup/logs
~/scripts/backup.sh >> /Volumes/ServerBackup/logs/backup.log 2>&1
```

**스냅샷:**

| ID | 시간 | 크기 |
|---|---|---|
| 894c5363 | 2026-06-14 16:04 | 6.495 KiB (초기 테스트) |
| 05583a46 | 2026-06-14 18:13 | **5.035 GiB** (실데이터) |

`forget --prune` 정상 완료. **내일 03:00 이후** `tail backup.log`로 cron 자동 실행만 추가 확인.

---

## 6. 교훈 · 트러블슈팅

| 증상 | 원인 | 해결 |
|---|---|---|
| `bad interpreter: /bin/bash^M` | curl 스크립트 CRLF | Mac: `sed -i '' 's/\r$//'` / Linux: `sed -i 's/\r$//'` |
| `fusermount: 명령어를 찾을 수 없음` | CentOS Stream 10 | `fusermount3` 사용 |
| Docker + `/mnt/serverdata/...` | SSHFS + bind 불가 | `~/docker/` 로컬 |
| SSHFS 부팅 1회 실패 | 맥 SSH 준비 전 | systemd `Restart=on-failure` — 자동 복구 |
| `backup.log` 없음 | cron 03:00 전 + logs 미생성 | `mkdir -p .../logs` + 수동 1회 실행 |

---

## 7. 현재 진행률

```text
[핵심 구축]     ████████████████████  100%
[운영 안정화]   ████████████████████  100%  ← 오늘 완료
[앱 서버 확장]  ████░░░░░░░░░░░░░░░░  ~20%
```

---

## 8. 다음 작업

```text
[ ] 내일: tail /Volumes/ServerBackup/logs/backup.log (cron 03:00)
[ ] whoami ~/docker/myapp 배포
[ ] Cloudflare Tunnel + 도메인
[ ] (선택) NPM, SMB fileshare 계정, cron→launchd
```

---

## 9. 자주 쓰는 명령 (업데이트)

### VM

```bash
systemctl --user status serverdata-sshfs.service
mount | grep serverdata
cd ~/docker/uptime-kuma && docker compose up -d
```

### 맥

```bash
launchctl list | grep centos
VBoxManage list runningvms
tail /Volumes/ServerBackup/logs/backup.log
restic -r /Volumes/ServerBackup/restic-repo snapshots
```

---

*2026-06-14 운영 안정화 세션 완료 기록.*
