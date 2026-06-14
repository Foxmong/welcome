# 맥미니 홈서버 — 마스터 핸드오프 문서

> **새 세션 시작 시 이 파일을 먼저 읽으세요.**  
> 작업 일지·가이드·현재 상태·다음 단계를 한곳에 정리했습니다.

- **최종 업데이트:** 2026-06-15
- **서버:** kimiui-Macmini (Apple Silicon)
- **작업자:** kimi
- **목적:** 24/7 홈서버 — 외부 접속, Linux VM, 파일 공유, 모니터링, 백업, 추후 앱 서버

---

## 1. 한 페이지 요약

```text
맥미니 (macOS)     → 24/7 호스트, Tailscale, SSH, SMB, restic 백업
ServerData (2TB)   → 메인 데이터, SMB Shared, VM 디스크
ServerBackup       → restic 백업 전용 (512GB)
CentOS VM          → Linux 실습, Docker, Uptime Kuma
외부 접속          → Tailscale (포트포워딩 없음)
파일 이동          → SFTP (get/put) 또는 SMB (Shared)
```

**핵심 구축:** ✅ 완료 (~100%)  
**운영 안정화:** 🔧 ~90% (SSHFS 자동화 스크립트 준비, VM 배포·검증 남음)  
**앱 서버 확장:** 🔧 ~20% (whoami/NPM/cloudflared 템플릿·가이드 준비, VM 배포 대기)

---

## 2. 접속 정보 (치트시트)

### 맥미니 (macOS)

| 항목 | 값 |
|---|---|
| 호스트명 | kimiui-Macmini |
| 사용자 | **kimi** |
| 집 IP | **192.168.0.100** |
| Tailscale IP | **100.127.117.23** |
| SSH (집) | `ssh kimi@192.168.0.100` |
| SSH (밖) | `ssh kimi@100.127.117.23` |
| SFTP (밖) | `sftp kimi@100.127.117.23` |
| SMB Shared | `smb://100.127.117.23/Shared` |

### CentOS VM (VirtualBox)

| 항목 | 값 |
|---|---|
| VM 이름 | centos-server |
| OS | CentOS Stream 10 (aarch64) |
| 사용자 | **foxmong** (centos 아님!) |
| 집 IP | **192.168.0.113** |
| Tailscale IP | **100.69.135.104** |
| SSH (집) | `ssh foxmong@192.168.0.113` |
| SSH (밖) | `ssh foxmong@100.69.135.104` |
| Uptime Kuma | `http://100.69.135.104:3001` |

### 네트워크

| 항목 | 값 |
|---|---|
| 공유기 | TP-Link AX3000, 192.168.0.1 |
| DHCP 권장 | 192.168.0.101 ~ .253 (맥미니 .100 충돌 방지) |
| DNS (맥미니) | 1.1.1.1, 8.8.8.8 |

---

## 3. 저장장치 구성

| 디스크 | 이름 | 용량 | 용도 |
|---|---|---|---|
| 내장 SSD | (시스템) | 256GB | macOS, VirtualBox, Tailscale, 스크립트 |
| M.2 #1 | **ServerData** | 2TB | 메인 데이터, VM 디스크, Shared |
| M.2 #2 | **ServerBackup** | 512GB | restic 백업 (RED에서 이름 변경) |

**구성:** JBOD (RAID 미사용)

### ServerData 경로

```text
/Volumes/ServerData/
├── Shared/       ← SMB 공유만 (외부 파일 교환)
├── Projects/
├── AppData/      ← SMB 공유 금지
├── LinuxVM/      ← VirtualBox VM 디스크
├── Docs/         ← 작업 문서
├── Downloads/
└── Media/
```

### ServerBackup 경로

```text
/Volumes/ServerBackup/
├── restic-repo/  ← restic 저장소
├── logs/         ← backup.log
├── db-dumps/
├── config-backups/
└── critical-data/
```

---

## 4. 아키텍처

```text
                    [인터넷]
                        |
                   [TP-Link 192.168.0.1]
                        |
        +---------------+---------------+
        |                               |
   [맥미니 macOS]                   [노트북]
   192.168.0.100                    Tailscale
   100.127.117.23                       |
        |                          SSH/SFTP/SMB
   +----+----+
   |         |
ServerData  ServerBackup
  2TB         restic
   |
VirtualBox ── CentOS VM
              192.168.0.113 / 100.69.135.104
              Docker + Uptime Kuma (:3001)
              SSHFS → /mnt/serverdata
              Docker data → ~/docker/ (로컬)
```

---

## 5. 완료된 작업 전체 목록

### 맥미니 (macOS)

- [x] 절전 방지 (`pmset`, 시스템 설정)
- [x] ServerData / ServerBackup 디스크 이름·폴더 구성
- [x] 고정 IP 192.168.0.100 (유선 LAN)
- [x] Tailscale 설치·연결
- [x] SSH (Remote Login) ON
- [x] SMB — **Shared 폴더만** 공유
- [x] restic 저장소 init (`/Volumes/ServerBackup/restic-repo`)
- [x] backup.sh + cron 매일 03:00
- [x] restic 복구 테스트 성공 (13 files → /tmp/restic-restore-test)

### CentOS VM

- [x] VirtualBox VM `centos-server` (4GB RAM, 2 CPU, 80GB, Bridged en0)
- [x] CentOS Stream 10, 사용자 **foxmong**, 호스트명 centos-server
- [x] SSH 활성화
- [x] VM Tailscale
- [x] SSHFS ServerData → `/mnt/serverdata` (Guest Additions 대체)
- [x] Docker CE (repo releasever=9)
- [x] Uptime Kuma (`~/docker/uptime-kuma`, port 3001)
- [x] Uptime Kuma 모니터 5종 등록
- [x] Uptime Kuma 알림 — **미사용** (대시보드 모니터링만)

### 문서

- [x] 작업 일지 06-11, 06-12, 06-14
- [x] Tailscale + SFTP 가이드
- [x] 이 핸드오프 문서

---

## 6. 중요 기술 결정 (반드시 기억)

### 6-1. Guest Additions = ARM64 불가

```text
VirtualBox Guest Additions → Detected unsupported arm64
대안: SSHFS (VM ↔ 맥미니 ServerData)
호스트↔VM GUI 복붙: SSH 터미널 사용
```

### 6-2. Docker bind mount ≠ SSHFS

```text
❌ /mnt/serverdata/AppData/... → Docker volume (FUSE 오류)
✅ ~/docker/uptime-kuma/data   → Docker volume (VM 로컬)
```

### 6-3. Uptime Kuma SSH 모니터 (Docker bridge)

```text
❌ 127.0.0.1:22 (Kuma 컨테이너 자신 → SSH 없음)
✅ 172.17.0.1:22 (docker0 게이트웨이 = VM 호스트 SSH)
```

컨테이너에 `nc` 없음 → 정상. TCP 모니터는 Hostname만 맞으면 됨.

### 6-4. SMB vs SFTP vs SSHFS

| 방식 | 용도 |
|---|---|
| SMB Shared | Finder 탐색, Shared만 |
| SFTP get/put | 임의 경로 파일 이동 (Tailscale) |
| SSHFS | VM 안에서 ServerData 전체 접근 |

### 6-5. restic

```text
저장소: /Volumes/ServerBackup/restic-repo  (오타 resic-repo ❌)
비밀번호: ~/scripts/backup.sh 의 RESTIC_PASSWORD (cron 필수)
백업: Projects, Shared, AppData, scripts
512GB → 2TB 전체 백업 불가, 중요 데이터만
```

### 6-6. 보안

```text
✅ Tailscale만 외부 접속, 포트포워딩 없음
✅ SMB Shared만 공유, AppData/ServerBackup 공유 금지
✅ SSH/SFTP 계정: kimi, foxmong
```

---

## 7. Uptime Kuma 모니터

| 이름 | Type | Target | 비고 |
|---|---|---|---|
| Mac mini SSH | TCP | 192.168.0.100:22 | |
| Mac mini Tailscale | Ping | 100.127.117.23 | |
| CentOS VM SSH | TCP | **172.17.0.1:22** | Docker bridge |
| CentOS VM Tailscale | Ping | 100.69.135.104 | |
| Uptime Kuma Self | HTTP | http://127.0.0.1:3001 | |

**알림:** 사용 안 함 (필요 시 Uptime Kuma UI에서만 설정)

---

## 8. 백업

### backup.sh

```text
경로: /Users/kimi/scripts/backup.sh
권한: chmod 700
cron: 0 3 * * * → /Volumes/ServerBackup/logs/backup.log
```

### 수동 실행

```bash
~/scripts/backup.sh
restic -r /Volumes/ServerBackup/restic-repo snapshots
```

### 복구 테스트 (검증 완료)

```bash
restic -r /Volumes/ServerBackup/restic-repo restore latest \
  --target /tmp/restic-restore-test
# → 13 files/dirs restored
rm -rf /tmp/restic-restore-test
```

---

## 9. 자주 쓰는 명령어

### 맥미니

```bash
tailscale ip -4
ssh kimi@100.127.117.23
sftp kimi@100.127.117.23
~/scripts/backup.sh
crontab -l
tail /Volumes/ServerBackup/logs/backup.log
```

### CentOS VM

```bash
# SSHFS (자동화 설치 후 — 재부팅해도 유지)
systemctl --user status serverdata-sshfs.service
# 수동 1회: ./install-sshfs-automount.sh  (guides/vm-sshfs-automount.md)

# Docker / Uptime Kuma
cd ~/docker/uptime-kuma && docker compose up -d
docker ps
curl -I http://127.0.0.1:3001

# VM 시작 (맥미니에서)
VBoxManage startvm centos-server --type headless
```

### SFTP (노트북)

```bash
sftp kimi@100.127.117.23
# sftp> cd /Volumes/ServerData/Shared
# sftp> lcd ~/Downloads
# sftp> put file.pdf
# sftp> get file.pdf
# sftp> exit
```

---

## 10. 문제 해결 빠른 참조

| 증상 | 해결 |
|---|---|
| SFTP Permission denied (VM) | 사용자 **foxmong** (centos 아님) |
| Guest Additions arm64 오류 | SSHFS 사용, GA 포기 |
| Docker + SSHFS bind 실패 | ~/docker/ 로컬 경로 |
| Uptime Kuma SSH Down | Hostname **172.17.0.1:22** |
| restic repo not found | `restic-repo` (resic 오타 주의) |
| restic wrong password | backup.sh RESTIC_PASSWORD 와 동일 |
| crontab vi 실패 | `(crontab -l; echo "...") \| crontab -` |
| SSHFS VM 재부팅 후 풀림 | `scripts/centos/install-sshfs-automount.sh` 실행 |
| nc not found (Kuma 컨테이너) | 무시, 모니터 Hostname만 수정 |

---

## 11. 미완료 / 다음 작업 (우선순위)

### 바로 (맥/VM에서 실행)

→ **[ops-stabilization.md](./guides/ops-stabilization.md)** 한 문서에 순서 정리

- [ ] **SSHFS 자동화:** VM에서 `install-sshfs-automount.sh` → 재부팅 후 `verify-ops-stabilization.sh`
- [ ] **VM autostart:** 맥에서 `install-vm-autostart.sh`
- [ ] cron 백업 로그 확인 (`tail backup.log`, 새벽 3시 이후)

### 운영 안정화

- [x] VM SSHFS 자동 마운트 **스크립트·가이드** ([vm-sshfs-automount.md](./guides/vm-sshfs-automount.md))
- [ ] VM autostart plist 설치 ([scripts/macos/com.kimi.centos-vm-autostart.plist](./scripts/macos/com.kimi.centos-vm-autostart.plist))
- [ ] macOS cron → launchd (선택)
- [ ] SMB fileshare 전용 계정 (선택)

### 앱 서버 확장

- [x] docker-compose 템플릿 (`scripts/docker/myapp`, `nginx-proxy-manager`, `cloudflared`)
- [ ] VM 배포: `~/docker/myapp` whoami → [app-server-docker-compose.md](./guides/app-server-docker-compose.md)
- [ ] Cloudflare Tunnel → [cloudflare-tunnel.md](./guides/cloudflare-tunnel.md)
- [ ] Nginx Proxy Manager (선택)

### 하드웨어 (여유)

- [ ] 외장 HDD 오프사이트 백업, UPS, DAS SSD 추가

---

## 12. 문서 목록

| 파일 | 내용 |
|---|---|
| **00-HOME-SERVER-HANDOFF.md** | **← 이 파일 (새 세션 시작점)** |
| setup-logs/2026-06-11-macmini-server-setup.md | 1일차: 디스크, Tailscale, VM 설치 |
| setup-logs/2026-06-12-macmini-server-setup.md | 2일차: SSHFS, Guest Additions ARM |
| setup-logs/2026-06-14-macmini-server-setup.md | 3일차: Docker, Kuma, restic |
| setup-logs/2026-06-15-macmini-server-setup.md | 4일차: SSHFS 자동화, 앱/Tunnel 템플릿 |
| guides/tailscale-sftp-file-transfer.md | SFTP get/put 가이드 |
| guides/vm-sshfs-automount.md | SSHFS 부팅 자동 마운트 |
| guides/app-server-docker-compose.md | 앱 서버 (whoami, NPM) |
| guides/cloudflare-tunnel.md | Cloudflare Tunnel |
| scripts/centos/ | SSHFS install 스크립트 |
| scripts/docker/ | compose 템플릿 |

### 맥미니 실제 경로

```text
/Volumes/ServerData/Docs/
```

### GitHub (클라oud 백업)

```text
https://github.com/Foxmong/welcome/tree/cursor/server-setup-docs-f7a6/ServerData/Docs
```

---

## 13. 새 세션 시작 프롬프트 (복사용)

```text
맥미니 홈서버 프로젝트 이어서 진행.
/Volumes/ServerData/Docs/00-HOME-SERVER-HANDOFF.md 를 기준으로 현재 상태 파악 후 작업해줘.

현재:
- 맥미니 Tailscale 100.127.117.23, SSH/SMB/restic 완료
- CentOS VM foxmong@100.69.135.104, Docker, Uptime Kuma :3001
- SSHFS /mnt/serverdata, Docker는 ~/docker/ 로컬
- 다음: install-sshfs-automount.sh 실행, whoami+Tunnel 배포
```

---

*이 문서는 2026-06-11 ~ 2026-06-14 홈서버 구축 전체를 요약한 핸드오프 문서입니다.*
