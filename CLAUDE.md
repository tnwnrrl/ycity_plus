# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Links

- **[Architecture Documentation](docs/ARCHITECTURE.md)** - Provider 아키텍처, 서비스 레이어, 데이터베이스 스키마, 설계 결정
- **[Build & Release Guide](docs/BUILD_GUIDE.md)** - 빌드 명령어, 릴리스 프로세스, 트러블슈팅, 코드 서명

# YCity Plus - Vehicle Location Tracking & Parking History App

Flutter mobile application for apartment complex parking management with automatic parking history tracking and analytics.

## Directory Structure

```
lib/
├── main.dart                           # App entry point with MultiProvider setup
├── models/                             # Data models
├── providers/                          # State management (Provider pattern)
├── services/                           # Business logic layer
├── screens/                            # UI screens
├── widgets/                            # Reusable UI components
└── database/                           # SQLite database management

android/app/src/main/kotlin/.../        # Android widget & background worker
ios/VehicleLocationWidget/              # iOS widget extension
scripts/                                # Build scripts (build_ios.sh, build_android.sh)
docs/                                   # Detailed documentation
```

## Essential Commands

```bash
# Build (ALWAYS use scripts)
./scripts/build_ios.sh                  # iOS IPA (App Store Connect)
./scripts/build_android.sh apk          # Android APK
./scripts/build_android.sh aab          # Android AAB

# Alternative for iOS
flutter build ipa --release             # Creates proper IPA

# Run on devices
flutter run -d "iPhone 16 Pro"          # iOS simulator
flutter run -d "00008140-00186D0C0882201C" --release  # iPhone (MUST use --release)

# Quality checks (MANDATORY before commits)
flutter analyze                         # Must pass with no issues
flutter test                            # Must all pass

# Flutter path (if not in PATH)
/Users/jjh/.claude/flutter/bin/flutter [command]
```

## Git Workflow

### MANDATORY: Automatic Version Increment

Every Git commit must automatically increment the build number:

1. Read current version from `pubspec.yaml` (line ~19)
2. Increment BUILD number (+1): `4.0.3+42` → `4.0.3+43`
3. Update `pubspec.yaml` with new version
4. Include updated `pubspec.yaml` in the commit

**Current Version**: 4.0.3+42

```bash
# Commit pattern
git add [files]
git commit -m "type: description"  # Claude auto-handles version increment
git push origin main

# Types: feat, fix, chore, refactor, docs
```

## Critical Rules

### Code Quality

- **Flutter Analyze**: Must show "No issues found!"
- **String Interpolation**: Use `'${variable}...'` not `variable + '...'`
- **Debug Mode Only**: Use `if (kDebugMode)` for debug outputs
- **HTTP-Only**: NEVER suggest HTTPS for parking API (intentional for performance)

### iOS Code Signing

**NEVER MODIFY CODE SIGNING SETTINGS**
- `CODE_SIGN_STYLE = Automatic` (DO NOT CHANGE)
- Xcode manages certificates and profiles automatically
- If issues occur: Check Apple Developer Center, don't modify project settings

### Important Configurations

- **Bundle ID**: `com.ilsan-ycity.ilsanycityplus`
- **Widget Extension**: `com.ilsan-ycity.ilsanycityplus.VehicleLocationWidget`
- **App Groups**: `group.com.ilsan-ycity.ilsanycityplus`
- **API Server**: `122.199.183.213` (HTTP only - intentional)

## Recent Updates (v4.0.3+42)

- **Widget Debug Info Fix (v4.0.3+42)**: Individual try-catch for getWidgetData calls
- **SharedPreferences Key Fix (v4.0.3+40)**: Flutter uses `flutter.` prefixed keys
- **iOS Widget ATS Fix (v4.0.3+37)**: HTTP exception for widget background refresh
- **Android Build Upgrade (v4.0.3+35)**: Gradle 8.7.0, AGP 8.6.0, Kotlin 2.1.0

## Test Credentials

- **Single Vehicle**: 103동 4705호 시리얼번호 a008227
- **Multiple Vehicle**: 101동 4304호 시리얼번호 a033388

## Widget Debugging

### iOS Widget Logs
```bash
log show --predicate 'subsystem == "com.ilsan-ycity.ilsanycityplus.VehicleLocationWidget"' --last 5m
```

### Widget Debug Dialog
Settings (⚙️) → 위젯 디버그 정보: Shows stored widget data for troubleshooting

---

For detailed information, see:
- **Architecture & Design**: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Build & Troubleshooting**: [docs/BUILD_GUIDE.md](docs/BUILD_GUIDE.md)
