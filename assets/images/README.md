# Assets Images

## 해상도 가이드 이미지

이 폴더에는 Android 해상도 설정 가이드에 사용될 이미지들이 저장됩니다.

### 필요한 이미지:
1. `android_resolution_guide.png` - Android 해상도 설정 화면 이미지
   - 사용자가 업로드한 이미지를 이 이름으로 저장해주세요
   - 권장 크기: 최대 1080px 너비
   - 파일 형식: PNG (투명도 지원)

### 이미지 사용 위치:
- `lib/widgets/android_resolution_fix_dialog.dart` - 경고 다이얼로그에서 사용
- `lib/screens/android_resolution_guide_screen.dart` - 가이드 화면에서 참조

### 이미지 추가 방법:
1. 사용자 제공 이미지를 `android_resolution_guide.png` 이름으로 이 폴더에 저장
2. `pubspec.yaml`의 assets 섹션에 경로 추가 (이미 추가됨)
3. 앱 재빌드 후 이미지 표시 확인

### 참고사항:
- 이미지가 없어도 앱은 정상 동작합니다 (placeholder UI 표시)
- 향후 이미지 추가시 hot reload로 바로 적용 가능