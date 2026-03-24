# onychomonitor

유조동물(Onychophora, velvet worm)을 주기적으로 촬영하여 행동과 상태 변화를 모니터링하는 시스템. Raspberry Pi 카메라로 1분마다 사진을 촬영하고 NFS 공유 스토리지에 저장한다.

## 구성

```
/srv/onychomonitor/           # 운영 디렉토리
├── capture.sh                # 촬영 스크립트
├── capture.log               # 실행 로그
└── tmp_pictures/             # NFS 장애 시 임시 저장소

/nfs/share/onychomonitor/
└── pictures/                 # 촬영 이미지 저장소
```

## 촬영 흐름

1. `rpicam-still`로 촬영 → `/tmp`(tmpfs)에 임시 저장
2. NFS 마운트 확인
   - **마운트 정상**: `tmp_pictures/`에 밀린 사진이 있으면 일괄 전송 후 현재 촬영분도 NFS로 이동
   - **마운트 안 됨 / 이동 실패**: `/srv/onychomonitor/tmp_pictures/`에 로컬 보관

## 파일명 형식

```
YYYYMMDD-HHMMSS.jpg
```

## cron

```
* * * * * /srv/onychomonitor/capture.sh
```

## 로그

`/srv/onychomonitor/capture.log`에 기록되며 레벨은 다음과 같다.

| 레벨 | 의미 |
|------|------|
| `[OK]` | 촬영 및 NFS 전송 성공 |
| `[OK] flushed` | 밀린 사진 NFS 전송 성공 |
| `[WARN]` | NFS 미마운트로 로컬 저장 |
| `[ERROR]` | 촬영 실패 또는 파일 이동 실패 |

## 요구사항

- Raspberry Pi + 카메라 모듈
- `rpicam-still` (libcamera)
- NFS 마운트: `/nfs/share`
