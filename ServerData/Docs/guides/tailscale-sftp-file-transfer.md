# Tailscale + SFTP 파일 이동 가이드

- **작성일:** 2026-06-12
- **대상:** kimiui-Macmini 홈서버
- **용도:** 외부/내부 노트북에서 맥미니·CentOS VM으로 파일 주고받기

---

## 1. 개요

### 이 방식이란?

```text
Tailscale  → 안전한 사설망(VPN) 연결
SFTP       → SSH 위에서 파일 업로드/다운로드
```

포트포워딩 없이, **집 밖에서도** 맥미니/VM에 파일을 옮길 수 있습니다.

### SMB vs SFTP vs SSHFS (현재 환경)

| 방식 | 용도 | 접근 범위 | 외부 접속 |
|---|---|---|---|
| **SMB** | Finder처럼 폴더 탐색 | Shared 폴더만 | Tailscale IP로 가능 |
| **SFTP** | 파일 업/다운, 스크립트 | SSH 권한 범위 | Tailscale IP로 가능 ✅ |
| **SSHFS** | VM에서 ServerData 마운트 | VM ↔ 맥미니 전체 | VM 내부에서만 |

**추천 역할 분리:**

```text
일상 파일 주고받기 (노트북)  → SFTP 또는 SMB(Shared)
서버 관리                    → SSH
VM ↔ ServerData              → SSHFS (VM 안)
```

---

## 2. 사전 준비 (맥미니)

### 2-1. Tailscale

이미 설치·연결된 상태:

```text
맥미니 Tailscale IP: 100.127.117.23
사용자: kimi
```

확인:

```bash
tailscale ip -4
tailscale status
```

### 2-2. SSH (Remote Login) 활성화

SFTP는 **SSH가 켜져 있어야** 동작합니다.

```bash
sudo systemsetup -setremotelogin on
sudo systemsetup -getremotelogin
```

정상 출력:

```text
Remote Login: On
```

### 2-3. 네트워크 정보

| 구분 | 맥미니 | CentOS VM |
|---|---|---|
| 집 안 IP | 192.168.0.100 | 192.168.0.113 |
| Tailscale IP | 100.127.117.23 | (VM Tailscale 설치 후) |
| 사용자 | kimi | foxmong |

---

## 3. 노트북 측 준비

### 3-1. Tailscale 설치 및 로그인

```text
노트북에 Tailscale 설치
→ 맥미니와 같은 Tailnet 계정으로 로그인
→ Connected 상태 확인
```

### 3-2. SSH 키 로그인 (권장)

비밀번호 대신 키 사용 시 편하고 안전합니다.

**노트북에서:**

```bash
ssh-keygen -t ed25519 -C "laptop-to-macmini"
```

공개키를 맥미니에 등록:

```bash
ssh-copy-id kimi@100.127.117.23
```

macOS에 `ssh-copy-id`가 없으면:

```bash
cat ~/.ssh/id_ed25519.pub
```

출력 내용을 맥미니 `~/.ssh/authorized_keys`에 추가.

**맥미니에서:**

```bash
mkdir -p ~/.ssh
chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys   # 공개키 한 줄 붙여넣기
chmod 600 ~/.ssh/authorized_keys
```

테스트:

```bash
ssh kimi@100.127.117.23
```

비밀번호 없이 접속되면 SFTP도 키로 사용 가능합니다.

---

## 4. 접속 주소 정리

### 맥미니 SFTP

| 상황 | 호스트 | 포트 |
|---|---|---|
| 같은 집 | `192.168.0.100` | 22 |
| 밖 (Tailscale) | `100.127.117.23` | 22 |

### CentOS VM SFTP (VM 켜져 있을 때)

| 상황 | 호스트 | 포트 |
|---|---|---|
| 같은 집 | `192.168.0.113` | 22 |
| 밖 (Jump Host) | 맥미니 경유 | 22 |
| 밖 (VM Tailscale 설치 후) | VM Tailscale IP | 22 |

---

## 5. SFTP 사용법 — 터미널 (sftp)

### 5-1. 접속

**맥미니 (Tailscale):**

```bash
sftp kimi@100.127.117.23
```

**맥미니 (집 안):**

```bash
sftp kimi@192.168.0.100
```

**CentOS VM (집 안):**

```bash
sftp foxmong@192.168.0.113
```

### 5-2. 자주 쓰는 명령어

접속 후 `sftp>` 프롬프트에서:

| 명령 | 설명 |
|---|---|
| `ls` | 서버(원격) 현재 폴더 목록 |
| `lls` | 내 PC(로컬) 현재 폴더 목록 |
| `pwd` | 서버 현재 경로 |
| `lpwd` | 로컬 현재 경로 |
| `cd 경로` | 서버에서 이동 |
| `lcd 경로` | 로컬에서 이동 |
| `get 파일` | 서버 → 내 PC 다운로드 |
| `get -r 폴더` | 서버 폴더 통째 다운로드 |
| `put 파일` | 내 PC → 서버 업로드 |
| `put -r 폴더` | 로컬 폴더 통째 업로드 |
| `mkdir 이름` | 서버에 폴더 생성 |
| `rm 파일` | 서버 파일 삭제 |
| `rename A B` | 서버에서 이름 변경 |
| `exit` / `bye` | 종료 |

### 5-3. 실전 예시

**노트북 → 맥미니 Shared에 파일 업로드:**

```bash
sftp kimi@100.127.117.23
cd /Volumes/ServerData/Shared
lcd ~/Downloads
put report.pdf
exit
```

**맥미니 Projects → 노트북으로 받기:**

```bash
sftp kimi@100.127.117.23
cd /Volumes/ServerData/Projects
lcd ~/Desktop
get -r myproject
exit
```

**한 줄로 업로드 (접속 없이):**

```bash
scp ~/Downloads/file.txt kimi@100.127.117.23:/Volumes/ServerData/Shared/
```

**한 줄로 다운로드:**

```bash
scp kimi@100.127.117.23:/Volumes/ServerData/Shared/file.txt ~/Downloads/
```

**폴더 통째 복사:**

```bash
scp -r kimi@100.127.117.23:/Volumes/ServerData/Projects/myproject ~/Desktop/
```

---

## 6. SFTP 사용법 — GUI

### 6-1. macOS Finder (간단, SMB와 유사)

Tailscale 연결 후:

```text
이동 → 서버에 연결
sftp://100.127.117.23
```

또는 SSH 마운트 후 Finder에서 SFTP 드라이브처럼 사용 (아래 sshfs 참고).

**참고:** macOS Finder는 **SMB**가 더 익숙합니다.

```text
smb://100.127.117.23/Shared
```

Shared 폴더만 필요하면 SMB, **임의 경로** 접근은 SFTP/scp.

### 6-2. Cyberduck / FileZilla (SFTP 전용 GUI)

**Cyberduck (macOS 추천):**

```text
새 연결
프로토콜: SFTP
서버: 100.127.117.23
포트: 22
사용자: kimi
비밀번호 또는 SSH 키
```

**FileZilla:**

```text
호스트: sftp://100.127.117.23
사용자: kimi
포트: 22
```

연결 후 드래그 앤 드롭으로 업/다운로드.

### 6-3. VS Code / Cursor Remote-SSH

```text
Remote-SSH 확장
→ kimi@100.127.117.23
→ /Volumes/ServerData/Projects 직접 편집
```

코드 작업 시 SFTP보다 편할 수 있습니다.

---

## 7. rsync (대용량·동기화)

SFTP/scp보다 **재전송·차분 동기화**에 유리합니다.

**노트북 → 맥미니:**

```bash
rsync -avh --progress ~/Projects/ kimi@100.127.117.23:/Volumes/ServerData/Projects/
```

**맥미니 → 노트북:**

```bash
rsync -avh --progress kimi@100.127.117.23:/Volumes/ServerData/Shared/ ~/Downloads/Shared/
```

**삭제 반영 (미러링, 주의):**

```bash
rsync -avh --delete ~/Projects/ kimi@100.127.117.23:/Volumes/ServerData/Projects/
```

옵션:

```text
-a  아카이브 (권한·시간 유지)
-v  상세 출력
-h  사람이 읽기 쉬운 크기
--progress  진행률
```

---

## 8. SSH config로 접속 단순화

노트북 `~/.ssh/config`:

```text
# 맥미니 (Tailscale)
Host macmini
    HostName 100.127.117.23
    User kimi
    IdentityFile ~/.ssh/id_ed25519

# 맥미니 (집 안)
Host macmini-local
    HostName 192.168.0.100
    User kimi
    IdentityFile ~/.ssh/id_ed25519

# CentOS VM (집 안)
Host centos
    HostName 192.168.0.113
    User foxmong
    IdentityFile ~/.ssh/id_ed25519
```

사용:

```bash
sftp macmini
scp file.txt macmini:/Volumes/ServerData/Shared/
ssh macmini
rsync -avh ./data/ macmini:/Volumes/ServerData/Projects/data/
```

---

## 9. CentOS VM 파일 이동

### 9-1. 노트북 → VM (집 안)

```bash
sftp foxmong@192.168.0.113
put file.txt
```

### 9-2. 노트북 → VM (밖, Jump Host)

VM Tailscale 미설치 시:

```bash
scp -J kimi@100.127.117.23 file.txt foxmong@192.168.0.113:~/
```

또는 `~/.ssh/config`:

```text
Host centos-via-macmini
    HostName 192.168.0.113
    User foxmong
    ProxyJump kimi@100.127.117.23
    IdentityFile ~/.ssh/id_ed25519
```

```bash
sftp centos-via-macmini
```

### 9-3. VM Tailscale 설치 후 (추천)

```bash
sftp foxmong@VM-Tailscale-IP
```

맥미니 거치지 않고 VM에 직접 SFTP.

---

## 10. 추천 폴더 경로

| 경로 | 용도 | SFTP 사용 |
|---|---|---|
| `/Volumes/ServerData/Shared` | 노트북 ↔ 서버 파일 교환 | ✅ 추천 |
| `/Volumes/ServerData/Projects` | 개발/작업 프로젝트 | ✅ |
| `/Volumes/ServerData/Downloads` | 임시 다운로드 | ✅ |
| `/Volumes/ServerData/AppData` | 앱/DB 데이터 | ⚠️ 관리용만 |
| `/Volumes/ServerBackup` | 백업 전용 | ❌ SFTP 접근 지양 |

---

## 11. 보안

### 해야 할 것

```text
SSH 키 로그인 사용
Tailscale로만 외부 접속 (포트포워딩 X)
강한 macOS/VM 비밀번호
Tailnet에 필요한 기기만 등록
Shared/AppData 역할 분리
```

### 하지 말 것

```text
SSH 22번 포트 공유기에 외부 공개
SMB 445 포트 인터넷 공개
약한 비밀번호
root SFTP 허용 (가능하면 일반 사용자만)
```

### root SFTP

macOS/CentOS 기본은 **일반 사용자 SFTP**입니다.  
`kimi`, `foxmong` 계정으로 접속하는 것이 안전합니다.

---

## 12. 문제 해결

### Connection refused

```bash
# 맥미니에서
sudo systemsetup -getremotelogin
tailscale status
```

SSH OFF 또는 Tailscale 미연결 확인.

### Permission denied

- 사용자명 확인 (`kimi` / `foxmong`)
- 비밀번호 또는 SSH 키 확인
- `ssh-copy-id` 재실행

### Tailscale IP로 안 됨

```bash
# 노트북에서
tailscale status
ping 100.127.117.23
```

같은 Tailnet인지, 맥미니 Tailscale Connected인지 확인.

### 경로 없음 (No such file)

```bash
# 맥미니에서
ls /Volumes/ServerData/Shared
```

ServerData 마운트 여부 확인.

### scp/sftp 느림

- 대용량은 `rsync` 사용
- Wi-Fi보다 유선 LAN이 빠름
- Tailscale은 집 밖에서 약간 지연 가능 (정상)

---

## 13. 자주 쓰는 명령어 치트시트

```bash
# === 접속 ===
sftp kimi@100.127.117.23
ssh kimi@100.127.117.23

# === 파일 1개 ===
scp local.txt kimi@100.127.117.23:/Volumes/ServerData/Shared/
scp kimi@100.127.117.23:/Volumes/ServerData/Shared/remote.txt ./

# === 폴더 ===
scp -r ./folder kimi@100.127.117.23:/Volumes/ServerData/Projects/
rsync -avh ./folder/ kimi@100.127.117.23:/Volumes/ServerData/Projects/folder/

# === SFTP 내부 ===
cd /Volumes/ServerData/Shared
lcd ~/Downloads
put file.pdf
get file.pdf
get -r project/
exit

# === VM (Jump) ===
scp -J kimi@100.127.117.23 file.txt foxmong@192.168.0.113:~/

# === 확인 ===
tailscale ip -4          # 맥미니
ssh kimi@100.127.117.23 "ls /Volumes/ServerData"
```

---

## 14. 시나리오별 추천

| 하고 싶은 일 | 추천 방법 |
|---|---|
| PDF/문서 몇 개 올리기 | `scp put` 또는 Cyberduck |
| 프로젝트 폴더 동기화 | `rsync` |
| Finder처럼 Shared 탐색 | SMB `smb://100.127.117.23/Shared` |
| ServerData 임의 경로 접근 | SFTP/scp |
| 코드 편집 | VS Code Remote-SSH |
| VM에 파일 넣기 | `scp foxmong@192.168.0.113` 또는 Jump Host |
| VM ↔ ServerData | VM 안 SSHFS (이미 구성됨) |

---

## 15. 현재 환경 빠른 참조

```text
맥미니
  사용자:     kimi
  집 IP:      192.168.0.100
  Tailscale:  100.127.117.23
  SFTP:       sftp kimi@100.127.117.23
  Shared:     /Volumes/ServerData/Shared

CentOS VM
  사용자:     foxmong
  집 IP:      192.168.0.113
  SFTP:       sftp foxmong@192.168.0.113
  ServerData: /mnt/serverdata (SSHFS, VM 안)
```

---

*맥미니 홈서버 — Tailscale + SFTP 파일 이동 가이드*
