#!/bin/sh

#
#  ci_post_clone.sh
#  Xcode Cloud가 저장소 클론 직후, 빌드 전에 실행하는 스크립트.
#
#  FoodAPIConfig.swift는 보안을 위해 .gitignore 되어 저장소에 없으므로,
#  Xcode Cloud 시크릿 환경변수로부터 이 파일을 빌드 전에 생성한다.
#
#  서비스키에는 '%' 같은 특수문자가 있어 환경변수 값으로 직접 저장이 거부된다.
#  따라서 키를 16진수(hex)로 인코딩한 값을 FOOD_API_KEY_HEX 에 저장하고,
#  여기서 원래 문자열로 복원한다.
#

set -e

echo "ci_post_clone: 시작"
echo "CI_PRIMARY_REPOSITORY_PATH=${CI_PRIMARY_REPOSITORY_PATH}"
echo "FOOD_API_KEY_HEX 길이=${#FOOD_API_KEY_HEX}"

CONFIG_DIR="$CI_PRIMARY_REPOSITORY_PATH/carbculator"
CONFIG_PATH="$CONFIG_DIR/FoodAPIConfig.swift"

if [ -z "$FOOD_API_KEY_HEX" ]; then
    echo "error: FOOD_API_KEY_HEX 환경변수가 비어 있습니다."
    echo "       워크플로우 환경변수(이름: FOOD_API_KEY_HEX, Secret 체크)로 등록한 뒤 '새 빌드'를 실행하세요."
    exit 1
fi

# hex → 원래 서비스키 문자열로 복원
KEY=$(printf '%s' "$FOOD_API_KEY_HEX" | xxd -r -p)

if [ -z "$KEY" ]; then
    echo "error: hex 복원 결과가 비어 있습니다. FOOD_API_KEY_HEX 값(16진수)을 확인하세요."
    exit 1
fi

if [ ! -d "$CONFIG_DIR" ]; then
    echo "error: 대상 폴더가 없습니다: $CONFIG_DIR"
    ls -la "$CI_PRIMARY_REPOSITORY_PATH" || true
    exit 1
fi

cat > "$CONFIG_PATH" <<EOF
//  FoodAPIConfig.swift (Xcode Cloud에서 자동 생성 — 커밋되지 않음)
import Foundation

enum FoodAPIConfig {
    static let serviceKeyEncoded = "$KEY"
}
EOF

echo "✅ FoodAPIConfig.swift 생성 완료: $CONFIG_PATH"
