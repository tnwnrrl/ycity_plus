# Xcode에서 직접 App Store 출시 가이드

## 1. Xcode 프로젝트 열기

```bash
# 터미널에서 실행
open /Users/jinhwanjeon/ycity_plus/ios/Runner.xcworkspace
```

**중요**: `.xcodeproj` 파일이 아닌 `.xcworkspace` 파일을 열어야 합니다!

## 2. 프로젝트 설정 확인

### 2.1 General 탭 설정
1. **Runner** 타겟 선택
2. **General** 탭으로 이동
3. 다음 설정들을 확인:
   - **Display Name**: `와이시티플러스` (이미 설정됨)
   - **Bundle Identifier**: `com.ilsan-ycity.ilsanycityplus` (이미 설정됨)
   - **Version**: `4.0.2` (이미 설정됨)
   - **Build**: Flutter에서 자동 설정
   - **Deployment Target**: `14.0` (이미 설정됨)

### 2.2 Signing & Capabilities 확인
1. **Signing & Capabilities** 탭으로 이동
2. 다음 설정들을 확인:
   - **Automatically manage signing**: ✅ 체크됨
   - **Team**: `372L6244K5` (이미 설정됨)
   - **Provisioning Profile**: Automatic

## 3. Archive 생성 및 업로드

### 3.1 Archive 생성
1. **Scheme 설정**:
   - 상단의 Scheme 선택기에서 `Runner` 선택
   - Device를 `Any iOS Device (arm64)` 또는 실제 iOS 기기로 설정

2. **Archive 생성**:
   - 메뉴: `Product` → `Archive`
   - 또는 단축키: `Cmd + Shift + B`

### 3.2 Organizer에서 업로드
Archive가 완료되면 자동으로 **Organizer** 창이 열립니다.

1. **Validate App** (선택사항):
   - `Validate App` 버튼 클릭
   - App Store Connect 업로드 전 검증

2. **Distribute App**:
   - `Distribute App` 버튼 클릭
   - **App Store Connect** 선택
   - **Upload** 선택
   - **Next** 계속 진행

### 3.3 Distribution Options
1. **App Store Connect distribution options**:
   - `Strip Swift symbols` ✅ (권장)
   - `Upload your app's symbols` ✅ (권장)
   - `Manage Version and Build Number` (자동 처리)

2. **Re-sign**:
   - Automatic signing 사용 (이미 설정됨)

3. **Review**:
   - 모든 설정 검토 후 **Upload** 클릭

## 4. App Store Connect에서 확인

업로드 완료 후 (보통 5-15분 소요):

1. [App Store Connect](https://appstoreconnect.apple.com) 접속
2. **My Apps** → **YCITY+** (또는 새 앱 생성)
3. **TestFlight** 탭에서 빌드 확인
4. **App Store** 탭에서 심사 제출

## 5. 문제 해결

### 5.1 일반적인 오류들

**코드사이닝 오류**:
```
- Team 설정 확인: 372L6244K5
- Apple ID 로그인 상태 확인
- Certificates 갱신 필요시 갱신
```

**Archive 실패**:
```
- Clean Build Folder: Cmd + Shift + K
- Derived Data 삭제: ~/Library/Developer/Xcode/DerivedData
- Flutter clean 실행 후 재시도
```

**업로드 실패**:
```
- 인터넷 연결 상태 확인
- Apple ID 2단계 인증 설정 확인
- App-specific password 필요시 생성
```

### 5.2 현재 프로젝트 특이사항

**Development Team 설정됨**: `372L6244K5`
- 이미 올바른 팀으로 설정되어 있음
- 추가 설정 불필요

**Display Name**: `와이시티플러스`
- Xcode에서 자동으로 설정됨
- App Store에 표시될 이름

**카테고리 설정됨**: `public.app-category.navigation`
- 내비게이션 카테고리로 설정됨
- App Store에서 적절한 카테고리로 표시

## 6. Xcode 단축키

```
Archive: Cmd + Shift + B
Clean: Cmd + Shift + K
Build: Cmd + B
Run: Cmd + R
```

## 7. 실행 순서 요약

1. **Xcode 열기**: `open ios/Runner.xcworkspace`
2. **Scheme 확인**: Runner, Any iOS Device
3. **Archive**: Product → Archive
4. **업로드**: Distribute App → App Store Connect
5. **확인**: App Store Connect에서 빌드 확인

---

## ⚠️ 주의사항

- **Flutter 앱**이므로 반드시 `.xcworkspace` 파일을 열어야 함
- **Archive 전**에 Clean Build 권장
- **업로드 후** App Store Connect에서 빌드 처리 완료까지 5-15분 소요
- **심사 제출**은 App Store Connect 웹사이트에서 진행

모든 설정이 완료되어 있으므로 바로 Archive → Upload 진행 가능합니다!