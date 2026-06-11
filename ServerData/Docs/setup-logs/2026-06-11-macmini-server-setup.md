# 맥미니 홈서버 구축 작업 일지

- **작성일:** 2026-06-11
- **서버:** kimiui-Macmini
- **작업자:** kimi
- **목적:** 24/7 맥미니 서버 구축 — 외부 노트북 접속, Linux VM 실습, 파일 공유, 추후 앱 서버 운영

---

## 1. 전체 목표

```text
맥미니를 24/7 개인 서버로 운영
├── 외부(노트북)에서 안전하게 접속
├── Linux VM에서 예제/앱 서버 테스트
├── 2TB SSD(ServerData)에 메인 데이터 저장
└── RED SSD(ServerBackup)에 백업 저장
```

### 추천 아키텍처 (채택 방향)

| 구성요소 | 역할 |
|---|---|
| macOS (내장 256GB) | OS, Docker/VirtualBox, Tailscale, SSH, 관리 스크립트 |
| ServerData (2TB) | 메인 데이터, 공유 폴더, VM 디스크, 앱 데이터 |
| ServerBackup (512GB) | restic 백업, DB dump, 설정 백업 |
| CentOS VM (VirtualBox) | Linux 실습, Docker, 추후 앱 서버 |
| Tailscale | 외부 접속 (VPN, 포트포워딩 불필요) |

---

## 2. 저장장치 구성 결정

### 디스크 역할 분리

| 디스크 | 이름 | 용량 | 용도 |
|---|---|---|---|
| 맥미니 내장 SSD | (시스템) | 256GB | macOS, VirtualBox, Tailscale, 설정, 스크립트 |
| 1번 M.2 SSD | **ServerData** | 2TB | 메인 데이터, 공유, VM, 앱 데이터 |
| 2번 M.2 SSD | **ServerBackup** | 512GB | 백업 전용 (RED에서 이름 변경) |

### 왜 이렇게 나눴는가

- **내장 SSD:** 부팅 안정성, DAS 연결 문제와 무관하게 핵심 서비스 유지
- **2TB ServerData:** 대용량 파일, VM 디스크, Docker volume, 공유 폴더
- **512GB ServerBackup:** 2TB 전체 백업은 불가 → **중요 데이터만 선별 백업**
- **JBOD (RAID 미사용):** 용량이 다른 디스크(2TB + 512GB)라 RAID1/0 부적합, 관리 단순

### ServerData 폴더 구조

```text
/Volumes/ServerData/
├── Shared/       ← SMB 공유 (외부 파일 주고받기)
├── Projects/     ← 작업/개발 파일
├── LinuxVM/      ← VirtualBox VM 디스크
├── AppData/      ← 추후 앱/DB 데이터 (SMB 공유 금지)
├── Downloads/
└── Media/
```

### ServerBackup 폴더 구조

```text
/Volumes/ServerBackup/
├── restic-repo/       ← restic 백업 저장소
├── db-dumps/          ← DB 덤프
├── config-backups/    ← 서버 설정 백업
├── critical-data/     ← 중요 파일 백업
└── logs/              ← 백업 로그
```

---

## 3. 네트워크 설정

### 맥미니 고정 IP (수동 설정)

| 항목 | 값 |
|---|---|
| 연결 | 이더넷 (유선 LAN) |
| IPv4 | 수동 |
| IP 주소 | **192.168.0.100** |
| 서브넷 | 255.255.255.0 |
| 라우터 | 192.168.0.1 |
| DNS | 1.1.1.1, 8.8.8.8 |

### TP-Link 공유기 DHCP

- **문제:** DHCP 범위 `192.168.0.2 ~ 192.168.0.253`에 `.100` 포함 → IP 충돌 가능
- **조치:** DHCP 시작 IP를 `192.168.0.101`로 변경 권장
- **추가 권장:** Address Reservation에 맥미니 MAC → 192.168.0.100 등록

### 접속 방식 정리

| 상황 | SSH | 파일 공유 |
|---|---|---|
| 같은 집 (내부망) | `ssh kimi@192.168.0.100` | `smb://192.168.0.100/Shared` |
| 밖 (Tailscale) | `ssh kimi@100.127.117.23` | `smb://100.127.117.23/Shared` |

> 헷갈리면 **항상 Tailscale IP**로 접속해도 됨.

---

## 4. 완료된 작업 체크리스트

### ✅ 1단계. 맥미니 절전 방지

- 서버 24/7 가동을 위해 sleep/disksleep 비활성화
- `pmset` 및 시스템 설정으로 절전 방지 완료

### ✅ 2단계. ServerData 디스크 설정

- 2TB SSD 이름: **ServerData**
- 기본 폴더 생성 (Shared, Projects, LinuxVM, AppData, Downloads, Media)

### ✅ 3단계. ServerBackup (RED) 설정

- RED 외장하드 이름: **ServerBackup** (`diskutil rename "RED" ServerBackup`)
- 백업용 폴더 생성 (restic-repo, db-dumps, config-backups, critical-data, logs)

### ✅ 4단계. Tailscale 설치

- 맥미니 Tailscale IP: **100.127.117.23**
- macOS 사용자: **kimi**
- 외부 접속용 VPN (포트포워딩 불필요)

### ✅ 5단계. SSH 활성화

- Remote Login ON
- 노트북에서 SSH 접속 확인 완료

### ✅ 6단계. SMB 파일 공유

- 공유 폴더: **`/Volumes/ServerData/Shared`만** 공유
- 전체 디스크 공유하지 않음 (AppData, LinuxVM, ServerBackup 노출 방지)
- 노트북에서 SMB 접속 확인 완료

### ✅ 7단계. VirtualBox + CentOS Stream 10 VM

| 항목 | 설정값 |
|---|---|
| VM 이름 | centos-server |
| OS | CentOS Stream 10 |
| 메모리 | 4GB |
| CPU | 2 |
| 디스크 | 80GB (ServerData/LinuxVM) |
| 네트워크 | Bridged Adapter (en0) |
| EFI | 사용 |
| 사용자 | **foxmong** (관리자) |
| 호스트명 | centos-server |
| VM IP | **192.168.0.113** |

- SSH 접속 확인: `ssh foxmong@192.168.0.113` ✅

---

## 5. 보안 관련 결정 사항

### SMB 공유 정책

- **Shared 폴더만** 공유 — AppData, LinuxVM, ServerBackup은 공유 금지
- 이유: 앱 데이터/VM/백업 노출 방지, 실수 삭제 방지
- 외부 낯선 사람 접속: Tailscale + 계정 인증으로 차단됨 (포트포워딩 미사용)

### SSH vs SMB 역할 분리

| 용도 | 방법 |
|---|---|
| 파일 주고받기 | SMB (Shared) |
| 서버 관리 | SSH |
| 앱 서버 | Docker/API (추후) |
| 백업 | restic → ServerBackup |

---

## 6. DAS / RAID 관련 (참고)

- DAS: M.2 2~5베이 (OWC Express 4M2 등 검토)
- 현재 구성: **JBOD** (2TB + 512GB 개별 사용)
- RAID1은 같은 용량 SSD 2개 필요 → 추후 2TB 추가 시 고려

---

## 7. 미완료 / 다음 작업

### 🔲 CentOS VM — Guest Additions

- ServerData 공유 폴더를 VM에 마운트 (`/mnt/serverdata`)
- VirtualBox: 설정 → 공유 폴더 → `/Volumes/ServerData` 추가

### 🔲 CentOS VM — Tailscale 설치

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### 🔲 CentOS VM — Docker 설치

- Ubuntu VM 대신 CentOS VM에서 Docker CE 설치

### 🔲 restic 백업 자동화

- ServerBackup에 restic 저장소 초기화
- Projects, Shared, AppData, scripts 백업
- cron 또는 launchd로 매일 새벽 3시 자동 실행

### 🔲 SMB 전용 계정 (선택)

- `fileshare` 계정 생성 → Shared만 접근
- 관리용 `kimi` / 파일용 `fileshare` 분리

### 🔲 Cloudflare Tunnel (추후)

- 웹 앱 외부 공개 시 사용
- 관리자 페이지는 Tailscale로만 접속

---

## 8. 자주 쓰는 명령어

### 맥미니 (macOS)

```bash
# Tailscale IP
tailscale ip -4

# SSH 상태
sudo systemsetup -getremotelogin

# 디스크 확인
ls /Volumes

# 네트워크 확인
ping -c 4 192.168.0.1
ping -c 4 google.com
```

### CentOS VM

```bash
# IP 확인
ip a

# SSH 서비스
sudo systemctl status sshd

# 업데이트
sudo dnf update -y
```

### 노트북 → 맥미니

```bash
# SSH (집)
ssh kimi@192.168.0.100

# SSH (밖)
ssh kimi@100.127.117.23

# SSH → CentOS VM
ssh foxmong@192.168.0.113
```

---

## 9. 문제 해결 기록

### SSH Permission denied (CentOS VM)

- **증상:** `ssh centos@192.168.0.113` → Permission denied
- **원인:** 설치 시 사용자명을 `centos`가 아닌 **`foxmong`**으로 설정함
- **해결:** `ssh foxmong@192.168.0.113`으로 접속 → 성공

---

## 10. 진행 상태 요약

```text
[완료]
 1. 절전 방지
 2. ServerData 설정
 3. ServerBackup 설정
 4. Tailscale 설치
 5. 네트워크/DHCP
 6. SSH (맥미니)
 7. SMB Shared 공유
 8. VirtualBox + CentOS Stream 10 VM 설치
 9. SSH (CentOS VM, foxmong)

[다음]
10. Guest Additions + ServerData 마운트
11. CentOS VM Tailscale
12. Docker 설치
13. restic 백up 자동화
```

---

*이 문서는 2026-06-11 맥미니 홈서버 구축 세션 작업 내용을 정리한 것입니다.*
