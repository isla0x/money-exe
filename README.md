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
| `mode dark` / `mode light` / `mode auto` | 화면 밝기 (auto 는 폰 설정을 따름, 위젯도 같이) |

## PRO (아이폰, 한 번 결제)

| 무료 | PRO |
|---|---|
| 기록 · 예산 · 영수증 · 통계 전부 | 홈 화면 위젯(작게 · 중간), 잠금화면 위젯(직사각형 · 원형 · 한 줄), 위젯 누르면 바로 입력 |

- 상품 ID: `money_exe_pro` (비소모성 / Non-Consumable). 안드로이드에는 PRO 메뉴가 안 보여요 (위젯이 아이폰 전용).
- 명령어: `upgrade`(구매 화면), `restore`(구매 복원). 제목줄 `PRO` 링크로도 열 수 있어요.
- PRO 가 아니면 위젯은 `Access is denied.` 잠금 화면을 보여줘요.
- 디버그 빌드에서만 `pro --dev` 로 결제 없이 PRO 를 켜고 끌 수 있어요.

### 스토어에 상품 등록
- **App Store Connect** → 앱 → 수익화 → 앱 내 구입 → `+` → **비소모성**, 제품 ID `money_exe_pro`, 가격, 한국어 표시 이름/설명, 심사용 스크린샷(PRO 화면)
- 첫 인앱 구입은 **앱 버전과 함께 심사 제출**해야 해요.

## iOS 위젯

| 위치 | 크기 | 내용 |
|---|---|---|
| 홈 화면 | 작게 | 디스크 막대 + 사용 % + 여유 + 하루 쓸 돈 |
| 홈 화면 | 중간 | 위 내용 + 최근 기록 3줄 + `C:\money> █` |
| 잠금화면 | 직사각형 | `C:\money> 87%` + 여유 + 하루 |
| 잠금화면 | 원형 | 사용 % 게이지 |
| 잠금화면 | 시계 위 한 줄 | `>_ 여유 92,400원 · 하루 13,200원` |

위젯을 누르면 앱이 입력칸을 연 채로 켜져요. 날짜가 바뀌면 위젯이 스스로 남은 날 · 하루 쓸 돈을 다시 계산하고, 달(주)이 끝나면 빈 디스크로 바뀌어요.

### 처음 한 번 설정 (Xcode, iOS 17 이상)

1. `bash tool/setup_platforms.sh` 를 한 번 돌린 뒤 `open ios/Runner.xcworkspace`
2. **File → New → Target… → Widget Extension**
   - Product Name: `MoneyWidget`
   - Include Live Activity / Control / Configuration App Intent: **모두 체크 해제**
   - Finish → "Activate scheme?" 은 **Cancel** (Runner 로 계속 실행)
3. 왼쪽에서 **MoneyWidget** 타깃 → General → **Minimum Deployments 를 17.0** 으로
4. **Runner** 타깃 → Signing & Capabilities → **+ Capability → App Groups** → `+` → `group.com.isla0x.moneyexe`
5. **MoneyWidget** 타깃도 4번과 똑같이 (같은 그룹 체크). Team 도 Runner 와 같게.
6. 터미널에서 `bash tool/install_ios_widget.sh` (위젯 코드 덮어쓰기)
7. Runner 선택 후 ▶︎ 실행 → 앱에서 `pro --dev` (디버그 실행일 때만) → 홈 화면 길게 누르기 → 편집 → 위젯 추가 → **money.exe**

설정한 `ios/` 폴더는 커밋해 두세요: `git add ios && git commit -m "iOS 위젯 타깃" && git push`

**막힐 때**
- `Cycle inside Runner` 빌드 오류: Runner 타깃 → Build Phases 에서 **Embed Foundation Extensions** 를 **Run Script / Thin Binary 위로** 끌어올리기
- 위젯에 숫자가 안 나옴: 두 타깃의 App Group 이름이 정확히 같은지 확인하고 앱을 한 번 열기

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
