# money.exe

한 줄 명령어로 쓰는 터미널 가계부. .exe 시리즈 (todo.exe · diary.exe · ink.exe · camera.exe) 다섯 번째 앱.

```
C:\money> -4500 커피
✓ 4,500원 기록 · #카페 · 여유 92,400원
```

- **예산 = 디스크 용량**: 이번 달 예산이 `로컬 디스크 (C:)` 막대로 보인다. 80% 넘으면 노랑, 넘기면 빨강 + "디스크 공간 부족" 창.
- **명령어 입력**: 금액과 메모 순서 자유, `1.2만` · `3천원` 도 OK. 태그는 메모를 보고 자동 (#카페 #식비 #교통 …).
- **영수증 출력**: `print` 로 그 달 내역이 영수증처럼 한 줄씩 출력. PNG 저장 · 공유.
- `stats`: 태그별 사용량(폴더 크기처럼) + 최근 6개월.
- 기록은 폰 안에만 저장 (서버 없음, 데이터 수집 없음).

## 명령어

| 명령어 | 설명 |
| --- | --- |
| `-4500 커피` / `커피 4500 #카페` | 지출 기록 |
| `budget 700000` | 한 달 예산 (0 이면 끔). 디스크 아래에 "이번 주 여유"도 보여준다 |
| `budget 15만 /week` | 주간 예산: 매주 월요일에 디스크가 다시 빈다 (`/month` 로 되돌리기) |
| `dir` | 이번 달 디스크 · 기록 |
| `stats [달]` | 태그별 · 최근 6개월 |
| `print [달]` | 영수증 출력 (`print 9`, `print 2026.09`) |
| `undo` | 마지막 기록 지우기 |
| `cls` | 화면 로그 지우기 |

## 빌드 (Mac)

```bash
git pull
bash tool/setup_platforms.sh      # android/ ios/ 폴더 만들기 + 아이콘 (처음 한 번, 여러 번 돌려도 안전)
flutter build ipa                 # App Store
flutter build appbundle           # Google Play
```

- iOS 번들 ID: `com.isla0x.moneyExe` · Android 패키지: `com.isla0x.money_exe`
- Android 서명은 camera.exe 와 같은 `~/.isla0x/android-upload.properties` 를 쓴다 (저장소에 절대 넣지 않음).
- GitHub Actions 가 push 마다 analyze · test · APK · iOS(서명 없이) 빌드를 확인한다.

아이콘 원본: `design/icons/e-mono-cursor.svg` (안드로이드 전경: `fg.svg`)
