# 맥미니 홈서버 구축 작업 일지 — 3일차

- **작성일:** 2026-06-14
- **서버:** kimiui-Macmini
- **작업자:** kimi
- **VM:** centos-server (CentOS Stream 10, aarch64)
- **VM 사용자:** foxmong
- **이전 일지:** [2026-06-12-macmini-server-setup.md](./2026-06-12-macmini-server-setup.md)

---

## 1. 오늘 목표 (계획)

```text
Phase 3  Docker 설치 (CentOS VM)
Phase 4  Uptime Kuma (서버 상태 웹)
Phase 5  restic 백업 자동화 (맥미니)
Phase 6  외부 접속·모니터링 확인
```

### 오늘 실제 달성

```text
✅ SSHFS ServerData 마운트 재확인 (/mnt/serverdata)
✅ Docker CE 설치 (CentOS VM)
✅ Uptime Kuma 설치 + 계정 생성 + 웹 접속
✅ Uptime Kuma 모니터 5종 등록 (CentOS VM SSH Down 이슈 확인)
✅ restic 저장소 초기화 + backup.sh + cron 자동 백업
✅ 홈서버 전체 로드맵 정리
⬜ CentOS VM SSH 모니터 Up 전환 (172.17.0.1 또는 host network)
⬜ restic 복구 테스트
⬜ Uptime Kuma 알림 설정
```

---

## 2. 오늘 진행한 작업 상세

### 2-1. SSHFS ServerData 마운트 재확인

**상황:** `/home`만 확인해 마운트 안 된 것처럼 보였으나, `/mnt/serverdata`는 정상.

**확인 명령:**

```bash
mount | grep serverdata
df -h /mnt/serverdata
ls /mnt/serverdata
```

**결과:**

```text
kimi@192.168.0.100:/Volumes/ServerData on /mnt/serverdata type fuse.sshfs
용량: 1.9T (83G 사용)
폴더: AppData, Docs, Downloads, LinuxVM, Media, Projects, Ridi, Shared
```

**chown 실패 (허가 거부):**

```bash
sudo chown foxmong:foxmong /mnt/serverdata
# → 이미 SSHFS 마운트된 상태에서는 chown 불필요/실패 가능 → 무시
```

**판단:** SSHFS 정상. `/home/foxmong`과 `/mnt/serverdata`는 별개 경로.

---

### 2-2. Docker CE 설치 (CentOS VM)

**위치:** CentOS VM (`foxmong@centos-server`)

CentOS Stream 10은 Docker repo `$releasever=10` 미지원 → **9로 지정**.

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo sed -i 's/$releasever/9/g' /etc/yum.repos.d/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo systemctl enable --now docker
sudo usermod -aG docker foxmong
newgrp docker
docker run hello-world
```

**완료 기준:** `Hello from Docker!` 출력.

---

### 2-3. Uptime Kuma 설치

#### 시도 A: ServerData 경로 (실패)

```bash
/mnt/serverdata/AppData/uptime-kuma
docker compose up -d
```

**에러:**

```text
error while creating mount source path '.../data':
mkdir /mnt/serverdata: file exists
```

**원인:** Docker bind mount는 **SSHFS(FUSE) 경로에서 동작하지 않음**.  
Docker daemon(root)이 FUSE 마운트 포인트를 볼륨으로 쓸 수 없음.

#### 시도 B: VM 로컬 경로 (성공) ✅

```bash
mkdir -p ~/docker/uptime-kuma/data
cd ~/docker/uptime-kuma
```

**docker-compose.yml:**

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - ./data:/app/data
```

```bash
docker compose up -d
curl -I http://127.0.0.1:3001
```

**접속 URL:**

```text
집 안:  http://192.168.0.113:3001
밖:     http://100.69.135.104:3001
```

**관리자 계정:** 생성 완료.

**방화벽 (필요 시):**

```bash
sudo firewall-cmd --permanent --add-port=3001/tcp
sudo firewall-cmd --reload
```

#### Docker 데이터 경로 정책 (중요)

| 경로 | Docker bind mount |
|---|---|
| `/mnt/serverdata` (SSHFS) | ❌ 불가 |
| `~/docker/` (VM 로컬) | ✅ 사용 |

---

### 2-4. Uptime Kuma 모니터링 등록

등록된 모니터 (5종):

| Friendly Name | Type | Target | 상태 |
|---|---|---|---|
| Mac mini SSH | TCP | 192.168.0.100:22 | ✅ Up |
| Mac mini Tailscale | Ping | 100.127.117.23 | ✅ Up |
| CentOS VM SSH | TCP | 127.0.0.1:22 | ❌ Down |
| CentOS VM Tailscale | Ping | 100.69.135.104 | ✅ Up |
| Uptime Kuma Self | HTTP | http://127.0.0.1:3001 | ✅ Up |

#### CentOS VM SSH Down 원인 분석

VM 호스트에서 SSH는 정상:

```bash
sudo ss -tuln | grep 22        # 0.0.0.0:22 LISTEN
nc -zv 127.0.0.1 22            # Connected
nc -zv 192.168.0.113 22        # Connected
```

**원인:** Uptime Kuma가 **Docker bridge 네트워크** 안에서 실행됨.

```text
127.0.0.1 (컨테이너 안) = Kuma 자신 → SSH 없음 → Down
127.0.0.1 (호스트)      = VM SSH ✅ (호스트 터미널 기준)
```

**해결 방안 (다음 세션):**

1. 모니터 Hostname → **`172.17.0.1:22`** (docker0 게이트웨이 = 호스트)
2. 또는 `docker-compose.yml`에 **`network_mode: host`** → 그때 `127.0.0.1:22` 사용 가능

**확인 명령:**

```bash
ip route | grep docker0
docker exec uptime-kuma sh -c "nc -zv 172.17.0.1 22"
```

---

### 2-5. restic 백업 자동화 (맥미니)

**위치:** 맥미니 macOS (`kimi@kimiui-Macmini`)

#### 저장소 초기화

```bash
restic -r /Volumes/ServerBackup/restic-repo init
```

**주의:** 경로 오타 `resic-repo` ❌ → **`restic-repo`** ✅

초기화 후 폴더 구조:

```text
/Volumes/ServerBackup/restic-repo/
├── config
├── data
├── index
├── keys
├── locks
└── snapshots
```

#### backup.sh

**경로:** `/Users/kimi/scripts/backup.sh`

```bash
#!/bin/bash
set -e

export RESTIC_REPOSITORY="/Volumes/ServerBackup/restic-repo"
export RESTIC_PASSWORD="(스크립트에 설정, cron용)"

restic backup \
  /Volumes/ServerData/Projects \
  /Volumes/ServerData/Shared \
  /Volumes/ServerData/AppData \
  /Users/kimi/scripts

restic forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --prune
```

```bash
chmod 700 ~/scripts/backup.sh
```

**수동 실행:** 비밀번호 입력 없이 완료 (RESTIC_PASSWORD 설정됨).

**스냅샷 예:**

```text
894c5363  2026-06-14 16:04:24
b1d6713c  2026-06-14 16:10:21
Paths: /Users/kimi/scripts, /Volumes/ServerData/AppData, Projects, Shared
```

#### cron 등록

`crontab -e` → vi 오류 (`/usr/bin/vi exited with status 1`).

**해결:** echo 파이프 방식:

```bash
mkdir -p /Volumes/ServerBackup/logs
(crontab -l 2>/dev/null; echo "0 3 * * * /Users/kimi/scripts/backup.sh >> /Volumes/ServerBackup/logs/backup.log 2>&1") | crontab -
crontab -l
```

**등록 내용:**

```cron
0 3 * * * /Users/kimi/scripts/backup.sh >> /Volumes/ServerBackup/logs/backup.log 2>&1
```

**자동 백업:** RESTIC_PASSWORD가 스크립트에 있으면 **입력 없이** 매일 03:00 실행.

---

### 2-6. 문서·가이드

| 문서 | 내용 |
|---|---|
| `tailscale-sftp-file-transfer.md` | SFTP get/put 중심으로 개정 |
| 홈서버 로드맵 | 완료/남은 단계 전체 정리 (대화 중) |

---

## 3. 중요 결정 사항 및 교훈

### 3-1. Docker + SSHFS 호환 불가

```text
Docker bind mount  → VM 로컬 디스크 (~/docker/)
SSHFS (/mnt/serverdata) → 파일 읽기/쓰기용, Docker volume ❌
```

### 3-2. Uptime Kuma 모니터 + Docker 네트워크

```text
Kuma in Docker bridge:
  127.0.0.1 = 컨테이너 (SSH 없음)
  172.17.0.1 = 호스트 (VM SSH ✅)

Kuma in host network:
  127.0.0.1 = VM 호스트 (SSH ✅)
```

### 3-3. restic cron on macOS

```text
crontab -e (vi) 실패 → echo | crontab - 사용
RESTIC_PASSWORD in backup.sh 필수 (cron은 대화형 입력 불가)
chmod 700 backup.sh
```

### 3-4. 백업 비밀번호

restic 저장소 비밀번호는 **복구 시 필수**. 별도 안전한 곳에 기록.  
`backup.sh`에 평문 저장 → 파일 권한 700 유지.

---

## 4. 현재 전체 인프라 상태

### 맥미니 (macOS)

| 항목 | 값/상태 |
|---|---|
| 내부 IP | 192.168.0.100 |
| Tailscale IP | 100.127.117.23 |
| SSH / SMB | ✅ |
| restic cron | ✅ 매일 03:00 |
| 백업 저장소 | /Volumes/ServerBackup/restic-repo |

### CentOS VM

| 항목 | 값/상태 |
|---|---|
| 내부 IP | 192.168.0.113 |
| Tailscale IP | 100.69.135.104 |
| SSH / SFTP | ✅ |
| SSHFS | ✅ /mnt/serverdata |
| Docker | ✅ |
| Uptime Kuma | ✅ ~/docker/uptime-kuma :3001 |

### 외부 접속 (노트북, Tailscale)

```bash
ssh kimi@100.127.117.23
sftp kimi@100.127.117.23
ssh foxmong@100.69.135.104
http://100.69.135.104:3001
```

---

## 5. 문제 해결 기록

| # | 증상 | 원인 | 해결 |
|---|---|---|---|
| 1 | chown /mnt/serverdata 거부 | SSHFS 이미 마운트됨 | chown 스킵, 마운트 정상 확인 |
| 2 | mkdir AppData/uptime-kuma 거부 | SSHFS 쓰기/경로 | 맥미니에서 폴더 생성 또는 ~/docker 사용 |
| 3 | docker compose SSHFS bind 실패 | FUSE + Docker 비호환 | ~/docker/uptime-kuma 로컬 경로 |
| 4 | ERR_CONNECTION_REFUSED :3001 | Kuma 미실행/방화벽 | docker compose up -d, firewall 3001 |
| 5 | restic repository does not exist | init 미실행 | restic init |
| 6 | resic-repo 경로 오류 | 오타 | restic-repo 로 통일 |
| 7 | crontab -e vi 실패 | vi 종료 오류 | echo \| crontab - |
| 8 | CentOS VM SSH 모니터 Down | Docker内 127.0.0.1 ≠ 호스트 | 172.17.0.1:22 또는 network_mode: host |

---

## 6. 미완료 / 다음 작업

### 우선 (운영)

```text
[ ] CentOS VM SSH 모니터 → 172.17.0.1:22 로 수정
[ ] restic 복구 테스트 (restore to /tmp)
[ ] Uptime Kuma 알림 (Telegram/Discord)
[ ] cron 백업 로그 확인 (tail backup.log)
```

### 안정화 (선택)

```text
[ ] VM SSHFS 부팅 시 자동 마운트 + ssh-copy-id
[ ] VM 자동 시작 (VBoxManage + launchd)
[ ] macOS cron → launchd 전환
[ ] SMB fileshare 전용 계정
```

### 확장 (예정)

```text
[ ] 앱 서버 Docker Compose (~/docker/myapp)
[ ] Cloudflare Tunnel
[ ] Gitea / Nextcloud 등
```

---

## 7. 자주 쓰는 명령어 (오늘 기준)

### CentOS VM

```bash
# SSHFS
sshfs kimi@192.168.0.100:/Volumes/ServerData /mnt/serverdata
ls /mnt/serverdata

# Docker / Uptime Kuma
cd ~/docker/uptime-kuma
docker compose up -d
docker ps
curl -I http://127.0.0.1:3001

# Uptime Kuma 모니터 디버그
ip route | grep docker0
docker exec uptime-kuma sh -c "nc -zv 172.17.0.1 22"
```

### 맥미니

```bash
~/scripts/backup.sh
restic -r /Volumes/ServerBackup/restic-repo snapshots
crontab -l
tail /Volumes/ServerBackup/logs/backup.log
```

### 노트북 (외부)

```bash
ssh kimi@100.127.117.23
ssh foxmong@100.69.135.104
sftp kimi@100.127.117.23
# 브라우저: http://100.69.135.104:3001
```

---

## 8. 진행 상태 요약

```text
[1일차 06-11] ServerData/Backup, Tailscale, SSH, SMB, CentOS VM 설치
[2일차 06-12] SSHFS, Guest Additions ARM 한계, SFTP 가이드
[3일차 06-14] Docker, Uptime Kuma, restic+cron, 모니터링 (SSH Down 잔여)

[핵심 구축]     ████████████████████  ~95%
[운영 안정화]   ████████░░░░░░░░░░░░  ~45%
[앱 서버 확장]  ░░░░░░░░░░░░░░░░░░░░   0%
```

---

## 9. 참고 경로

| 항목 | 경로 |
|---|---|
| 작업 일지 | `/Volumes/ServerData/Docs/setup-logs/` |
| SFTP 가이드 | `/Volumes/ServerData/Docs/guides/tailscale-sftp-file-transfer.md` |
| 백업 스크립트 | `/Users/kimi/scripts/backup.sh` |
| Uptime Kuma | `~/docker/uptime-kuma/` (VM) |
| restic repo | `/Volumes/ServerBackup/restic-repo` |

---

*이 문서는 2026-06-14 맥미니 홈서버 구축 3일차 작업 내용을 정리한 것입니다.*
