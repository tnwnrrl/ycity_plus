# YCITY+ iOS App Store 업로드 가이드

## 현재 상태
✅ **준비 완료**: IPA 파일이 성공적으로 생성되었습니다!
- 위치: `build/ios/ipa/ycity_plus.ipa`
- 크기: 24.0MB
- 코드사이닝: 완료 (Apple Development: Jinhwan Jeon)

## App Store Connect 업로드 방법

### 방법 1: Apple Transporter 사용 (추천)
1. **Apple Transporter 설치**:
   - App Store에서 "Transporter" 다운로드
   - 또는 링크: https://apps.apple.com/us/app/transporter/id1450874784

2. **업로드 과정**:
   ```bash
   # 1. Transporter 앱 실행
   # 2. "+" 버튼 클릭
   # 3. 다음 파일 선택:
   /Users/jinhwanjeon/ycity_plus/build/ios/ipa/ycity_plus.ipa
   # 4. "전송" 버튼 클릭
   ```

### 방법 2: 터미널 사용
```bash
# API Key가 필요한 경우
xcrun altool --upload-app --type ios \\
  -f /Users/jinhwanjeon/ycity_plus/build/ios/ipa/ycity_plus.ipa \\
  --apiKey [YOUR_API_KEY] \\
  --apiIssuer [YOUR_ISSUER_ID]
```

## App Store Connect 설정

### 1. 앱 등록
- **Bundle ID**: `com.ilsan-ycity.ilsanycityplus`
- **앱 이름**: YCITY+
- **SKU**: 임의의 고유 식별자 (예: com.ilsan-ycity.ilsanycityplus.001)

### 2. 앱 정보 입력
```
카테고리: 생활 (Lifestyle)
부카테고리: 유틸리티
연령 등급: 4+ (모든 연령)
```

### 3. 필수 정보
- **개인정보 처리방침 URL**: [필요]
- **지원 URL**: [필요]
- **마케팅 URL**: [선택사항]

### 4. 앱 설명
```
짧은 설명:
일산 YCITY 주차장 차량 위치 확인 앱

상세 설명:
YCITY+ 는 일산 YCITY 주차장에서 내 차량의 주차 위치를 쉽고 빠르게 확인할 수 있는 편리한 앱입니다.

주요 기능:
• 실시간 차량 위치 확인
• 주차층 정보 표시
• 간편한 동/호수 입력
• 직관적인 사용자 인터페이지
• 안전한 데이터 보호

YCITY 아파트 주민들을 위한 맞춤형 서비스로, 복잡한 주차장에서도 내 차를 쉽게 찾을 수 있습니다.
```

### 5. 키워드
```
주차장,차량위치,YCITY,일산,아파트,주차,편의,위치찾기,스마트파킹,주민편의
```

## 스크린샷 요구사항

### iPhone 6.7" (1290 × 2796) - 필수
시뮬레이터에서 촬영 가능한 화면들:

1. **메인 화면** (차량 정보 입력)
   - 동, 호, 시리얼번호 입력 폼
   - YCITY+ 로고 표시

2. **차량 위치 표시 화면**
   - "현재 주차 위치: B4" 표시
   - 마지막 업데이트 시간

3. **설정/정보 화면**
   - 앱 정보 및 사용법

### 스크린샷 촬영 방법
```bash
# iOS 시뮬레이터에서
# Cmd + S 또는 Device > Screenshot
# 파일은 데스크톱에 저장됨
```

## 심사 준비사항

### 필수 체크리스트
- [x] IPA 파일 생성 완료
- [x] 앱 아이콘 설정 완료
- [x] Info.plist 최적화 완료
- [x] 코드사이닝 완료
- [ ] 개인정보 처리방침 페이지 제작
- [ ] 고객지원 페이지 제작
- [ ] 스크린샷 촬영 (3-10장)
- [ ] App Store Connect에서 앱 정보 입력

### 심사 가이드라인 준수사항
1. **기능성**: 앱이 정상적으로 작동해야 함
2. **성능**: 크래시나 버그가 없어야 함
3. **비즈니스**: 앱의 목적이 명확해야 함
4. **디자인**: Apple Human Interface Guidelines 준수
5. **법적**: 개인정보 처리방침 필수

## 예상 심사 시간
- **첫 심사**: 24-48시간
- **업데이트**: 24시간 이내

## 심사 거부 시 대응방안
1. **Rejection 이유 확인**
2. **해당 이슈 수정**
3. **새 빌드 업로드**
4. **Resolution Center에서 답변**

## 문제 해결

### 일반적인 이슈들
1. **메타데이터 거부**
   - 스크린샷과 앱 기능 불일치
   - 부적절한 키워드 사용

2. **기술적 거부**
   - 크래시나 버그
   - 네트워크 연결 실패

3. **가이드라인 위반**
   - 개인정보 처리방침 누락
   - 부적절한 콘텐츠

### 현재 앱의 잠재적 이슈
1. **네트워크 의존성**: HTTP 통신 실패 시 대응
2. **위치 권한**: 사용하지 않는 위치 권한 설명 제거 검토

## 출시 후 관리
1. **버전 업데이트** 계획
2. **사용자 피드백** 모니터링
3. **크래시 리포트** 분석
4. **앱 스토어 리뷰** 관리

---

## 즉시 실행 가능한 다음 단계

1. **Transporter 앱 설치** 및 IPA 업로드
2. **App Store Connect**에서 앱 정보 입력
3. **스크린샷 촬영** (시뮬레이터 실행 중)
4. **개인정보 처리방침** 및 **지원 페이지** 제작

현재 IPA 파일이 준비되어 있으므로 언제든지 App Store에 업로드할 수 있습니다!