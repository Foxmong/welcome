# Cloudflare Tunnel 가이드

> **포트포워딩 없이** 도메인으로 Uptime Kuma·앱에 HTTPS 접속. Tailscale과 병행 가능.

---

## 개요

| 방식 | 장점 | 단점 |
|---|---|---|
| Tailscale | VPN, 설정 간단 | 클라이언트 설치 필요 |
| Cloudflare Tunnel | 브라우저만으로 공개 URL | Cloudflare 계정·도메인 필요 |

**권장:** 관리용(Uptime Kuma)은 Tailscale + Tunnel 이중, 공개 서비스만 Tunnel.

---

## 사전 준비

1. [Cloudflare](https://dash.cloudflare.com) 계정
2. 도메인을 Cloudflare DNS로 이전 (또는 NS 위임)
3. CentOS VM Docker 동작 중
4. (선택) Cloudflare Access — Uptime Kuma에 로그인 보호

---

## 1. Zero Trust에서 Tunnel 생성

1. [Cloudflare Zero Trust](https://one.dash.cloudflare.com) → **Networks** → **Tunnels**
2. **Create a tunnel** → 이름: `home-server`
3. **Cloudflared** 선택 → **Docker** 탭
4. `TUNNEL_TOKEN=eyJ...` 복사 (`.env`에만 저장, Git 금지)

---

## 2. VM에 cloudflared 배포

### 디렉터리

```bash
mkdir -p ~/docker/cloudflared
cd ~/docker/cloudflared
```

### docker-compose.yml

문서 템플릿: `Docs/scripts/docker/cloudflared/docker-compose.yml`

```yaml
services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel run
    environment:
      TUNNEL_TOKEN: ${TUNNEL_TOKEN}
```

### .env

```bash
cp .env.example .env
nano .env
# TUNNEL_TOKEN=eyJ... (대시보드에서 복사)
chmod 600 .env
```

### 실행

```bash
docker compose up -d
docker logs cloudflared --tail 20
# "Connection ... registered" / "Serving tunnel" 유사 메시지
```

---

## 3. Public Hostname (라우팅)

Zero Trust → Tunnels → `home-server` → **Public Hostname** → Add

### Uptime Kuma 예시

| 필드 | 값 |
|---|---|
| Subdomain | `status` (또는 `kuma`) |
| Domain | `yourdomain.com` |
| Type | HTTP |
| URL | `192.168.0.113:3001` 또는 `localhost:3001` |

**주의:** cloudflared 컨테이너가 **host network가 아니면** `localhost:3001`은 cloudflared 자신을 가리킵니다.

**해결 (택1):**

| 방법 | Service URL |
|---|---|
| VM 호스트 IP | `192.168.0.113:3001` ✅ 권장 |
| Docker bridge 게이트웨이 | `172.17.0.1:3001` |
| host network mode | compose에 `network_mode: host` → `127.0.0.1:3001` |

### whoami 앱 예시

| Subdomain | URL |
|---|---|
| `whoami` | `192.168.0.113:8080` |

접속: `https://status.yourdomain.com`, `https://whoami.yourdomain.com`

---

## 4. Cloudflare SSL/TLS

Cloudflare Dashboard → 도메인 → **SSL/TLS**

| 모드 | 설명 |
|---|---|
| **Full** | Cloudflare ↔ origin HTTP (VM :3001) — Tunnel에 흔함 |
| Full (strict) | origin에도 인증서 필요 (NPM 사용 시) |

Tunnel + VM plain HTTP(3001) → **Full** 로 충분.

---

## 5. Access로 Uptime Kuma 보호 (강력 권장)

공개 URL을 열면 누구나 Kuma 대시보드 접근 가능.

1. Zero Trust → **Access** → **Applications** → Add
2. Type: Self-hosted
3. Domain: `status.yourdomain.com`
4. Policy: Allow — Email OTP 또는 Google/GitHub 로그인
5. Save

---

## 6. NPM과 함께 쓰기 (고급)

```text
Internet → Cloudflare Tunnel → NPM (:443) → 내부 앱들
```

- Tunnel Public Hostname → `192.168.0.113:443`
- NPM에서 서브도메인별 Proxy Host
- Let's Encrypt는 Tunnel 환경에서 NPM 단독 LE가 까다로울 수 있음 → **Cloudflare Origin Certificate** 또는 Tunnel 직연결 권장

---

## 7. 검증 체크리스트

```text
[ ] Zero Trust Tunnel Created
[ ] ~/docker/cloudflared/.env + docker compose up -d
[ ] docker logs cloudflared — registered
[ ] Public Hostname → Uptime Kuma (192.168.0.113:3001)
[ ] https://status.yourdomain.com 브라우저 접속
[ ] (권장) Cloudflare Access 정책 적용
[ ] Uptime Kuma 모니터 추가 (선택): HTTPS URL
```

---

## 8. 문제 해결

| 증상 | 해결 |
|---|---|
| 502 Bad Gateway | Service URL을 `localhost` 대신 `192.168.0.113` 로 |
| Tunnel disconnected | `docker logs cloudflared`, 토큰 만료/오타 |
| SSL loop | SSL mode Full vs Flexible 확인 |
| VM 재부팅 후 끊김 | `restart: unless-stopped`, VM autostart plist |

---

## 9. 보안 요약

```text
✅ 포트포워딩 불필요 (아웃바운드만)
✅ Tailscale 관리 경로 유지 (100.69.135.104:3001)
⚠️ Tunnel URL은 공개 — Access 또는 Kuma 강한 비밀번호
❌ TUNNEL_TOKEN을 Git/문서에 평문 저장 금지
```

---

## 관련 문서

- [app-server-docker-compose.md](./app-server-docker-compose.md)
- [00-HOME-SERVER-HANDOFF.md](../00-HOME-SERVER-HANDOFF.md)

---

## 맥미니 경로

```text
/Volumes/ServerData/Docs/guides/cloudflare-tunnel.md
/Volumes/ServerData/Docs/scripts/docker/cloudflared/
```
