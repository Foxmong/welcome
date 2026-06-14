# 맥미니 서버 구축 작업 일지

> **새 세션:** [../00-HOME-SERVER-HANDOFF.md](../00-HOME-SERVER-HANDOFF.md) 먼저 읽기

이 폴더에는 맥미니 홈서버 구축·운영 과정에서 진행한 작업을 날짜별로 기록합니다.

## 파일 목록

| 파일 | 날짜 | 내용 |
|---|---|---|
| [2026-06-11-macmini-server-setup.md](./2026-06-11-macmini-server-setup.md) | 2026-06-11 | 저장장치 구성, Tailscale, SSH, SMB, CentOS VM 설치까지 |
| [2026-06-12-macmini-server-setup.md](./2026-06-12-macmini-server-setup.md) | 2026-06-12 | Guest Additions 실패→SSHFS, ServerData 마운트, ARM64 한계, 다음 단계 |
| [2026-06-14-macmini-server-setup.md](./2026-06-14-macmini-server-setup.md) | 2026-06-14 | Docker, Kuma, restic, 운영 안정화 완료 |

## 관련 가이드

| 파일 | 내용 |
|---|---|
| [../guides/tailscale-sftp-file-transfer.md](../guides/tailscale-sftp-file-transfer.md) | Tailscale + SFTP 파일 이동, 명령어, 세팅 |
| [../guides/vm-sshfs-automount.md](../guides/vm-sshfs-automount.md) | SSHFS 자동 마운트 |
| [../guides/app-server-docker-compose.md](../guides/app-server-docker-compose.md) | 앱 서버 |
| [../guides/cloudflare-tunnel.md](../guides/cloudflare-tunnel.md) | Cloudflare Tunnel |

## 맥미니 실제 경로

```text
/Volumes/ServerData/Docs/setup-logs/
/Volumes/ServerData/Docs/guides/
```
