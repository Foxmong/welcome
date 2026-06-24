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
| [blog/setup-blog-wizard.sh](./blog/setup-blog-wizard.sh) | blog.env 마법사 |
| [blog/install-blog-launchd.sh](./blog/install-blog-launchd.sh) | launchd 자동 등록 |
| [blog/openrouter-call.sh](./blog/openrouter-call.sh) | LLM 호출 (예산·캐시) |
| [blog/llm-budget.sh](./blog/llm-budget.sh) | 일일 LLM 상한 |
| [blog/content-dedup.sh](./blog/content-dedup.sh) | 중복 필터 (LLM 전) |
| [blog/telegram-approval.sh](./blog/telegram-approval.sh) | 승인 요청 |
| [blog/telegram-callback-poller.sh](./blog/telegram-callback-poller.sh) | 승인 버튼 폴링 |
| [blog/tistory-cookie-check.sh](./blog/tistory-cookie-check.sh) | 쿠키 자동 검사 |
| [blog/deal-template-render.sh](./blog/deal-template-render.sh) | 핫딜 템플릿 (비용 절약) |

가이드: [../guides/blog-automation-openclaw-openrouter.md](../guides/blog-automation-openclaw-openrouter.md) Phase 4-B

```bash
# 예: 맥미니 (순서대로)
cd /Volumes/ServerData/Docs/scripts/blog
./setup-blog-wizard.sh
./install-blog-scripts.sh
~/scripts/blog/blog-orchestrator.sh test-alert
./install-blog-launchd.sh
```
