# Uptime Kuma Email 알림 확인 가이드

> SMTP 설정 후 **Test 성공**과 **실제 Down 알림 수신**까지 검증하는 체크리스트입니다.

---

## 사전 조건

| 항목 | 상태 |
|---|---|
| Uptime Kuma 접속 | `http://100.69.135.104:3001` |
| 모니터 5종 Up | 특히 CentOS VM SSH → `172.17.0.1:22` |
| SMTP 계정 | Gmail 앱 비밀번호 / Naver / Outlook 등 |

---

## 1. SMTP 알림 생성

**Settings → Notifications → Setup Notification → Email (SMTP)**

### Gmail 예시

| 필드 | 값 |
|---|---|
| Friendly Name | `Email 알림` |
| Hostname | `smtp.gmail.com` |
| Port | `587` |
| Security | **STARTTLS** |
| Ignore TLS Error | ❌ |
| Username | `your@gmail.com` |
| Password | **16자리 앱 비밀번호** (일반 비밀번호 X) |
| From Email | `"Uptime Kuma" <your@gmail.com>` |
| To Email | `your@gmail.com` |

### Naver 예시

| 필드 | 값 |
|---|---|
| Hostname | `smtp.naver.com` |
| Port | `587` |
| Security | STARTTLS |
| Username | `naver_id@naver.com` (전체 주소) |
| Password | 네이버 비밀번호 (2단계 시 앱 비밀번호) |

---

## 2. Test 버튼 검증

1. **Test** 클릭
2. Uptime Kuma UI에 **Success** (또는 녹색 메시지) 확인
3. **받는 메일함**에서 테스트 메일 수신 (스팸함도 확인)

### Test 실패 시

| 오류 | 원인 | 해결 |
|---|---|---|
| `Invalid login` | 앱 비밀번호 미사용 | Gmail 2FA + 앱 비밀번호 재생성 |
| `Connection timeout` | 방화벽/포트 | VM에서 `curl -v telnet://smtp.gmail.com:587` |
| `self signed certificate` | TLS | Ignore TLS Error는 최후 수단, 보통 OFF 유지 |
| `535 Authentication failed` (Naver) | ID 형식 | `@naver.com` 전체 이메일 사용 |

VM 방화벽 (SMTP 아웃바운드):

```bash
# 587 아웃바운드는 기본 허용. 막혀 있으면:
sudo firewall-cmd --permanent --add-service=smtp
sudo firewall-cmd --reload
```

---

## 3. 모니터에 알림 연결

**각 모니터 → Edit → Notification → 방금 만든 Email 알림 체크**

| 모니터 | 알림 연결 |
|---|---|
| Mac mini SSH | ✅ |
| Mac mini Tailscale | ✅ |
| CentOS VM SSH | ✅ |
| CentOS VM Tailscale | ✅ |
| Uptime Kuma Self | 선택 (자기 자신 Down은 드묾) |

**Save** 후 Settings → Notifications에서 연결된 모니터 수 확인.

---

## 4. 실제 Down 알림 테스트 (권장)

Test 버튼은 SMTP만 확인합니다. **실제 장애 알림**은 모니터를 일시 중지해야 합니다.

### 방법 A: 모니터 Pause (가장 안전)

1. **Mac mini SSH** 모니터 → **Pause** (1시간 등)
2. 1~2 Heartbeat Interval(60초) 대기
3. 상태가 **Down**으로 바뀌면 이메일 수신 확인
4. **Resume** 으로 복구

### 방법 B: 잘못된 포트로 임시 모니터

1. **Add New Monitor** → TCP Port
2. Hostname: `192.168.0.100`, Port: `9999` (열리지 않은 포트)
3. Email 알림 연결
4. 1~2분 내 Down + 이메일 확인
5. 테스트 모니터 **Delete**

### 방법 C: Uptime Kuma 컨테이너 중지 (Self 모니터)

```bash
cd ~/docker/uptime-kuma
docker compose stop
# Self 모니터에 알림 연결돼 있으면 Down 메일 (다른 경로로 접속해 Resume 불가 주의)
docker compose start
```

---

## 5. Up 복구 알림 (선택)

**Settings → Notifications → Edit → Default enabled**

- **"Also send notification when monitor goes UP"** — 복구 시에도 메일 받기

---

## 6. 완료 체크리스트

```text
[ ] SMTP Test → Success
[ ] 테스트 메일 수신 (받은편함/스팸)
[ ] 4개 핵심 모니터에 Email 알림 연결
[ ] Pause 또는 가짜 Down → 장애 알림 메일 수신
[ ] Resume/복구 후 모니터 Up 100%
[ ] (선택) Up 복구 알림 ON
```

---

## 7. cron 백업 로그 확인 (맥미니)

Email과 별도로 restic 자동 백업 확인:

```bash
# 맥미니
tail -30 /Volumes/ServerBackup/logs/backup.log
restic -r /Volumes/ServerBackup/restic-repo snapshots
crontab -l
```

**완료 기준:** `backup.log`에 매일 03:00 전후 `snapshot ... saved` 또는 에러 없음.

---

## 관련 문서

- [00-HOME-SERVER-HANDOFF.md](../00-HOME-SERVER-HANDOFF.md) — §7 Uptime Kuma 모니터
- [setup-logs/2026-06-14-macmini-server-setup.md](../setup-logs/2026-06-14-macmini-server-setup.md) — §2-9 Email SMTP

---

## 맥미니 경로

```text
/Volumes/ServerData/Docs/guides/uptime-kuma-email-alerts.md
```
