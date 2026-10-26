#!/bin/sh
# 사용자 앱 계정에 표마다 데이터 권한(DML)을 준다. 관리자 앱 Flyway가 표를 만든 뒤에 돈다.
# 명세(conventions.md 'DB 계정'): 사용자 앱 계정은 admin_account·SPRING_SESSION_ADMIN 권한 없음, DDL 권한 없음.
# MySQL은 "이 표만 빼고"를 줄 수 없어서 나머지 표를 하나씩 준다. 세션 속성 표와 Flyway 기록 표도 뺀다.
set -eu
db="$MYSQL_DATABASE"
tables=$(mysql -h mysql -uroot -N -e "
  SELECT table_name FROM information_schema.tables
  WHERE table_schema = '$db'
    AND table_name NOT IN ('admin_account', 'SPRING_SESSION_ADMIN', 'SPRING_SESSION_ADMIN_ATTRIBUTES', 'flyway_schema_history')")
count=0
for t in $tables; do
  mysql -h mysql -uroot -e "GRANT SELECT, INSERT, UPDATE, DELETE ON \`$db\`.\`$t\` TO 'white_eyes_user'@'%'"
  count=$((count + 1))
done
echo "white_eyes_user: 표 ${count}개 권한"
