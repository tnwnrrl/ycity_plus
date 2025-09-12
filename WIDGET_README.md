# YCITY+ 홈화면 위젯 가이드

YCITY+ 앱용 홈화면 위젯으로 파싱된 층 정보를 간단하게 표시합니다.

## 기능

- 파싱된 층 정보만 텍스트로 표시 (예: "B1", "B2 B4", "층 정보 없음")
- 간단하고 깔끔한 디자인 (흰색 배경, 검은색 텍스트)
- 위젯 터치시 메인 앱 실행
- 메인 앱에서 층 정보 파싱할 때마다 자동 업데이트

## Android 위젯

### 설정 파일들

- `android/app/src/main/kotlin/com/example/ycity_plus/FloorInfoWidget.kt` - AppWidgetProvider 구현
- `android/app/src/main/res/layout/floor_info_widget.xml` - 위젯 레이아웃
- `android/app/src/main/res/xml/floor_info_widget_info.xml` - 위젯 설정
- `android/app/src/main/res/drawable/widget_background.xml` - 위젯 배경
- `android/app/src/main/AndroidManifest.xml` - 위젯 등록

### 크기 및 스타일

- 권장 크기: 4x1 (가로형)
- 최소 크기: 250dp x 40dp
- 리사이즈 가능: 가로/세로 모두
- 업데이트 주기: 30분

### 사용법

1. 홈화면에서 길게 눌러 위젯 메뉴 접근
2. "YCITY+ 층 정보" 위젯 선택
3. 홈화면에 배치
4. 메인 앱에서 차량 위치 조회시 자동 업데이트

## iOS 위젯

### 설정 파일들

- `ios/FloorInfoWidget/FloorInfoWidget.swift` - WidgetKit 구현
- `ios/FloorInfoWidget/Info.plist` - 위젯 정보
- `ios/Runner/Runner.entitlements` - App Group 설정
- `ios/Runner/AppDelegate.swift` - 메소드 채널 처리

### 크기 및 스타일

- 지원 크기: Small (2x2)
- 업데이트 주기: 30분
- 시스템 색상 테마 지원 (라이트/다크 모드)

### 사용법

1. 홈화면에서 길게 눌러 위젯 추가 모드 진입
2. "+" 버튼 터치
3. "YCITY+ 층 정보" 검색 및 선택
4. Small 크기 선택 후 "위젯 추가"
5. 메인 앱에서 차량 위치 조회시 자동 업데이트

## Flutter 통합

### 핵심 서비스

- `lib/services/widget_service.dart` - 위젯 데이터 관리 및 업데이트
- `lib/widgets/widget_demo_page.dart` - 위젯 테스트 페이지 (디버그 모드)

### 데이터 저장

- **Android**: SharedPreferences (`FlutterSharedPreferences`)
- **iOS**: UserDefaults with App Group (`group.com.example.ycity_plus.widget`)

### 자동 업데이트

메인 앱의 `_updateLocationInfo()` 메소드에서 층 정보 파싱 완료시 자동으로 위젯 업데이트:

```dart
// Update widget with floor information
await _widgetService.updateWidget(floorInfo);
```

## 테스트 방법

1. 디버그 모드에서 앱 실행
2. 홈화면에서 "위젯 테스트" 버튼 터치
3. 각종 층 정보로 위젯 업데이트 테스트
4. 홈화면에서 위젯 변화 확인

## 빌드 요구사항

### Android

- Android API 21+ (Android 5.0)
- Kotlin 지원

### iOS

- iOS 14.0+ (WidgetKit 요구사항)
- Xcode 12+
- SwiftUI 지원

## 알려진 제한사항

1. 위젯은 단순 텍스트 표시만 지원 (색상 구분 없음)
2. 실시간 업데이트가 아닌 앱 실행시에만 업데이트
3. iOS는 시스템 정책에 따라 위젯 업데이트 제한 가능
4. Android 위젯은 사용자가 직접 홈화면에 추가해야 함

## 향후 개선 사항

- [ ] 위젯에서 층별 색상 표시
- [ ] 더 다양한 위젯 크기 지원
- [ ] 위젯 설정 화면 추가
- [ ] 백그라운드 자동 업데이트
- [ ] 위젯 터치시 특정 화면으로 바로 이동

## 트러블슈팅

### Android

- 위젯이 업데이트되지 않는 경우: 앱을 재시작하고 차량 위치를 다시 조회
- 위젯이 표시되지 않는 경우: 홈화면에서 위젯을 다시 추가

### iOS

- 위젯이 업데이트되지 않는 경우: 설정 > 배터리 > 배터리 최적화에서 앱 제외
- App Group 오류: 개발자 계정에서 App Group 기능 활성화 필요