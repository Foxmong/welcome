# 앱 서버 Docker Compose 가이드

> CentOS VM에서 **~/docker/** 로컬 경로 기준으로 웹 앱·리버스 프록시를 올리는 방법입니다.  
> Docker bind mount는 **SSHFS(`/mnt/serverdata`) 불가** — 반드시 VM 로컬 디스크 사용.

---

## 아키텍처 (목표)

```text
[인터넷]
    |
[Cloudflare Tunnel]  ← 포트포워딩 없음, Tailscale 대안/보완
    |
[Nginx Proxy Manager :81]  ← HTTPS, 서브도메인 라우팅
    |
[앱 컨테이너 :8080]  ← whoami, Gitea, Nextcloud 등
    |
[Uptime Kuma :3001]  ← 이미 운영 중
```

**현재 단계:** Uptime Kuma ✅ → **whoami 테스트 앱** → NPM → Cloudflare Tunnel

---

## 1. 디렉터리 구조 (VM)

```bash
mkdir -p ~/docker/{uptime-kuma,myapp,nginx-proxy-manager,cloudflared}
```

```text
~/docker/
├── uptime-kuma/          ← 운영 중
├── myapp/                ← 테스트/실제 앱
├── nginx-proxy-manager/  ← 리버스 프록시 (선택)
└── cloudflared/          ← Cloudflare Tunnel
```

템플릿 compose 파일:

```text
/Volumes/ServerData/Docs/scripts/docker/
```

---

## 2. 테스트 앱 (whoami)

### 파일 복사

```bash
# SFTP 또는 SSHFS로 Docs/scripts/docker/myapp/ 내용을 VM에 복사
cd ~/docker/myapp
# docker-compose.yml → scripts/docker/myapp/docker-compose.yml 과 동일
```

### docker-compose.yml

```yaml
services:
  whoami:
    image: traefik/whoami:latest
    container_name: whoami
    restart: unless-stopped
    ports:
      - "8080:80"
```

### 실행

```bash
cd ~/docker/myapp
docker compose up -d
curl http://127.0.0.1:8080
# Hostname: ..., IP: ... 출력
```

**외부 (Tailscale):** `http://100.69.135.104:8080`

### Uptime Kuma 모니터 추가 (선택)

| Type | Target |
|---|---|
| HTTP | `http://127.0.0.1:8080` |

Docker bridge 안에서 Kuma → `127.0.0.1:8080`은 컨테이너 자신이므로, **호스트 IP** 사용:

| Type | Target |
|---|---|
| HTTP | `http://172.17.0.1:8080` |

---

## 3. Nginx Proxy Manager (선택, 도메인 HTTPS)

도메인 + Let's Encrypt가 필요할 때 NPM을 앞단에 둡니다.  
**Cloudflare Tunnel만 쓸 경우** NPM 없이 Tunnel → Uptime Kuma 직접 연결도 가능.

### 설치

```bash
mkdir -p ~/docker/nginx-proxy-manager/{data,letsencrypt}
cd ~/docker/nginx-proxy-manager
# docker-compose.yml 복사 (scripts/docker/nginx-proxy-manager/)
docker compose up -d
```

### 접속

| URL | 용도 |
|---|---|
| `http://100.69.135.104:81` | NPM 관리 UI |
| 기본 로그인 | `admin@example.com` / `changeme` (최초 로그인 후 변경) |

### Proxy Host 예시 (whoami)

1. **Hosts → Proxy Hosts → Add**
2. Domain: `whoami.yourdomain.com` (Cloudflare DNS 필요)
3. Forward: `172.17.0.1:8080` (또는 `host.docker.internal` 미지원 시 VM IP `192.168.0.113:8080`)
4. SSL → Request new certificate (도메인이 VM에 직접 열려 있어야 LE 성공 — Tunnel 사용 시 아래 Cloudflare 가이드 참고)

**참고:** Cloudflare Tunnel + Full SSL 조합이면 NPM 대신 Tunnel Public Hostname만으로도 충분한 경우가 많습니다.

---

## 4. 실제 앱 추가 시 패턴

### Gitea (예시 스켈레톤)

```bash
mkdir -p ~/docker/gitea/data
```

```yaml
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
```

데이터는 **~/docker/gitea/data** (로컬).  
ServerData 백업이 필요하면 **restic** (맥미니) 또는 주기적 `rsync`를 SSHFS로 *읽기*만 사용.

---

## 5. 방화벽 (CentOS)

```bash
sudo firewall-cmd --permanent --add-port=8080/tcp   # whoami
sudo firewall-cmd --permanent --add-port=81/tcp     # NPM
sudo firewall-cmd --reload
```

Tailscale만 쓸 때는 외부 포트를 최소화하고, Cloudflare Tunnel은 **아웃바운드만** 필요.

---

## 6. 체크리스트

```text
[ ] ~/docker/myapp/docker-compose.yml 배포
[ ] docker compose up -d && curl 127.0.0.1:8080
[ ] Tailscale에서 :8080 접속
[ ] (선택) NPM :81 설치 및 Proxy Host
[ ] Uptime Kuma HTTP 모니터 172.17.0.1:8080
[ ] Cloudflare Tunnel 가이드로 외부 HTTPS
```

---

## 관련 문서

- [cloudflare-tunnel.md](./cloudflare-tunnel.md)
- [vm-sshfs-automount.md](./vm-sshfs-automount.md) — Docker ≠ SSHFS
- [00-HOME-SERVER-HANDOFF.md](../00-HOME-SERVER-HANDOFF.md)

---

## 맥미니 경로

```text
/Volumes/ServerData/Docs/guides/app-server-docker-compose.md
/Volumes/ServerData/Docs/scripts/docker/
```
