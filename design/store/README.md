# 스토어 그림

- `screenshots/` App Store: `iphone-0N` (6.9형 1320x2868) · `iphone65-0N` (6.5형 1284x2778) · `ipad-0N` (13형 2064x2752)
- `iap-review-1320x2868.png`: 인앱 구입(PRO) 심사용 스크린샷
- `../play/` Google Play: `play-0N` (폰 1080x1920) · `feature-1024x500` (대표 이미지) · `icon-512`

다시 만들기 (playwright 필요):

```bash
mkdir -p fonts   # JetBrainsMono · NanumGothicCoding (assets/fonts) + NotoSansKR.ttf 를 넣는다
node render.js   # → out/ 스크린샷 + 심사용 PRO 화면
node feature.js  # → out/feature-1024x500.png
```

5번(위젯)은 PRO 기능이라 Google Play 에서는 빼도 돼요 (안드로이드에는 위젯이 없음).
