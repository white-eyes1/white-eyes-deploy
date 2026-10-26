#!/bin/bash
# 행정구역 경계 파일(FNC-A-012)을 받아 시연 지역만 잘라 regions/regions.geojson으로 둔다.
# 출처: vuski/admdongkor ver20261001(통계청 SGIS 기반, 데이터 CC BY 4.0). decisions/0014의 잠정 후보다.
# 인자로 시·군·구 코드(5자리)를 주면 그 지역만 자른다. 없으면 시연 지역: 대전 중구 25020, 수원시영통구 31014, 김포시 31230
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p regions
url=https://raw.githubusercontent.com/vuski/admdongkor/master/ver20261001/HangJeongDong_ver20261001.geojson
[ -f regions/all.geojson ] || curl -fL -o regions/all.geojson "$url"
codes=("$@")
[ ${#codes[@]} -gt 0 ] || codes=(25020 31014 31230)
python3 - "${codes[@]}" <<'PY'
import json, sys
codes = sys.argv[1:]
with open("regions/all.geojson", encoding="utf-8") as f:
    data = json.load(f)
data["features"] = [x for x in data["features"] if str(x["properties"]["adm_cd"])[:5] in codes]
with open("regions/regions.geojson", "w", encoding="utf-8") as f:
    json.dump(data, f, ensure_ascii=False)
print(f"regions/regions.geojson: 읍·면·동 {len(data['features'])}개 ({', '.join(codes)})")
PY
