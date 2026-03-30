# Android 위젯 백그라운드 갱신 수정 계획

## 문제

앱이 포그라운드에 있을 때는 위젯이 정상 업데이트되지만,
백그라운드에서는 자동 갱신이 되지 않는다.

## 버그 원인 (3가지)

### 버그 1 (Critical): WidgetAlarmReceiver — goAsync() 미사용

`onReceive()`에서 백그라운드 스레드를 시작하고 즉시 return.
Android는 `onReceive()` 리턴 후 BroadcastReceiver 프로세스를 종료할 수 있어
HTTP 요청이 완료되기 전에 죽는다.
→ 백그라운드에서 위젯이 갱신되지 않는 직접적 원인

**수정**: `goAsync()` 추가, `apply()` → `commit()`

### 버그 2 (Major): WidgetUpdateWorker — 이중 HTTP

`updateAllWidgets()`에서 `VehicleLocationWidgetProvider().onUpdate()`를 직접 호출.
`onUpdate()` 내부에서 또 HTTP 요청을 시작하는데, 이 스레드는
WorkManager coroutine이 await하지 않음 → doWork() 완료 시 함께 죽음.

**수정**: broadcast 방식으로 변경, 사용자 정보를 SharedPreferences에서 읽도록 수정

### 버그 3 (Minor): VehicleLocationWidgetProvider — 이중 HTTP

Alarm이 이미 데이터를 저장하고 broadcast를 보냈는데,
`onUpdate()`에서 또 HTTP 요청을 한다.

**수정**: 타임스탬프 체크로 30초 이내 갱신된 데이터는 캐시 사용

## 수정 파일

| 파일 | 수정 내용 |
|------|---------|
| WidgetAlarmReceiver.kt | goAsync(), commit() |
| WidgetUpdateWorker.kt | broadcast 방식, commit(), SharedPreferences에서 사용자정보 읽기 |
| VehicleLocationWidgetProvider.kt | 타임스탬프 체크 추가 |

## iOS 파일 절대 수정 금지

## 검증

```bash
./scripts/build_android.sh apk
adb logcat | grep -E "WidgetAlarmReceiver|WidgetUpdateWorker|VehicleLocationWidget"
```

기대 로그 (앱 종료 후 15분 후):
```
WidgetAlarmReceiver: 알람 수신
WidgetAlarmReceiver: 서버 요청
WidgetAlarmReceiver: 위젯 업데이트 완료
WidgetAlarmReceiver: 다음 알람 예약됨
```
