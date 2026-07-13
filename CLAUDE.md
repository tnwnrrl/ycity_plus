# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# YCity Plus - Vehicle Location Tracking & Parking History App

Flutter mobile application for apartment complex parking management with automatic parking history tracking and analytics.

## Essential Commands

```bash
# Build (ALWAYS use scripts)
./scripts/build_ios.sh                  # iOS IPA (App Store Connect)
./scripts/build_android.sh apk          # Android APK
./scripts/build_android.sh aab          # Android AAB

# Run on devices
flutter run -d "iPhone 16 Pro"          # iOS simulator
flutter run -d "00008140-00186D0C0882201C" --release  # iPhone (MUST use --release)

# Quality checks (MANDATORY before commits)
flutter analyze                         # Must pass with no issues
flutter test                            # Must all pass

# Flutter path (if not in PATH)
/Users/jjh/.claude/flutter/bin/flutter [command]

# iOS widget logs
log show --predicate 'subsystem == "com.ilsan-ycity.ilsanycityplus.VehicleLocationWidget"' --last 5m
```

## Git Workflow

**Every commit must increment the build number** in `pubspec.yaml` (line ~19):
- Format: `4.0.4+1` → `4.0.4+2`
- Include updated `pubspec.yaml` in every commit

**Current Version**: 4.0.4+1

## Architecture

### Provider State Management (4 providers, all in `MultiProvider` at root)

| Provider | Responsibility |
|----------|---------------|
| `AppStateProvider` | Theme mode, network status, app init state |
| `UserInfoProvider` | User CRUD via SQLite (dong/ho/serialNumber) |
| `VehicleLocationProvider` | Real-time parking location, multi-vehicle, optimistic updates |
| `ParkingHistoryProvider` | Parking history, statistics, SQLite operations |

### Service Layer (all singletons)

| Service | Responsibility |
|---------|---------------|
| `VehicleLocationService` | HTTP → HTML parsing from `122.199.183.213`, LRU cache (3min), HTTP client reuse |
| `ParkingHistoryService` | Auto entry/exit detection, background processing via `Future.microtask()` |
| `HomeWidgetService` | iOS App Group + Android MethodChannel widget updates |
| `PreferencesService` | SharedPreferences wrapper, vehicle selection persistence |
| `UserInfoService` | SQLite CRUD, DB v2 schema, migrations |

### Data Flow

```
User input → Provider → Service → HTTP API (parking server)
                                      ↓ HTML parse → ParkingFloorInfo
                    ← notifyListeners ← cache update
                                      → HomeWidgetService → home screen widget
                                      → ParkingHistoryService → SQLite
```

### Widget Architecture (Home Screen Widget)

**Key constraint**: `HomeWidgetService` uses `flutter.` prefixed SharedPreferences keys explicitly because `home_widget` package does NOT auto-add prefixes. iOS widget and Android worker read the same keys.

- **iOS**: Swift extension in `ios/VehicleLocationWidget/`
- **Android**: `WidgetUpdateWorker` (WorkManager, 15-min intervals), `VehicleLocationWidgetProvider`, `WidgetAlarmReceiver`
- **MethodChannels**: `ycityplus/widget_click` (click events), `ycityplus/workmanager` (background)

### Database Schema (SQLite v2)

- `user_info`: dong, ho, serial_number, created_at, updated_at
- `parking_history`: dong, ho, serial_number, floor, entry_time, exit_time, parking_duration_minutes, status, notes

## Critical Rules

### Code Quality
- **Flutter Analyze**: Must show "No issues found!"
- **String Interpolation**: Use `'${variable}...'` not `variable + '...'`
- **Debug output**: Always wrap with `if (kDebugMode)`
- **HTTP-Only**: NEVER use HTTPS for parking API — intentional, do not change

### iOS Code Signing
- `CODE_SIGN_STYLE = Automatic` — **DO NOT MODIFY**
- If signing issues occur: check Apple Developer Center, never edit project settings

### Important Configurations
- **Bundle ID**: `com.ilsan-ycity.ilsanycityplus`
- **Widget Extension**: `com.ilsan-ycity.ilsanycityplus.VehicleLocationWidget`
- **App Groups**: `group.com.ilsan-ycity.ilsanycityplus`
- **API Server**: `http://122.199.183.213/rtlsTag/main/action.do`
- **Valid floors**: B1, B2, B3, B4

## Test Credentials

- **Single vehicle**: 103동 4705호 시리얼번호 `a008227`
- **Multiple vehicles**: 101동 4304호 시리얼번호 `a033388`

## Widget Debugging

Settings (⚙️) → 위젯 디버그 정보: shows stored SharedPreferences widget data

## Documentation

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — detailed architecture, service interactions, design decisions
- **[docs/BUILD_GUIDE.md](docs/BUILD_GUIDE.md)** — build commands, release process, troubleshooting
- **[docs/privacy_policy.html](https://tnwnrrl.github.io/ycity_plus/privacy_policy.html)** — Play Store privacy policy
