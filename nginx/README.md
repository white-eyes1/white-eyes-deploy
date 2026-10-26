# nginx 설정 (웹 서버)

외부에서 접근할 수 있는 유일한 입구(포트 80)의 설정이다. 규칙의 원본은 white-eyes-docs `conventions.md` '프록시·nginx 경로 규칙'이고, 이 폴더는 그 규칙을 그대로 옮긴 것이다. 규칙을 바꾸려면 명세를 먼저 고친다.
2026-10-26에 white-eyes-spring `deploy/nginx`에서 이 저장소로 옮겼다(그 전 이력은 spring 저장소에 있다).

| 파일 | 역할 |
|---|---|
| `nginx.conf` | 전체 설정. 환경마다 고치지 않는다 |
| `upstreams.conf` | 서버 주소(user 8080, admin 8081, 분석 서버 5000). compose 서비스 이름을 쓴다. 다른 환경에서는 이 파일만 주소를 바꿔 `/etc/nginx/upstreams.conf`로 둔다 |
| `proxy.inc` | 앱·분석 서버로 전달하는 모든 위치의 공통 헤더(`Host`, `X-Forwarded-*`). 위치에 `proxy_set_header`가 하나라도 있으면 바깥 설정의 헤더를 물려받지 못해서 파일로 모아 위치마다 include 한다 |
| `sse.inc` | SSE 위치 공통(`proxy_buffering off`, `proxy_read_timeout 1h`) |
| `templates/internal-token.conf.template` | 분석 서버로 보낼 `X-Internal-Token` 값. nginx 이미지가 시작할 때 `.env`의 `INTERNAL_API_TOKEN`으로 채워 `/etc/nginx/internal-token.conf`를 만든다. **값이 든 파일은 저장소에 올리지 않는다** |
| `verify/` | 가짜 앱으로 이 설정을 확인하는 스크립트(아래) |

## 두는 곳
`nginx.conf`·`proxy.inc`·`sse.inc`·`upstreams.conf`·`internal-token.conf`는 같은 폴더(`/etc/nginx/`)에 둔다. 영상·좌표 파일이 있는 공유 스토리지는 `/srv/media`에 **읽기 전용**으로 마운트한다. compose(`../compose.yml`)가 이렇게 마운트한다.

## 무엇을 하는가
| 경로 | 동작 |
|---|---|
| `/` · `/admin/` | 사용자 앱(8080) · 관리자 앱(8081)으로 전달 |
| `/admin/live/{cameraId}`, `/admin/live/{cameraId}/snapshot` | `auth_request`로 관리자 앱 `GET /admin/api/v1/live/auth?cameraId=`를 확인해 204일 때만 분석 서버 `/analyzer/v1/cameras/{cameraId}/live`·`/snapshot`으로 전달. `X-Internal-Token`을 붙이고(클라이언트가 보낸 값은 덮어씀), 스트림은 `proxy_buffering off`, 미리보기는 `Cache-Control: no-store` |
| 위 두 경로의 카메라 번호 | 권한을 확인한 번호와 분석 서버로 보낼 번호가 다르면(예: `/admin/live/1/../2/snapshot`) 403으로 막는다 |
| `/api/v1/stats/stream`, `/admin/api/v1/stats/stream`, `/admin/api/v1/notifications/stream` | SSE. 정확히 일치하는 위치, `proxy_buffering off`, `proxy_read_timeout 1h`, `Connection` 비움 |
| `/protected/media/` | `internal`, `alias /srv/media/`. 관리자 앱이 `X-Accel-Redirect`로 지정할 때만 전송, Range 지원. 브라우저가 직접 입력하면 404 |
| `/protected/media/**/*.json.gz` | `Content-Type: application/json`, `Content-Encoding: gzip` |
| `/internal/`, `/admin/internal/` | 404 |

## 확인하는 법
WSL Docker에서 `sh nginx/verify/run.sh`를 실행한다(compose의 nginx가 80을 쓰고 있으면 `docker compose stop nginx` 먼저). nginx:alpine 컨테이너에 이 설정을 올리고, 가짜 user·admin 앱과 분석 서버(`verify/fakes.py`)를 이 컴퓨터에 띄워 위 표를 하나씩 확인한 뒤 컨테이너를 지운다. 서버 주소는 `upstreams.conf`의 서비스 이름을 `127.0.0.1`로 바꿔 쓴다.

확인하는 것: 문법(`nginx -t`), 경로 분배와 프록시 헤더, 내부 경로 404, 라이브 권한(쿠키 없음 401·권한 없음 403·통과 200, 분석 서버가 받은 토큰, 비튼 주소 차단), 스트림·SSE가 모이지 않고 바로 나오는지, `X-Accel-Redirect`·Range 206·직접 접근 404, 좌표 파일 헤더(`Content-Encoding` 1개). 가짜 앱의 응답 규칙은 `fakes.py` 위쪽을 본다(실제 앱 규칙은 FNC-A-041·044 명세).

- 3번의 잘못된 캠 번호(`abc`)는 가짜 관리자 앱이 `/admin/...`에 모두 200을 주므로 200으로 나온다. 실제 관리자 앱에서는 404다.
