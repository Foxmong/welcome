# Tailscale + SFTP 파일 이동 가이드

- **작성일:** 2026-06-12 (SFTP 방식 중심으로 정리)
- **대상:** kimiui-Macmini 홈서버
- **방식:** **SFTP (`sftp` + `get` / `put`)** — 이 문서의 기본 방법

---

## 1. 개요

### 이 방식이란?

```text
Tailscale  → 안전한 사설망(VPN) 연결
SFTP       → sftp 접속 후 get / put 으로 파일 이동
```

포트포워딩 없이, **집 밖에서도** 맥미니/VM에 파일을 옮길 수 있습니다.

### SFTP 기본 흐름

```text
1. sftp 접속
2. sftp> 프롬프트 확인
3. cd / lcd 로 경로 이동
4. put (업로드) 또는 get (다운로드)
5. exit
```

> **중요:** `get`, `put`은 **일반 터미널 명령이 아닙니다.**  
> 반드시 `sftp` 접속 후 **`sftp>` 프롬프트 안에서** 사용합니다.

---

## 2. 사전 준비 (맥미니)

### 2-1. Tailscale

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

SFTP는 SSH 위에서 동작합니다. Remote Login이 켜져 있어야 합니다.

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
| 포트 | 22 | 22 |

---

## 3. 노트북 측 준비

### 3-1. Tailscale 설치 및 로그인

```text
노트북 Tailscale 설치
→ 맥미니와 같은 Tailnet 계정 로그인
→ Connected 상태 확인
```

### 3-2. SSH 키 로그인 (권장)

SFTP 접속 시에도 같은 SSH 키를 사용합니다.

**노트북에서:**

```bash
ssh-keygen -t ed25519 -C "laptop-to-macmini"
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
nano ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

테스트:

```bash
ssh kimi@100.127.117.23
sftp kimi@100.127.117.23
```

---

## 4. SFTP 접속 방법

### 4-1. 맥미니 접속

**밖 (Tailscale, 추천):**

```bash
sftp kimi@100.127.117.23
```

**집 안 (같은 Wi‑Fi):**

```bash
sftp kimi@192.168.0.100
```

**SSH config 사용 시:**

```bash
sftp macmini
```

### 4-2. CentOS VM 접속 (VM 켜져 있을 때)

**집 안:**

```bash
sftp foxmong@192.168.0.113
```

**밖 (Jump Host, VM Tailscale 미설치 시):**

```bash
sftp -J kimi@100.127.117.23 foxmong@192.168.0.113
```

**VM Tailscale 설치 후:**

```bash
sftp foxmong@VM-Tailscale-IP
```

### 4-3. 접속 성공 확인

프롬프트가 이렇게 바뀌면 SFTP 세션 안입니다:

```text
sftp>
```

이 상태에서만 `get`, `put`, `cd`, `lcd`를 사용할 수 있습니다.

---

## 5. SFTP 명령어 (get / put 중심)

### 5-1. 경로 이동

| 명령 | 설명 | 예시 |
|---|---|---|
| `pwd` | 서버(맥미니) 현재 경로 | `pwd` |
| `lpwd` | 내 PC(노트북) 현재 경로 | `lpwd` |
| `cd 경로` | 서버에서 이동 | `cd /Volumes/ServerData/Shared` |
| `lcd 경로` | 내 PC에서 이동 | `lcd ~/Downloads` |
| `ls` | 서버 파일 목록 | `ls` |
| `lls` | 내 PC 파일 목록 | `lls` |

### 5-2. 파일 업로드 — put

**내 PC → 서버**

| 명령 | 설명 |
|---|---|
| `put 파일` | 파일 1개 업로드 |
| `put -r 폴더` | 폴더 통째 업로드 |
| `mput *.txt` | 여러 파일 업로드 (glob) |

예시:

```text
sftp> lcd ~/Downloads
sftp> cd /Volumes/ServerData/Shared
sftp> put report.pdf
sftp> put -r project-folder
```

### 5-3. 파일 다운로드 — get

**서버 → 내 PC**

| 명령 | 설명 |
|---|---|
| `get 파일` | 파일 1개 다운로드 |
| `get -r 폴더` | 폴더 통째 다운로드 |
| `mget *.pdf` | 여러 파일 다운로드 (glob) |

예시:

```text
sftp> cd /Volumes/ServerData/Projects
sftp> lcd ~/Desktop
sftp> get backup.zip
sftp> get -r myproject
```

### 5-4. 기타 유용한 명령

| 명령 | 설명 |
|---|---|
| `mkdir 이름` | 서버에 폴더 생성 |
| `rm 파일` | 서버 파일 삭제 |
| `rmdir 폴더` | 서버 빈 폴더 삭제 |
| `rename A B` | 서버에서 이름 변경 |
| `!명령` | 로컬 쉘 명령 실행 (예: `!ls`) |
| `help` | SFTP 도움말 |
| `exit` / `bye` | SFTP 종료 |

### 5-5. get / put 옵션

| 옵션 | 설명 |
|---|---|
| `-r` | 폴더 재귀 (하위까지) |
| `-P` | 권한 유지 (일부 클라이언트) |
| `-a` | 재개(resume) 가능 (일부 클라이언트) |

---

## 6. 실전 시나리오 (SFTP만 사용)

### 시나리오 1. 노트북 → 맥미니 Shared 업로드

```bash
sftp kimi@100.127.117.23
```

```text
sftp> cd /Volumes/ServerData/Shared
sftp> lcd ~/Downloads
sftp> put document.pdf
sftp> ls
sftp> exit
```

### 시나리오 2. 맥미니 Projects → 노트북 다운로드

```bash
sftp kimi@100.127.117.23
```

```text
sftp> cd /Volumes/ServerData/Projects
sftp> lcd ~/Desktop
sftp> get -r myproject
sftp> exit
```

### 시나리오 3. 여러 파일 한 번에 업로드

```bash
sftp kimi@100.127.117.23
```

```text
sftp> cd /Volumes/ServerData/Shared
sftp> lcd ~/Downloads
sftp> mput *.pdf
sftp> exit
```

### 시나리오 4. 서버에 폴더 만들고 업로드

```bash
sftp kimi@100.127.117.23
```

```text
sftp> cd /Volumes/ServerData/Shared
sftp> mkdir 2026-06-12
sftp> cd 2026-06-12
sftp> lcd ~/Downloads
sftp> put -r photos
sftp> exit
```

### 시나리오 5. CentOS VM에 파일 넣기

```bash
sftp foxmong@192.168.0.113
```

```text
sftp> lcd ~/Downloads
sftp> put script.sh
sftp> ls
sftp> exit
```

### 시나리오 6. 밖에서 VM 접속 (Jump Host)

```bash
sftp -J kimi@100.127.117.23 foxmong@192.168.0.113
```

```text
sftp> put file.txt
sftp> exit
```

---

## 7. SSH config로 접속 단순화

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

# CentOS VM (밖, 맥미니 경유)
Host centos-via-macmini
    HostName 192.168.0.113
    User foxmong
    ProxyJump kimi@100.127.117.23
    IdentityFile ~/.ssh/id_ed25519
```

사용:

```bash
sftp macmini
sftp centos
sftp centos-via-macmini
```

접속 후 동일하게 `put` / `get` 사용.

---

## 8. 추천 서버 경로

| 서버 경로 | 용도 |
|---|---|
| `/Volumes/ServerData/Shared` | 노트북 ↔ 서버 파일 교환 (기본) |
| `/Volumes/ServerData/Projects` | 작업/개발 프로젝트 |
| `/Volumes/ServerData/Downloads` | 임시 파일 |
| `/Volumes/ServerData/AppData` | 앱 데이터 (신중히) |
| `/Volumes/ServerBackup` | 백업 전용 — SFTP 접근 지양 |

---

## 9. 자주 쓰는 명령어 치트시트

```bash
# === 접속 ===
sftp kimi@100.127.117.23          # 밖
sftp kimi@192.168.0.100           # 집 안
sftp macmini                      # config 사용

# === sftp> 안에서 (반드시 접속 후) ===

# 경로
pwd
lpwd
cd /Volumes/ServerData/Shared
lcd ~/Downloads
ls
lls

# 업로드 (내 PC → 서버)
put file.txt
put -r folder/
mput *.pdf

# 다운로드 (서버 → 내 PC)
get file.txt
get -r folder/
mget *.pdf

# 기타
mkdir new-folder
rm old-file.txt
rename old.txt new.txt
exit

# === VM ===
sftp foxmong@192.168.0.113
sftp -J kimi@100.127.117.23 foxmong@192.168.0.113
```

---

## 10. 흔한 실수

### ❌ 일반 터미널에서 put / get

```bash
put file.txt
# zsh: command not found: put
```

→ `sftp` 접속 먼저.

### ❌ SSH 세션에서 put / get

```bash
ssh kimi@100.127.117.23
put file.txt
# 작동 안 함
```

→ SSH가 아니라 **SFTP**로 접속.

### ❌ 경로 이동 없이 put

```text
sftp> put file.txt
# 어디로 올라갔는지 모름
```

→ `cd`(서버), `lcd`(로컬) 먼저 확인.

### ✅ 올바른 순서

```bash
sftp kimi@100.127.117.23
cd /Volumes/ServerData/Shared
lcd ~/Downloads
put file.txt
exit
```

---

## 11. GUI로 SFTP 쓰기 (선택)

터미널 `sftp` 대신 GUI를 쓰면 **내부적으로 같은 SFTP(get/put)** 입니다.

### Cyberduck (macOS)

```text
프로토콜: SFTP
서버: 100.127.117.23
포트: 22
사용자: kimi
SSH 키 또는 비밀번호
```

드래그 앤 드롭 = put / get 과 동일.

### FileZilla

```text
호스트: sftp://100.127.117.23
사용자: kimi
포트: 22
```

---

## 12. 보안

```text
✅ Tailscale로만 외부 접속
✅ SSH 키 로그인
✅ kimi / foxmong 일반 사용자만
✅ Shared / Projects 위주 사용

❌ SSH 22번 포트 공유기 외부 공개
❌ root SFTP
❌ ServerBackup 임의 수정
```

---

## 13. 문제 해결

| 증상 | 확인 |
|---|---|
| `command not found: put` | `sftp` 접속 안 함 → `sftp user@host` 먼저 |
| Connection refused | 맥미니 SSH ON, Tailscale Connected 확인 |
| Permission denied | 사용자명·비밀번호·SSH 키 확인 |
| No such file | `cd` / `lcd` 경로 확인, `ls` / `lls`로 목록 확인 |
| Tailscale 접속 안 됨 | 노트북·맥미니 같은 Tailnet, `ping 100.127.117.23` |
| put 후 파일 안 보임 | `cd` 경로 확인, `ls`로 서버 목록 확인 |

---

## 14. 현재 환경 빠른 참조

```text
맥미니
  SFTP 접속:  sftp kimi@100.127.117.23
  Shared:     cd /Volumes/ServerData/Shared
  Projects:   cd /Volumes/ServerData/Projects

CentOS VM
  SFTP 접속:  sftp foxmong@192.168.0.113
  홈:         cd ~
```

### 한 세션 예시 (복사해서 사용)

```bash
sftp kimi@100.127.117.23
```

```text
cd /Volumes/ServerData/Shared
lcd ~/Downloads
put 내파일.pdf
ls
exit
```

---

*맥미니 홈서버 — Tailscale + SFTP (get/put) 파일 이동 가이드*
