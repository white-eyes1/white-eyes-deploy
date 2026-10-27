# white-eyes-deploy

white-eyes 전체(사용자 앱·관리자 앱·분석 서버·nginx·MySQL)를 local에서 docker compose로 한 번에 띄운다.
명세: white-eyes-docs `overview.md` '서버 환경'(local: WSL + docker compose로 전부 한 번에 실행).
이미지는 각 서비스 저장소의 `Dockerfile`로 만든다(white-eyes-spring·white-eyes-flask 루트). 이 저장소에는 묶어 띄우는 설정만 둔다.

| 서비스 | 내용 | 바깥 포트 |
|---|---|---|
| nginx | 유일한 입구. 설정은 `nginx/`(경로 규칙의 원본은 docs conventions.md) | 80 |
| user | 사용자 앱(8080) | - |
| admin | 관리자 앱(웹 8081, 내부 API 8082). Flyway를 돌린다 | - |
| flask | 분석 서버(5000) | - |
| mysql | MySQL 8.4. 앱마다 DB 계정을 따로 둔다 | - |
| db-grants | 관리자 앱 Flyway 뒤에 사용자 앱 계정에 표 권한을 주고 끝난다 | - |

공유 스토리지(NFS)는 `./media` 폴더로 대신한다. 분석 서버는 쓰고 nginx는 읽기만 한다. 관리자 앱은 파일을 직접 읽지 않는다(`X-Accel-Redirect`).

## 준비
- WSL2(Ubuntu) 안의 Docker Engine + Compose v2. 저장소는 WSL 파일 시스템 안에 둔다(Windows 드라이브 쪽은 매우 느리다).
- 메모리: 모두 합쳐 약 2.5GB를 쓴다. WSL에 6GB 이상을 권한다(`.wslconfig`).
- 세 저장소를 한 폴더에 나란히 clone 한다. spring·flask는 `dev`(또는 공지한 시험 기준 커밋)를 체크아웃한다. 위치가 다르면 `.env`의 `SPRING_DIR`·`FLASK_DIR`로 준다.
  ```
  white-eyes/
  ├─ white-eyes-spring/
  ├─ white-eyes-flask/
  └─ white-eyes-deploy/   ← 이 저장소
  ```

## 처음 한 번
1. `cp .env.example .env` 후 값을 채운다. 값은 팀 메신저로 안내한다. **`.env`는 커밋하지 않고, 이슈·PR에 붙이지 않는다.**
2. 분석 모델 가중치를 `weights/`에 둔다. 받는 곳과 SHA-256은 white-eyes-flask README '가중치'(기본 `visdrone-yolov8m.pt`).
3. 더미 캠 영상(`.mp4`)을 `media/dummy/videos/`에 둔다. 비공개 white-eyes-assets 저장소의 Release에 있다(받는 곳은 메신저로 안내, **외부 공개 금지**). 캠을 등록할 때 주소는 `dummy/videos/<파일 이름>`이다.
4. 행정구역 경계: `./scripts/fetch-regions.sh`가 시연 지역(대전 중구·수원시영통구·김포시)만 잘라 `regions/regions.geojson`을 만든다(python3 필요).

## 실행
```bash
docker compose up -d --build              # 처음은 이미지 빌드로 10분 넘게 걸린다
docker compose ps                         # admin·user·flask가 healthy, db-grants가 Exited (0)
docker compose run --rm load-regions      # 행정구역 적재(처음 한 번)
```
- 사용자 앱 `http://localhost/`, 관리자 앱 `http://localhost/admin/`(`.env`의 최고 관리자로 로그인 → 첫 로그인에 비밀번호 변경)
- 시연용 통계: 관리자 화면에서 구역·캠을 등록하고 **가동한 뒤** `docker compose run --rm generate-demo`. 구역마다 첫 가동 시각 직전까지 1년 치 시간별·일별을 만든다(가동 전에 실행했다면 가동 뒤 한 번 더). 첫 가동 당일에 실행하면 그날 일별까지 시간별 합과 맞는다(지난 날이면 그날 하루만 다를 수 있음). 자세한 것은 spring `admin/demo/README.md`
  ```bash
  docker compose run --rm generate-demo                                        # 모든 구역, 기본 설정
  docker compose run --rm generate-demo --job=generate-demo --zone=1,2         # 1·2번 구역만 다시 만듦
  docker compose run --rm generate-demo --job=generate-demo --config=/demo/generate-demo.json  # 값 바꿀 때(spring 견본을 demo/로 복사해 고침)
  docker compose run --rm generate-demo --job=delete-demo                      # 시연용 데이터 지우기
  ```

## 앱 설정 바꾸기
임계값·보관 일수·분석 입력 크기처럼 앱이 읽는 설정은 `env/spring.env`(사용자·관리자 앱), `env/flask.env`(분석 서버)에 적는다. 없으면 앱 기본값을 쓴다. 쓸 수 있는 이름은 각 저장소의 `.env.example`이다. 주소·계정·토큰은 compose가 정하므로 여기에 적어도 바뀌지 않는다.
```bash
mkdir -p env && echo "THRESHOLD_WARN_DENSITY=0.5" >> env/spring.env
docker compose up -d admin user           # 설정만 바꿨으면 --build 없이 다시 만든다
```

## 개발할 때(앱을 bootRun·IDE로 띄움)
MySQL만 여기서 띄우고, 앱은 각 저장소에서 띄운다. DB 계정은 명세대로 앱마다 다르다(관리자 앱 `white_eyes_admin`, 사용자 앱 `white_eyes_user`).
```bash
docker compose up -d mysql                # 127.0.0.1:3306(.env의 MYSQL_PORT)
# 관리자 앱을 띄워 Flyway가 표를 만든 뒤, 사용자 앱 계정에 표 권한을 준다
docker compose run --rm --no-deps db-grants
```
- 새 표를 만드는 마이그레이션 뒤에도 `db-grants`를 다시 돌린다. 안 돌리면 사용자 앱이 그 표에서 권한 오류(`command denied`)로 멈춘다.
- 앱 실행 방법은 white-eyes-spring CLAUDE.md '명령'.

## 자주 쓰는 명령
```bash
docker compose logs -f admin flask        # 로그 보기(이슈에 붙일 때는 비밀값이 없는지 확인)
git -C ../white-eyes-spring rev-parse --short HEAD   # 시험한 커밋 확인
docker compose up -d --build admin user   # 옆 저장소를 바꾼 뒤 그 서비스만 다시 만든다
docker compose down                       # 멈춤(데이터 유지)
docker compose down -v                    # DB·분석 서버 캐시까지 지움. 다음 up에서 DB 계정을 다시 만든다
```

## 구성 메모
- nginx: 설정과 확인 스크립트는 `nginx/README.md`. 서버 주소는 `nginx/upstreams.conf`, 내부 토큰은 시작할 때 `.env`의 `INTERNAL_API_TOKEN`으로 만든다.
- DB 계정(conventions.md 'DB 계정'): 관리자 앱 계정은 전체 권한. 사용자 앱 계정은 `admin_account`·`SPRING_SESSION_ADMIN`(+속성 표)·`flyway_schema_history`를 뺀 표의 SELECT·INSERT·UPDATE·DELETE만 갖는다. MySQL은 "이 표만 빼고"를 줄 수 없어서 `db-grants`가 표마다 준다.
- `.env`의 DB 비밀번호는 MySQL 볼륨을 처음 만들 때만 적용된다. 바꾸려면 `down -v`.
- MySQL은 `127.0.0.1`로만 열어 다른 컴퓨터에서는 붙을 수 없다. 3306을 이미 쓰고 있으면 `up`이 `port is already allocated`로 멈춘다. `.env`에 `MYSQL_PORT=3307`처럼 바꾼다(white-eyes-spring troubleshooting 0019).
- 디버깅으로 앱 포트를 직접 열려면 `compose.override.yml`에 `ports`를 더한다(커밋하지 않는다).
