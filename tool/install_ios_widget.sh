#!/usr/bin/env bash
# Xcode 에서 MoneyWidget 타깃을 만든 뒤 실행: 위젯 코드를 ios/MoneyWidget/ 에 덮어쓴다.
set -euo pipefail
cd "$(dirname "$0")/.."

DEST=ios/MoneyWidget
if [ ! -d "$DEST" ]; then
  echo "ios/MoneyWidget 폴더가 없어요."
  echo "Xcode 에서 File > New > Target > Widget Extension 으로 이름을 'MoneyWidget' 으로 먼저 만들어 주세요."
  exit 1
fi

cp ios_widget/MoneyWidget.swift "$DEST/MoneyWidget.swift"
cp ios_widget/MoneyWidgetBundle.swift "$DEST/MoneyWidgetBundle.swift"
cp ios_widget/PrivacyInfo.xcprivacy "$DEST/PrivacyInfo.xcprivacy"
# Xcode 가 만든 예시 파일은 지운다 (같은 이름의 위젯이 두 번 생기지 않게)
rm -f "$DEST/MoneyWidgetLiveActivity.swift" "$DEST/MoneyWidgetControl.swift" "$DEST/AppIntent.swift"
echo "위젯 코드를 $DEST 에 복사했어요."
