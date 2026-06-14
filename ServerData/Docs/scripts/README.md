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
| [docker/myapp/](./docker/myapp/) | whoami 테스트 앱 |
| [docker/nginx-proxy-manager/](./docker/nginx-proxy-manager/) | 리버스 프록시 |
| [docker/cloudflared/](./docker/cloudflared/) | Cloudflare Tunnel |

```bash
# 예: VM
mkdir -p ~/docker/myapp
scp .../scripts/docker/myapp/docker-compose.yml foxmong@192.168.0.113:~/docker/myapp/
```
