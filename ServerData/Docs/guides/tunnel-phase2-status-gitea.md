# Tunnel Phase 2 — status(Kuma) · Access · Gitea

> **도메인:** `foxmong.cc`  
> **완료:** `whoami.foxmong.cc` → `192.168.0.113:8080`  
> **순서:** ① status+Access → ② Kuma 모니터 → ③ 토큰 교체 → ④ 문서 → ⑤ Gitea

---

## 1. Uptime Kuma 공개 + Cloudflare Access

### 1-1. Published application route

Zero Trust → **Networks** → **Connectors** → **Tunnels** → **home-server** → **Published application routes** → **Add**

| 필드 | 값 |
|---|---|
| Subdomain | `status` |
| Domain | `foxmong.cc` |
| Type | HTTP |
| URL | `192.168.0.113:3001` |

Save.

### 1-2. DNS (자동 안 되면)

[dash.cloudflare.com](https://dash.cloudflare.com) → **foxmong.cc** → **DNS** → **Records**

| Type | Name | Target |
|---|---|---|
| CNAME | `status` | `<TUNNEL_ID>.cfargotunnel.com` |

(Tunnel ID = home-server Overview, whoami와 동일 패턴)

### 1-3. Cloudflare Access (로그인 보호)

Zero Trust → **Access** → **Applications** → **Add an application**

1. **Self-hosted**
2. Application name: `Uptime Kuma`
3. Session Duration: 24h (원하는 값)
4. **Add public hostname** (또는 Subdomain):
   - `status.foxmong.cc`
5. **Next** → **Add a policy**
   - Policy name: `Allow me`
   - Action: **Allow**
   - Include: **Emails** → `foxmong0410@gmail.com` (본인 이메일)
   - 또는 **Login methods** → One-time PIN
6. **Save application**

### 1-4. 확인

```text
https://status.foxmong.cc
```

→ Cloudflare 로그인 화면 → 통과 후 Uptime Kuma 대시보드

---

## 2. Uptime Kuma 모니터 추가

`http://100.69.135.104:3001` (Tailscale) 또는 status Access 통과 후:

**Add New Monitor**

| 항목 | 값 |
|---|---|
| Type | HTTP(s) |
| Friendly Name | whoami (public) |
| URL | `https://whoami.foxmong.cc` |
| Interval | 60 |

**Save** → 1~2분 후 **Up** 확인.

(선택) status 자체 모니터:

| URL | `https://status.foxmong.cc` (Access 있으면 Kuma가 403일 수 있음 — whoami만 권장) |

---

## 3. Tunnel 토큰 교체 (보안)

채팅 등에 토큰 노출됐을 때 수행.

### Cloudflare

Zero Trust → **Tunnels** → **home-server** → **Configure** → **⋯** → **Rotate token**  
(또는 Delete connector token → 새 토큰 발급)

새 `TUNNEL_TOKEN=eyJ...` 복사.

### VM

```bash
cd ~/docker/cloudflared
nano .env
# TUNNEL_TOKEN=새토큰
docker compose down
docker compose up -d
docker logs cloudflared --tail 10
```

Tunnel **Healthy** 확인.  
**Published routes / DNS는 유지** — 토큰만 바뀜.

---

## 4. 문서

맥 ServerData 동기화:

```bash
# Git pull 또는 curl로 Docs 업데이트
/Volumes/ServerData/Docs/setup-logs/2026-06-14-macmini-server-setup.md
/Volumes/ServerData/Docs/00-HOME-SERVER-HANDOFF.md
```

---

## 5. Gitea 배포

### VM

```bash
mkdir -p ~/docker/gitea/data
cd ~/docker/gitea

cat > docker-compose.yml << 'EOF'
services:
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    restart: unless-stopped
    ports:
      - "3000:3000"
      - "2222:22"
    volumes:
      - ./data:/data
    environment:
      - USER_UID=1000
      - USER_GID=1000
EOF

docker compose up -d
```

초기 설정: `http://100.69.135.104:3000` → 설치 마법사

| 항목 | 권장 |
|---|---|
| Database | SQLite (기본) |
| Domain | `git.foxmong.cc` (나중에 Tunnel 연결 시) |
| SSH port | 2222 |
| HTTP port | 3000 |

### Tunnel (선택)

Published route:

| Subdomain | URL |
|---|---|
| `git` | `http://192.168.0.113:3000` |

→ `https://git.foxmong.cc` + **Access** 권장

### 방화벽

```bash
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --permanent --add-port=2222/tcp
sudo firewall-cmd --reload
```

---

## 완료 체크리스트

```text
[ ] status.foxmong.cc → Kuma (Access 로그인)
[ ] Kuma 모니터 https://whoami.foxmong.cc Up
[ ] Tunnel 토큰 rotate + cloudflared 재기동
[ ] Docs 동기화
[ ] Gitea :3000 + (선택) git.foxmong.cc
```

---

## 공개 URL 요약

| URL | 서비스 | Access |
|---|---|---|
| https://whoami.foxmong.cc | whoami 테스트 | 선택 |
| https://status.foxmong.cc | Uptime Kuma | ✅ 권장 |
| https://git.foxmong.cc | Gitea | ✅ 권장 |

Tailscale 관리: `100.69.135.104:3001`, `:8080`, `:3000` 유지.
