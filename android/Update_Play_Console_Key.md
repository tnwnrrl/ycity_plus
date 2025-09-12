# Google Play Console 키 업데이트 방법

## 🔑 현재 키를 Play Console에 업데이트하는 방법

Google Play Console에서는 몇 가지 방법으로 키를 업데이트할 수 있습니다.

## 방법 1: Play App Signing 사용 (권장)

### 1단계: Play App Signing 활성화
1. **Google Play Console** → **앱 선택**
2. **설정** → **앱 서명**
3. **Play 앱 서명 사용** 클릭

### 2단계: 새 키 업로드
1. **업로드 키 인증서** 섹션에서
2. **새 업로드 키 추가** 클릭
3. **인증서 업로드 방법 선택**:
   - **Java 키스토어에서 내보내기** (현재 상황에 적합)

### 3단계: 현재 키스토어에서 인증서 추출
```bash
# 현재 키스토어에서 인증서 추출
keytool -export -rfc -keystore android/app/upload-keystore.jks -alias upload -file upload_certificate.pem

# 비밀번호 입력: android
```

### 4단계: 인증서 업로드
1. 생성된 `upload_certificate.pem` 파일을 Play Console에 업로드
2. **저장** 클릭

## 방법 2: 구글 지원팀에 문의

### 키 재설정 요청
1. **Google Play Console** → **도움말**
2. **문의하기** → **앱 서명 키 문제**
3. **키 재설정 요청** 제출

### 필요한 정보:
```
앱 패키지명: com.ilsan_ycity.ilsanycityplus
현재 키 SHA1: 78:5B:5C:8C:53:84:A1:18:39:FD:D1:85:6B:E8:C7:4C:EA:49:D4:C0
요청 사유: 새로운 업로드 키로 변경 필요
```

## 방법 3: 앱 번들 재서명

### Google에서 제공하는 pepk 도구 사용
1. **pepk.jar 다운로드**:
```bash
# Google 공식 pepk 도구 다운로드
curl -o pepk.jar https://www.gstatic.com/play-apps-publisher-rapid/signing-tool/prod/pepk.jar
```

2. **키스토어를 Play Console 형식으로 변환**:
```bash
java -jar pepk.jar --keystore=android/app/upload-keystore.jks --alias=upload --output=output.zip --encryptionkey=eb10fe8f7c7c9df715022017b00c6471f8ba8170b13049a11e6c09ffe3056a104a3bbe4ac5a955f4ba4fe93fc8cef27558a3eb9d2a529a2092761fb833b673523cd2
```

3. **output.zip을 Play Console에 업로드**

## 방법 4: 실시간 해결 시도

현재 키스토어에서 인증서를 추출해보겠습니다:

### 1단계: 인증서 추출
```bash
cd /Users/jinhwanjeon/ycity_plus
keytool -export -rfc -keystore android/app/upload-keystore.jks -alias upload -file upload_certificate.pem -storepass android
```

### 2단계: Play Console에서 확인
1. **Play Console** → **설정** → **앱 서명**
2. **업로드 키 인증서** 섹션 확인
3. **새 업로드 키 추가** 옵션이 있는지 확인

## 주의사항

### ⚠️ 중요 정보
- **첫 업로드가 아닌 경우**: 키 변경이 제한될 수 있음
- **Play App Signing 미사용**: 키 변경이 더 복잡함
- **보안 검토**: Google에서 키 변경 시 보안 검토 진행

### 🔒 보안 고려사항
- 새 키는 기존 키와 동일한 CN(Common Name) 사용 권장
- 키 변경 후 이전 키는 무효화됨
- 모든 향후 업데이트는 새 키로 서명 필요

## 추천 순서

### 1순위: Play App Signing 확인
- Play Console에서 Play App Signing 상태 확인
- 활성화되어 있다면 새 업로드 키 추가 가능

### 2순위: 인증서 업로드 시도
- 현재 키에서 인증서 추출
- Play Console에 직접 업로드 시도

### 3순위: Google 지원팀 문의
- 위 방법들이 불가능한 경우
- 공식 지원을 통한 키 재설정

지금 바로 인증서 추출을 시도해보시겠습니까?