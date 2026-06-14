# 운영 안정화 — 실행 가이드

> **목표:** 재부팅해도 SSHFS·VM·백업이 자동으로 돌아가게 만들기.  
> **순서:** ① VM SSHFS 자동화 → ② 맥 VM autostart → ③ restic cron 확인 → ④ 재부팅 검증

---

## 체크리스트

> **2026-06-14 완료** — 상세: [setup-logs/2026-06-14-ops-stabilization.md](../setup-logs/2026-06-14-ops-stabilization.md)

```text
[x] 1. VM — SSHFS 자동 마운트 (install-sshfs-automount.sh)
[x] 2. VM — 재부팅 후 /mnt/serverdata 확인
[x] 3. 맥 — CentOS VM autostart (launchd)
[x] 4. 맥 — restic cron / backup.log 확인
[x] 5. VM — Uptime Kuma ~/docker/uptime-kuma 기동
[ ] 6. 맥 — 내일 03:00 cron backup.log 자동 실행 확인
```

---

## 1. VM — SSHFS 자동 마운트

**위치:** CentOS VM (`foxmong@centos-server`)

### 1-1. 스크립트 복사 (맥미니에서)

```bash
scp /Volumes/ServerData/Docs/scripts/centos/install-sshfs-automount.sh \
    /Volumes/ServerData/Docs/scripts/centos/serverdata-sshfs.service \
    foxmong@192.168.0.113:~/
```

Tailscale만 쓸 때:

```bash
scp /Volumes/ServerData/Docs/scripts/centos/install-sshfs-automount.sh \
    /Volumes/ServerData/Docs/scripts/centos/serverdata-sshfs.service \
    foxmong@100.69.135.104:~/
```

### 1-2. 설치 (VM에서)

```bash
chmod +x ~/install-sshfs-automount.sh
~/install-sshfs-automount.sh
```

**ssh-copy-id 안내가 나오면** (최초 1회):

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_serverdata.pub kimi@192.168.0.100
# kimi 비밀번호 1회 입력 후, 설치 스크립트 다시 실행
~/install-sshfs-automount.sh
```

### 1-3. 확인

```bash
systemctl --user status serverdata-sshfs.service
mount | grep serverdata
ls /mnt/serverdata
loginctl show-user foxmong -p Linger   # yes 여야 부팅 시 자동
```

---

## 2. VM — 재부팅 검증

```bash
sudo reboot
```

재접속 후:

```bash
mount | grep serverdata
ls /mnt/serverdata/Shared
systemctl --user is-active serverdata-sshfs.service
cd ~/docker/uptime-kuma && docker ps
curl -sI http://127.0.0.1:3001 | head -1
```

**완료 기준:** SSHFS 마운트됨 + Kuma `HTTP/1.1 302` 또는 `200`

---

## 3. 맥 — VM 자동 시작 (launchd)

**위치:** 맥미니 (`kimi@kimiui-Macmini`)

### 방법 A — 설치 스크립트 (권장)

```bash
/Volumes/ServerData/Docs/scripts/macos/install-vm-autostart.sh
```

### 방법 B — 수동

```bash
# VBoxManage 경로 확인
which VBoxManage
# 없으면: /Applications/VirtualBox.app/Contents/MacOS/VBoxManage

mkdir -p /Volumes/ServerBackup/logs
cp /Volumes/ServerData/Docs/scripts/macos/com.kimi.centos-vm-autostart.plist \
   ~/Library/LaunchAgents/
# plist 안 VBoxManage 경로가 which 결과와 다르면 수정

launchctl load ~/Library/LaunchAgents/com.kimi.centos-vm-autostart.plist
launchctl list | grep centos
VBoxManage list runningvms
```

**완료 기준:** `centos-server` running (또는 5분 이내 StartInterval로 기동)

---

## 4. 맥 — restic cron / backup.log

```bash
crontab -l
# 0 3 * * * /Users/kimi/scripts/backup.sh ...

ls -la /Volumes/ServerBackup/logs/backup.log
tail -50 /Volumes/ServerBackup/logs/backup.log
restic -r /Volumes/ServerBackup/restic-repo snapshots
```

**로그가 비어 있거나 오래됐으면** 수동 1회 실행:

```bash
~/scripts/backup.sh
tail -20 /Volumes/ServerBackup/logs/backup.log
```

**완료 기준:** `snapshots`에 최근 날짜 + log에 error 없음

---

## 5. 문제 해결

| 증상 | 해결 |
|---|---|
| SSHFS `Permission denied (publickey)` | `ssh-copy-id -i ~/.ssh/id_ed25519_serverdata.pub kimi@192.168.0.100` |
| 부팅 후 SSHFS 없음 | `loginctl enable-linger foxmong` (VM), 서비스 `Restart=on-failure` 확인 |
| 맥 부팅 후 VM 꺼짐 | launchd plist 경로·VBoxManage 경로 확인 |
| VM은 켜졌는데 Kuma Down | `cd ~/docker/uptime-kuma && docker compose up -d` |
| backup.log 없음 | cron 등록 확인, `mkdir -p /Volumes/ServerBackup/logs` |

---

## 관련 파일

| 파일 | 용도 |
|---|---|
| [vm-sshfs-automount.md](./vm-sshfs-automount.md) | SSHFS 상세 |
| `scripts/centos/install-sshfs-automount.sh` | VM 설치 |
| `scripts/macos/install-vm-autostart.sh` | 맥 VM autostart |
| `scripts/centos/verify-ops-stabilization.sh` | VM 검증 한 번에 |

---

## 맥미니 경로

```text
/Volumes/ServerData/Docs/guides/ops-stabilization.md
```
