# 맥미니 홈서버 구축 작업 일지 — 2일차

- **작성일:** 2026-06-12
- **서버:** kimiui-Macmini
- **작업자:** kimi
- **VM:** centos-server (CentOS Stream 10, aarch64)
- **VM 사용자:** foxmong
- **이전 일지:** [2026-06-11-macmini-server-setup.md](./2026-06-11-macmini-server-setup.md)

---

## 1. 오늘 목표 (계획)

```text
Phase 1  VM 기반 완성 (Guest Additions / ServerData 마운트 / VM Tailscale)
Phase 2  Docker 환경
Phase 3  Uptime Kuma (외부 웹 상태 점검)
Phase 4  외부 접속 테스트
```

### 오늘 실제 달성

```text
✅ VirtualBox 공유 폴더 설정
❌ Guest Additions (ARM64 미지원으로 실패)
✅ SSHFS로 ServerData 마운트 (/mnt/serverdata)
⏸ VM Tailscale, Docker, Uptime Kuma → 다음 세션
```

---

## 2. 오늘 진행한 작업 상세

### 2-1. VirtualBox 공유 폴더 설정

**목적:** 맥미니 ServerData를 CentOS VM에서 사용하기 위함.

**설정 위치:** VirtualBox → centos-server → 설정 → 공유 폴더

| 항목 | 값 |
|---|---|
| 폴더 경로 | `/Volumes/ServerData` |
| 폴더 이름 | `ServerData` |
| 마운트 지점 | **비워둠** |
| 읽기 전용 | ❌ |
| 자동 마운트 | ✅ |
| Make Global | ❌ |

**주의:** `/Volumes/ServerData → ServerData` 는 **터미널 명령이 아님**. VirtualBox GUI 설정 설명이었음.  
터미널에 입력 시 `zsh: permission denied: /Volumes/ServerData` 발생 — 정상적인 오해.

---

### 2-2. Guest Additions 설치 시도 → 실패

**목적:** 공유 폴더, 호스트↔VM 복붙, vboxsf 그룹 생성.

**실행 명령 (VM 안):**

```bash
sudo dnf install -y kernel-devel kernel-headers gcc make perl elfutils-libelf-devel
sudo mkdir -p /mnt/cdrom
sudo mount /dev/cdrom /mnt/cdrom
cd /mnt/cdrom
sudo ./VBoxLinuxAdditions.run
```

**에러:**

```text
Detected unsupported arm64 machine type.
```

**원인:**

```text
맥미니: Apple Silicon (ARM64)
CentOS VM: aarch64 (CentOS Stream 10)
VirtualBox Guest Additions: ARM64 미지원
```

**결과:**

```text
vboxsf 그룹 생성 불가
usermod -aG vboxsf foxmong → group 'vboxsf' does not exist
VirtualBox 공유 폴더 직접 마운트 불가
호스트↔VM GUI 복붙 연동 불가 (Guest Additions 필요)
```

**판단:** Guest Additions 경로 **포기**, 네트워크 방식(SSH/SSHFS)으로 대체.

---

### 2-3. 호스트↔VM 복붙 연동

**질문:** Guest Additions 없이 복붙 먼저 가능한가?

**답:** VirtualBox GUI 창 내 복붙은 ARM에서 불가.  
**대안:** 맥미니 터미널에서 SSH로 VM 접속하면 복붙 가능.

```bash
# 맥미니에서
ssh foxmong@192.168.0.113
```

**SSH config (선택):**

```text
Host centos
    HostName 192.168.0.113
    User foxmong
```

---

### 2-4. SSHFS로 ServerData 마운트 (성공)

**목적:** Guest Additions 대신 VM에서 맥미니 ServerData 전체 접근.

#### 패키지 설치

CentOS Stream 10 기본 repo에 `fuse-sshfs` 없음:

```text
오류: 일치하는 항목을 찾을 수 없습니다: fuse-sshfs
```

**해결:** EPEL 활성화 후 설치

```bash
sudo dnf install -y epel-release
sudo dnf install -y fuse-sshfs
# 또는: sudo dnf install -y sshfs
```

#### 마운트 포인트 권한 문제

**에러:**

```text
fusermount3: user has no write access to mountpoint /mnt/serverdata
```

**원인:** `sudo mkdir`로 root 소유 폴더에 일반 사용자(foxmong)가 sshfs 마운트 시도.

**해결:**

```bash
sudo mkdir -p /mnt/serverdata
sudo chown foxmong:foxmong /mnt/serverdata
sshfs kimi@192.168.0.100:/Volumes/ServerData /mnt/serverdata
ls /mnt/serverdata
```

**성공 확인:**

```text
AppData  Docs  Downloads  LinuxVM  Media  Projects  Shared
```

#### SSHFS 최종 구조

```text
맥미니 macOS
└── /Volumes/ServerData
         │
         │ SSHFS (kimi@192.168.0.100)
         ▼
CentOS VM (foxmong)
└── /mnt/serverdata
    ├── AppData
    ├── Docs
    ├── Downloads
    ├── LinuxVM
    ├── Media
    ├── Projects
    └── Shared
```

---

## 3. 중요 결정 사항 및 교훈

### 3-1. Apple Silicon + VirtualBox 한계

| 기능 | VirtualBox + Guest Additions | 대안 |
|---|---|---|
| 공유 폴더 | ❌ ARM64 미지원 | SSHFS ✅ |
| GUI 복붙 | ❌ | SSH 터미널 복붙 ✅ |
| vboxsf | ❌ | 불필요 (SSHFS 사용) |

**향후 고려:** GUI 복붙/공유폴더가 꼭 필요하면 UTM 또는 Parallels 검토.  
현재 구성(SSH + SSHFS)으로 서버 용도는 충분.

### 3-2. SSHFS vs SMB

| 방식 | 접근 범위 | 비고 |
|---|---|---|
| **SSHFS** | ServerData 전체 | 오늘 채택 ✅ |
| SMB | Shared 폴더만 | 제한적 |

### 3-3. sshfs 실행 시 주의

```text
❌ sudo sshfs ...        → root 마운트, 권한 꼬임
✅ foxmong으로 sshfs     → 일반 사용자 마운트
✅ chown foxmong 먼저    → 마운트 포인트 소유권
```

### 3-4. VM 재부팅 시

SSHFS 마운트는 **풀림**. 재접속 필요:

```bash
sshfs kimi@192.168.0.100:/Volumes/ServerData /mnt/serverdata
```

비밀번호 생략: `ssh-copy-id kimi@192.168.0.100` (VM → 맥미니)

---

## 4. 현재 전체 인프라 상태

### 맥미니 (macOS)

| 항목 | 값/상태 |
|---|---|
| 내부 IP | 192.168.0.100 |
| Tailscale IP | 100.127.117.23 |
| 사용자 | kimi |
| SSH | ✅ ON |
| Tailscale | ✅ ON |
| SMB | Shared만 공유 |
| ServerData | ✅ 마운트 |
| ServerBackup | ✅ 마운트 |

### CentOS VM (VirtualBox)

| 항목 | 값/상태 |
|---|---|
| VM 이름 | centos-server |
| OS | CentOS Stream 10 (aarch64) |
| 내부 IP | 192.168.0.113 |
| 사용자 | **foxmong** (centos 아님!) |
| SSH (맥미니→VM) | ✅ `ssh foxmong@192.168.0.113` |
| Tailscale | ❌ 미설치 |
| ServerData | ✅ SSHFS `/mnt/serverdata` |
| Docker | ❌ 미설치 |

### 외부 접속 가능 범위 (현재)

| 경로 | 집 안 | 밖 (Tailscale) |
|---|---|---|
| 맥미니 SSH | ✅ | ✅ |
| CentOS VM SSH | ✅ (VM 켜져 있을 때) | ❌ (VM Tailscale 미설치) |
| ServerData (SSHFS) | ✅ (VM 켜져 있을 때) | ❌ |
| Uptime Kuma | ❌ | ❌ |

**우회:** 밖에서 VM 접속 = `ssh -J kimi@100.127.117.23 foxmong@192.168.0.113` (VM ON 필요)

---

## 5. 문제 해결 기록

### 문제 1: `/Volumes/ServerData → ServerData` permission denied

- **원인:** 문서 설명을 터미널 명령으로 오인
- **해결:** VirtualBox GUI에서 공유 폴더 설정

### 문제 2: `vboxsf` group does not exist

- **원인:** Guest Additions 미설치
- **해결:** Guest Additions 설치 시도 → ARM64 실패 → SSHFS로 전환

### 문제 3: Guest Additions `unsupported arm64`

- **원인:** VirtualBox GA가 Apple Silicon ARM 게스트 미지원
- **해결:** SSHFS 채택, Guest Additions 포기

### 문제 4: `fuse-sshfs` 패키지 없음

- **원인:** CentOS 기본 repo 미포함
- **해결:** `epel-release` 설치 후 `fuse-sshfs` 또는 `sshfs` 설치

### 문제 5: `user has no write access to mountpoint`

- **원인:** `/mnt/serverdata` root 소유
- **해결:** `sudo chown foxmong:foxmong /mnt/serverdata`

### 문제 6: SSH 비밀번호 여러 번 실패

- **원인:** kimi@192.168.0.100 비밀번호 오입력 가능
- **해결:** 올바른 비밀번호 입력 후 마운트 성공

---

## 6. 오늘 종료 시 서버 상태

### 켜 두어도 되는 것

```text
맥미니 (24/7)
Tailscale
SSH
이더넷
ServerData / ServerBackup 디스크
```

### 끄면 좋은 것 (선택)

```text
CentOS VM (RAM 4GB 절약)
VirtualBox 앱
```

### SSHFS

VM 종료/재부oot 시 마운트 해제됨. 다음 세션 시작 시 재마운트 필요.

---

## 7. 다음 세션 작업 (우선순위)

### Phase A. VM Tailscale (외부 VM 직접 접속)

```bash
# CentOS VM 안
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
tailscale ip -4
```

**완료 기준:** 노트북에서 `ssh foxmong@VM-Tailscale-IP` 성공

### Phase B. Docker 설치

```bash
sudo dnf install -y dnf-plugins-core
# Docker CE repo 추가 후 설치
docker run hello-world
```

### Phase C. Uptime Kuma (서버 상태 웹)

```yaml
# /mnt/serverdata/AppData/uptime-kuma/docker-compose.yml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    restart: unless-stopped
    ports:
      - "3001:3001"
    volumes:
      - ./data:/app/data
```

**모니터링 대상:**

```text
맥미니 SSH (192.168.0.100:22)
맥미니 Tailscale (100.127.117.23)
CentOS VM SSH (192.168.0.113:22)
CentOS VM Tailscale (설치 후)
```

**외부 접속:** `http://VM-Tailscale-IP:3001`

### Phase D. SSHFS 자동화 (선택)

```bash
# VM에서 SSH 키 등록
ssh-keygen -t ed25519
ssh-copy-id kimi@192.168.0.100

# 부팅 시 자동 마운트 (/etc/fstab)
kimi@192.168.0.100:/Volumes/ServerData /mnt/serverdata fuse.sshfs defaults,_netdev,IdentityFile=/home/foxmong/.ssh/id_ed25519 0 0
```

---

## 8. 자주 쓰는 명령어 (오늘 기준)

### 맥미니 → CentOS VM

```bash
ssh foxmong@192.168.0.113
# 또는
ssh centos   # ~/.ssh/config 설정 시
```

### CentOS VM → ServerData 마운트

```bash
sshfs kimi@192.168.0.100:/Volumes/ServerData /mnt/serverdata
ls /mnt/serverdata
```

### 마운트 해제

```bash
fusermount -u /mnt/serverdata
```

### 외부 → 맥미니

```bash
ssh kimi@100.127.117.23
```

### 외부 → VM (현재, Jump Host)

```bash
ssh -J kimi@100.127.117.23 foxmong@192.168.0.113
```

---

## 9. 진행 상태 요약

```text
[1일차 완료]
 ✅ 절전 방지, ServerData/ServerBackup, Tailscale, SSH, SMB
 ✅ VirtualBox + CentOS Stream 10 설치
 ✅ SSH foxmong@192.168.0.113

[2일차 완료 — 오늘]
 ✅ VirtualBox 공유 폴더 설정 (GUI)
 ❌ Guest Additions (ARM64 불가, SSHFS로 대체)
 ✅ SSHFS ServerData 마운트 (/mnt/serverdata)
 ✅ SSH 터미널 복붙 방식 확정

[다음]
 ⬜ VM Tailscale
 ⬜ Docker
 ⬜ Uptime Kuma
 ⬜ 외부 웹 상태 점검
 ⬜ restic 백업 자동화
 ⬜ SSHFS 자동 마운트 / SSH 키
```

---

## 10. 참고 링크 및 파일

| 항목 | 경로/값 |
|---|---|
| 작업 일지 (1일차) | `ServerData/Docs/setup-logs/2026-06-11-macmini-server-setup.md` |
| 작업 일지 (2일차) | `ServerData/Docs/setup-logs/2026-06-12-macmini-server-setup.md` |
| GitHub (백업) | `Foxmong/welcome` branch `cursor/server-setup-docs-f7a6` |
| 맥미니 Tailscale | 100.127.117.23 |
| VM IP | 192.168.0.113 |
| VM 사용자 | foxmong |

---

*이 문서는 2026-06-12 맥미니 홈서버 구축 2일차 작업 내용을 정리한 것입니다.*
