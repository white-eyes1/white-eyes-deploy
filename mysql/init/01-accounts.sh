#!/bin/sh
# 앱마다 DB 계정을 따로 만든다(conventions.md 'DB 계정'). MySQL 데이터 볼륨이 비어 있을 때 한 번만 돈다.
# 관리자 앱 계정: 전체 표 + Flyway(DDL). 사용자 앱 계정의 표 권한은 표가 생긴 뒤 db-grants 서비스가 준다.
set -eu
mysql --protocol=socket -uroot -p"$MYSQL_ROOT_PASSWORD" <<SQL
CREATE USER 'white_eyes_admin'@'%' IDENTIFIED BY '${ADMIN_DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${MYSQL_DATABASE}\`.* TO 'white_eyes_admin'@'%';
CREATE USER 'white_eyes_user'@'%' IDENTIFIED BY '${USER_DB_PASSWORD}';
SQL
