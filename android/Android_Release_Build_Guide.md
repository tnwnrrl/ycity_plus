# Android Google Play Store 출시 가이드

## 현재 상태
✅ **출시 준비 완료**:
- **패키지명**: com.ilsan_ycity.ilsanycityplus
- **버전**: 4.0.2 (빌드: 1)
- **키스토어**: upload-keystore.jks 생성 완료
- **앱 서명**: Release 빌드 설정 완료
- **ProGuard**: 난독화 및 최적화 설정 완료

## AAB (Android App Bundle) 빌드

### 릴리즈 AAB 빌드 명령어
```bash
# 1. 프로젝트 클린
flutter clean

# 2. 의존성 다시 설치
flutter pub get

# 3. AAB 빌드 (권장)
flutter build appbundle --release

# 또는 APK 빌드 (구버전 호환)
flutter build apk --release
```

### 빌드 결과 위치
- **AAB**: `build/app/outputs/bundle/release/app-release.aab`
- **APK**: `build/app/outputs/flutter-apk/app-release.apk`

## Google Play Console 업로드

### 1. Google Play Console 접속
1. [Google Play Console](https://play.google.com/console) 접속
2. **앱 만들기** 또는 기존 앱 선택

### 2. 앱 기본 정보 설정
```
앱 이름: YCITY+
기본 언어: 한국어
앱 또는 게임: 앱
무료 또는 유료: 무료
```

### 3. 스토어 설정 → 기본 스토어 등록 정보
- **앱 이름**: YCITY+
- **짧은 설명**: 일산 YCITY 주차장에서 내 차량의 위치를 쉽고 빠르게 확인하는 앱
- **전체 설명**: (Google_Play_Store_Metadata.md 참조)

### 4. 그래픽 에셋 업로드
- **앱 아이콘**: 자동으로 AAB에서 추출
- **피처드 그래픽**: 1024 x 500 픽셀 (제작 필요)
- **스크린샷**: 최소 2장 (촬영 필요)

### 5. 앱 콘텐츠 설정
- **개인정보 처리방침**: URL 입력 (제작 필요)
- **앱 카테고리**: 도구
- **연락처 세부정보**: 이메일 주소 입력

### 6. 콘텐츠 등급
- **설문지 작성**: 모든 항목 "아니요" 선택
- **예상 등급**: 전체 이용가

### 7. 타겟 고객 및 콘텐츠
- **타겟 연령**: 18세 이상 성인만 대상
- **전체 이용가 앱**: 예

## 출시 설정

### 1. 프로덕션 → 새 출시 만들기
1. **앱 번들 업로드**: app-release.aab 파일 드래그 앤 드롭
2. **출시 이름**: 4.0.2 (첫 번째 출시)
3. **출시 노트**: 
```
• 일산 YCITY 주민을 위한 주차 위치 확인 서비스
• 실시간 차량 위치 조회 기능
• 간편한 사용법과 직관적인 UI
• 보안 강화 및 성능 최적화
```

### 2. 국가/지역 및 기기
- **국가/지역**: 대한민국 선택
- **기기 호환성**: 자동 설정 (휴대폰, 태블릿)

### 3. 가격 및 배포
- **앱 가격**: 무료
- **국가별 이용 가능성**: 대한민국만

## 키스토어 관리

### 현재 키스토어 정보
```
파일: android/app/upload-keystore.jks
별칭(Alias): upload
스토어 비밀번호: android
키 비밀번호: android
유효기간: 10,000일
```

### ⚠️ 중요사항
- **키스토어 파일 백업 필수**: 분실 시 앱 업데이트 불가
- **비밀번호 안전 보관**: 복구 불가능
- **Play App Signing 권장**: Google에서 키 관리

## 출시 프로세스

### 1. 내부 테스트 (선택사항)
```bash
# 테스트 그룹 생성
# AAB 업로드
# 테스터 초대 및 테스트
```

### 2. 프로덕션 출시
1. **출시 검토**: 모든 설정 확인
2. **출시 시작**: "프로덕션으로 출시" 클릭
3. **심사 대기**: 최대 7일 소요

### 3. 출시 후 모니터링
- **충돌 보고서**: Play Console에서 모니터링
- **사용자 리뷰**: 정기적 확인 및 답변
- **성능 지표**: 설치 및 이탈률 분석

## 문제 해결

### 일반적인 오류들

**키스토어 오류**:
```
Keystore was tampered with, or password was incorrect
→ 비밀번호 확인: android
```

**업로드 실패**:
```
Upload failed: You need to use a different version code
→ pubspec.yaml에서 version: 4.0.2+2로 변경
```

**서명 오류**:
```
App not signed or signed incorrectly
→ gradle 설정의 signingConfigs 확인
```

### AAB vs APK
- **AAB 권장**: Google Play에서 최적화된 APK 생성
- **APK**: 직접 배포 또는 다른 스토어용

## 업데이트 출시

### 버전 업데이트 방법
1. **pubspec.yaml** 버전 증가:
```yaml
version: 4.0.3+3  # 4.0.3 버전, 빌드 번호 3
```

2. **새 AAB 빌드**:
```bash
flutter build appbundle --release
```

3. **Play Console 업로드**:
- 프로덕션 → 새 출시 만들기
- 새 AAB 파일 업로드
- 출시 노트 작성 후 출시

## 즉시 실행 가능한 다음 단계

1. **AAB 빌드**: `flutter build appbundle --release`
2. **Google Play Console** 앱 등록
3. **스크린샷 촬영** (Android 에뮬레이터)
4. **개인정보 처리방침** 페이지 제작
5. **AAB 업로드** 및 출시 신청

---

## 📋 출시 체크리스트

### 기술적 준비
- [x] 키스토어 생성 완료
- [x] 앱 서명 설정 완료
- [x] ProGuard 설정 완료
- [x] 패키지명 설정 완료

### 콘텐츠 준비
- [x] 앱 설명 작성 완료
- [x] 앱 아이콘 설정 완료
- [ ] 피처드 그래픽 제작
- [ ] 스크린샷 촬영

### 정책 준비
- [ ] 개인정보 처리방침 작성
- [ ] 개발자 연락처 등록
- [ ] 콘텐츠 등급 설문 완료

모든 기술적 설정이 완료되어 있으므로 바로 AAB 빌드 후 Google Play Console에 업로드할 수 있습니다!