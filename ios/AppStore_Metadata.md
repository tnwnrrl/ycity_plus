# YCITY+ iOS App Store 출시 정보

## 앱 기본 정보
- **앱 이름**: YCITY+
- **번들 ID**: com.ilsan-ycity.ilsanycityplus
- **버전**: 1.0.0
- **빌드 번호**: 1
- **카테고리**: 생활 (Lifestyle) 또는 유틸리티 (Utilities)
- **연령 등급**: 4+ (모든 연령)

## 앱 설명 (한국어)

### 짧은 설명 (30자 이내)
일산 YCITY 주차장 차량 위치 확인 앱

### 앱 설명
YCITY+ 는 일산 YCITY 주차장에서 내 차량의 주차 위치를 쉽고 빠르게 확인할 수 있는 편리한 앱입니다.

주요 기능:
• 실시간 차량 위치 확인
• 주차층 정보 표시
• 간편한 동/호수 입력
• 직관적인 사용자 인터페이스
• 안전한 데이터 보호

YCITY 아파트 주민들을 위한 맞춤형 서비스로, 복잡한 주차장에서도 내 차를 쉽게 찾을 수 있습니다.

### 키워드
주차장, 차량위치, YCITY, 일산, 아파트, 주차, 편의

### 개인정보 처리방침 URL
[개인정보 처리방침 URL이 필요합니다]

### 지원 URL
[고객지원 URL이 필요합니다]

## 스크린샷 요구사항
- iPhone 6.7" (iPhone 14 Pro Max): 1290 × 2796 pixels
- iPhone 6.5" (iPhone 11 Pro Max): 1242 × 2688 pixels  
- iPhone 5.5" (iPhone 8 Plus): 1242 × 2208 pixels

필요한 스크린샷:
1. 메인 화면 (차량 정보 입력)
2. 차량 위치 표시 화면
3. 설정/정보 화면

## 앱 아이콘
- 이미 설정됨: YCITY+ 로고 (1024x1024)

## 출시 체크리스트

### 필수 사항
- [x] Info.plist 최적화 완료
- [x] 앱 아이콘 설정 완료
- [x] 릴리즈 빌드 테스트 완료
- [x] IPA 파일 생성 완료
- [ ] 개인정보 처리방침 작성
- [ ] 고객지원 페이지 생성
- [ ] 앱 스크린샷 촬영
- [ ] Apple Developer 계정 확인
- [ ] App Store Connect에서 앱 정보 입력

### 권장 사항
- [ ] 베타 테스트 (TestFlight)
- [ ] 앱 리뷰 가이드라인 검토
- [ ] ASO (앱스토어 최적화) 키워드 연구

## 업로드 방법
1. **Apple Transporter 사용**:
   - Transporter 앱 다운로드
   - build/ios/ipa/*.ipa 파일을 드래그 앤 드롭

2. **Terminal 사용**:
   ```bash
   xcrun altool --upload-app --type ios -f build/ios/ipa/*.ipa --apiKey [YOUR_API_KEY] --apiIssuer [YOUR_ISSUER_ID]
   ```

## 참고사항
- 현재 코드사이닝이 설정되어 있으므로 바로 업로드 가능
- 론치 이미지를 커스텀 이미지로 교체 권장
- 위치 권한 설명이 Info.plist에 추가됨