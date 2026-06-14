# CentOS VM — SSHFS 자동 마운트 가이드

> VM 재부팅 후 `/mnt/serverdata`가 풀리는 문제를 **SSH 키 + systemd user 서비스**로 해결합니다.

---

## 개요

| 항목 | 값 |
|---|---|
| VM 사용자 | foxmong |
| 맥미니 SSH | kimi@192.168.0.100 |
| 원격 경로 | `/Volumes/ServerData` |
| VM 마운트 | `/mnt/serverdata` |
| 방식 | sshfs + systemd user service |

**왜 fstab이 아닌 systemd?**  
SSHFS는 네트워크·SSH 키·재연결 옵션이 필요하고, 부팅 순서(맥미니→VM)를 고려해야 합니다. systemd의 `Restart=on-failure`가 적합합니다.

---

## 1단계: SSH 키 등록 (1회)

### VM (foxmong)에서

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_serverdata -N "" -C "foxmong-serverdata-sshfs"
ssh-copy-id -i ~/.ssh/id_ed25519_serverdata.pub kimi@192.168.0.100
```

비밀번호 없이 접속 확인:

```bash
ssh -i ~/.ssh/id_ed25519_serverdata kimi@192.168.0.100 "ls /Volumes/ServerData"
```

### SSH config (권장)

`~/.ssh/config`:

```text
Host macmini-serverdata
    HostName 192.168.0.100
    User kimi
    IdentityFile ~/.ssh/id_ed25519_serverdata
    IdentitiesOnly yes
    ServerAliveInterval 15
    ServerAliveCountMax 3
```

```bash
chmod 600 ~/.ssh/config
ssh macmini-serverdata "echo OK"
```

---

## 2단계: 자동 설치 스크립트 (권장)

문서 저장소의 스크립트를 VM으로 복사한 뒤 실행:

```bash
# 맥미니에서 VM으로 복사 (예)
scp /Volumes/ServerData/Docs/scripts/centos/install-sshfs-automount.sh \
    /Volumes/ServerData/Docs/scripts/centos/serverdata-sshfs.service \
    foxmong@192.168.0.113:~/

# VM에서
chmod +x install-sshfs-automount.sh
./install-sshfs-automount.sh
```

스크립트가 수행하는 작업:

1. `fuse-sshfs` 설치 확인
2. `/mnt/serverdata` 권한 확인
3. SSH config + systemd user 서비스 설치
4. `loginctl enable-linger foxmong` (부팅 시 user 서비스)
5. 즉시 마운트 시작

---

## 3단계: 수동 설치 (스크립트 없이)

### systemd user 서비스

`~/.config/systemd/user/serverdata-sshfs.service`:

```ini
[Unit]
Description=SSHFS mount Mac mini ServerData to /mnt/serverdata
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
ExecStart=/usr/bin/sshfs macmini-serverdata:/Volumes/ServerData /mnt/serverdata \
  -o reconnect,ServerAliveInterval=15,ServerAliveCountMax=3,_netdev,uid=%U,gid=%G
ExecStop=/usr/bin/fusermount3 -u /mnt/serverdata
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now serverdata-sshfs.service
sudo loginctl enable-linger foxmong
```

---

## 4단계: 검증

```bash
# 서비스 상태
systemctl --user status serverdata-sshfs.service

# 마운트 확인
mount | grep serverdata
df -h /mnt/serverdata
ls /mnt/serverdata

# 재부팅 테스트
sudo reboot
# 재접속 후
mount | grep serverdata
```

**완료 기준:** 재부팅 후 `ls /mnt/serverdata`에 Shared, Projects 등이 보임.

---

## 5단계 (선택): 맥미니 VM 자동 시작

VM이 꺼져 있으면 SSHFS도 실패합니다. 맥미니 재부팅 시 VM을 자동 기동:

```bash
# 맥미니 (kimi)
cp /Volumes/ServerData/Docs/scripts/macos/com.kimi.centos-vm-autostart.plist \
   ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.kimi.centos-vm-autostart.plist
```

`StartInterval 300` — 5분마다 VM 실행 여부 확인 (이미 실행 중이면 무시).

---

## 문제 해결

| 증상 | 해결 |
|---|---|
| `Permission denied (publickey)` | `ssh-copy-id` 재실행, `~/.ssh/config` IdentityFile 확인 |
| `fusermount3: user has no write access` | `sudo chown foxmong:foxmong /mnt/serverdata` |
| 부팅 후 마운트 안 됨 | `loginctl enable-linger foxmong` 확인 |
| 맥미니 꺼짐/슬립 | 맥미니 `pmset` 절전 방지, VM autostart plist |
| `Connection reset` / 타임아웃 | 맥미니 SSH ON, 192.168.0.100 ping |
| Docker bind mount on SSHFS | ❌ 불가 — `~/docker/` 로컬 사용 |

---

## 관련 문서

- [00-HOME-SERVER-HANDOFF.md](../00-HOME-SERVER-HANDOFF.md) — §6-2 Docker + SSHFS
- [setup-logs/2026-06-12-macmini-server-setup.md](../setup-logs/2026-06-12-macmini-server-setup.md) — SSHFS 최초 설정

---

## 맥미니 경로

```text
/Volumes/ServerData/Docs/guides/vm-sshfs-automount.md
/Volumes/ServerData/Docs/scripts/centos/
```
