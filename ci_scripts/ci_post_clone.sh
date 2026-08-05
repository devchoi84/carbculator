#!/bin/sh

#
#  ci_post_clone.sh
#  Xcode Cloud가 저장소 클론 직후, 빌드 전에 실행하는 스크립트.
#
#  FoodAPIConfig.swift는 보안을 위해 .gitignore 되어 저장소에 없으므로,
#  Xcode Cloud 워크플로우의 시크릿 환경변수 FOOD_API_KEY 값으로 이 파일을 생성한다.
#

set -e

# 생성 위치: 클론된 저장소의 앱 소스 폴더
CONFIG_PATH="$CI_PRIMARY_REPOSITORY_PATH/carbculator/FoodAPIConfig.swift"

if [ -z "$FOOD_API_KEY" ]; then
    echo "error: FOOD_API_KEY 환경변수가 설정되지 않았습니다. Xcode Cloud 워크플로우 환경변수를 확인하세요."
    exit 1
fi

cat > "$CONFIG_PATH" <<EOF
//  FoodAPIConfig.swift (Xcode Cloud에서 자동 생성 — 커밋되지 않음)
import Foundation

enum FoodAPIConfig {
    static let serviceKeyEncoded = "$FOOD_API_KEY"
}
EOF

echo "✅ FoodAPIConfig.swift 생성 완료: $CONFIG_PATH"
