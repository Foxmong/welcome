# 맥미니 홈서버 구축 작업 일지 — 4일차

- **작성일:** 2026-06-15
- **서버:** kimiui-Macmini
- **작업자:** kimi (+ Cloud Agent 세션)
- **VM:** centos-server (CentOS Stream 10, aarch64)
- **VM 사용자:** foxmong
- **이전 일지:** [2026-06-14-macmini-server-setup.md](./2026-06-14-macmini-server-setup.md)

---

## 1. 오늘 목표

```text
Phase A  VM SSHFS 부팅 자동화 (ssh-copy-id + systemd)
Phase C  앱 서버 템플릿 (whoami + NPM)
Phase D  Cloudflare Tunnel template + 가이드
```

### Cloud Agent 세션에서 준비한 것 (맥/VM에서 실행 필요)

```text
✅ SSHFS 자동 마운트 스크립트 + systemd unit
✅ 맥미니 VM autostart launchd plist
✅ docker-compose 템플릿 (whoami, NPM, cloudflared)
✅ 앱 서버 / Cloudflare Tunnel 가이드
✅ 실제 실행 완료 → [2026-06-14-ops-stabilization.md](./2026-06-14-ops-stabilization.md)
```

---

## 2. SSHFS 자동 마운트

### 문제

VM 재부팅 후 `sshfs kimi@192.168.0.100:...` 수동 실행 필요 ([핸드오프 §10](../00-HOME-SERVER-HANDOFF.md)).

### 해결 (준비 완료)

| 파일 | 용도 |
|---|---|
| `scripts/centos/install-sshfs-automount.sh` | 원클릭 설치 |
| `scripts/centos/serverdata-sshfs.service` | systemd user unit 템플릿 |
| `guides/vm-sshfs-automount.md` | 상세 가이드 |

### VM에서 실행할 명령

```bash
# 맥미니 → VM 복사
scp /Volumes/ServerData/Docs/scripts/centos/install-sshfs-automount.sh \
    /Volumes/ServerData/Docs/scripts/centos/serverdata-sshfs.service \
    foxmong@192.168.0.113:~/

# VM
chmod +x install-sshfs-automount.sh
./install-sshfs-automount.sh
# ssh-copy-id 안내 시 맥미니 kimi 비밀번호 1회 입력

# 검증
sudo reboot
# 재접속 후
mount | grep serverdata
ls /mnt/serverdata
```

### 맥미니 VM 자동 시작 (선택)

```bash
cp /Volumes/ServerData/Docs/scripts/macos/com.kimi.centos-vm-autostart.plist \
   ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.kimi.centos-vm-autostart.plist
```

---

## 3. 앱 서버 (whoami)

가이드: [guides/app-server-docker-compose.md](../guides/app-server-docker-compose.md)

```bash
mkdir -p ~/docker/myapp
# Docs/scripts/docker/myapp/docker-compose.yml 복사
cd ~/docker/myapp && docker compose up -d
curl http://127.0.0.1:8080
```

Tailscale: `http://100.69.135.104:8080`

---

## 4. Cloudflare Tunnel

가이드: [guides/cloudflare-tunnel.md](../guides/cloudflare-tunnel.md)

```bash
mkdir -p ~/docker/cloudflared
# compose + .env.example → .env (TUNNEL_TOKEN)
cd ~/docker/cloudflared && docker compose up -d
```

Zero Trust Public Hostname 예: `status.yourdomain.com` → `192.168.0.113:3001`

---

## 5. 진행 상태

```text
[핵심 구축]     ████████████████████  100%
[운영 안정화]   ██████████████████░░  ~90%  ← SSHFS 자동화 스크립트 준비
[앱 서버 확장]  ████░░░░░░░░░░░░░░░░  ~20%  ← 템플릿·가이드 준비, 배포 대기
```

---

## 6. 다음 세션 (맥/VM에서)

1. `install-sshfs-automount.sh` 실행 + 재부팅 검증
2. whoami `docker compose up -d`
3. Cloudflare Tunnel 토큰 + Public Hostname
4. (선택) NPM :81

---

## 7. 새 파일 목록

| 경로 | 내용 |
|---|---|
| guides/vm-sshfs-automount.md | SSHFS 자동 마운트 |
| guides/app-server-docker-compose.md | 앱 서버 |
| guides/cloudflare-tunnel.md | Tunnel |
| scripts/centos/* | SSHFS 설치 |
| scripts/macos/*.plist | VM autostart |
| scripts/docker/* | compose 템플릿 |

---

*이 문서는 2026-06-15 홈서버 4일차(Cloud Agent 세션) 작업을 정리한 것입니다.*
