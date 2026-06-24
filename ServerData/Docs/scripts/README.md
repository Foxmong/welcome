# 홈서버 스크립트·Docker 템플릿

맥미니 / CentOS VM에 복사해 실행하는 파일입니다.

## CentOS VM

| 파일 | 용도 |
|---|---|
| [centos/install-sshfs-automount.sh](./centos/install-sshfs-automount.sh) | SSHFS 자동 마운트 설치 |
| [centos/serverdata-sshfs.service](./centos/serverdata-sshfs.service) | systemd unit 템플릿 |

가이드: [../guides/vm-sshfs-automount.md](../guides/vm-sshfs-automount.md)

## macOS (맥미니)

| 파일 | 용도 |
|---|---|
| [macos/install-vm-autostart.sh](./macos/install-vm-autostart.sh) | 부팅 시 VirtualBox VM 시작 |
| [centos/verify-ops-stabilization.sh](./centos/verify-ops-stabilization.sh) | VM 운영 상태 검증 |

## Docker compose (VM ~/docker/ 로 복사)

| 디렉터리 | 용도 |
|---|---|
| [docker/uptime-kuma/](./docker/uptime-kuma/) | Uptime Kuma (참고용, 이미 운영 중) |
| [docker/gitea/](./docker/gitea/) | Gitea Git 서버 |
| [docker/nginx-proxy-manager/](./docker/nginx-proxy-manager/) | 리버스 프록시 |
| [docker/cloudflared/](./docker/cloudflared/) | Cloudflare Tunnel |

## 블로그 자동화 (맥미니 ~/scripts/blog)

| 파일 | 용도 |
|---|---|
| [blog/install-blog-scripts.sh](./blog/install-blog-scripts.sh) | 스크립트 맥미니 설치 |
| [blog/telegram-alert.sh](./blog/telegram-alert.sh) | 실패·에스컬레이션 Telegram 알림 |
| [blog/pipeline-common.sh](./blog/pipeline-common.sh) | 재시도, 로그, notify_failure |
| [blog/blog-orchestrator.sh](./blog/blog-orchestrator.sh) | stock/deal 파이프라인 골격 |
| [blog/config/blog.env.example](./blog/config/blog.env.example) | 설정 템플릿 |

가이드: [../guides/blog-automation-openclaw-openrouter.md](../guides/blog-automation-openclaw-openrouter.md) Phase 4-B

```bash
# 예: 맥미니
cd /Volumes/ServerData/Docs/scripts/blog
./install-blog-scripts.sh
~/scripts/blog/blog-orchestrator.sh test-alert
```
