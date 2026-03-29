# Build & Release Guide

This document covers build commands, release processes, and troubleshooting for the YCity Plus application.

## Development Commands

### Use Organized Build Scripts

**ALWAYS use organized build scripts instead of direct Flutter commands**

```bash
# PREFERRED: Organized Build Scripts (Use These)
./scripts/build_ios.sh                 # iOS IPA 빌드 (App Store Connect 업로드용)
./scripts/build_android.sh apk         # Android APK 빌드
./scripts/build_android.sh aab         # Android AAB 빌드
./scripts/build_android.sh both        # APK + AAB 동시 빌드

# ALTERNATIVE: Flutter standard method for App Store Connect
flutter build ipa --release            # Creates proper IPA for Transporter upload

# AVOID: Manual build commands (legacy - files saved to wrong location)
flutter build apk --release            # Don't use - wrong directory
flutter build ios --release            # Don't use - no version in filename, can't upload to App Store
flutter build appbundle --release      # Don't use - wrong directory
```

### Running & Testing

```bash
# CRITICAL: Flutter Path Setup
# Flutter may not be in PATH. If commands fail, use full path:
/Users/jjh/.claude/flutter/bin/flutter [command]

# Run on specific devices
flutter run -d "iPhone 16 Pro"          # iOS simulator
flutter run -d "emulator-5554"          # Android emulator

# CRITICAL: iPhone 실제 기기 테스트 방법
# iPhone 실제 기기에서는 debug 모드에서 Flutter framework 크래시 이슈 발생
# 반드시 release 모드로 실행해야 정상 작동
flutter run -d "00008140-00186D0C0882201C" --release    # iPhone 실제 기기 (MUST use --release)
# flutter run -d "00008140-00186D0C0882201C" --debug    # NEVER use - causes crash

# Quality checks (mandatory before commits)
flutter analyze                         # Lint check (must pass with no issues)
flutter test                           # Run all tests (must all pass)
flutter test test/widget_test.dart      # Run single test file

# Development workflow
flutter clean && flutter pub get       # Clean rebuild
flutter pub deps                       # Show dependency tree
flutter doctor                         # Check Flutter installation

# CocoaPods management (iOS only)
cd ios && pod install                   # Install iOS dependencies when needed
```

### Organized Build System

```bash
# Build directory structure
builds/
├── ios/release/          # iOS IPA files
├── android/release/      # Android APK/AAB files
└── README.md            # Build documentation

# Build file naming convention
YCITY_Plus_v{version}_{build}.{ext}
# Example: YCITY_Plus_v4.0.3_8.ipa
```

### Database Debugging

```bash
# View SQLite database (Android)
adb exec-out run-as com.mycompany.YcityPlus cat databases/ycity_plus.db > local.db
sqlite3 local.db

# Common queries
SELECT * FROM parking_history ORDER BY entry_time DESC LIMIT 10;
SELECT floor, COUNT(*) FROM parking_history GROUP BY floor;
```

## Version Management

Update in `pubspec.yaml`:
```yaml
version: 4.0.3+42  # Format: MAJOR.MINOR.PATCH+BUILD
```

**Current Version**: 4.0.3+42

### Automatic Version Increment

**MANDATORY**: Every Git commit must automatically increment the build number in pubspec.yaml

**Version Increment Rules**:
1. **Before every Git commit**: Automatically increment build number (e.g., 4.0.3+41 → 4.0.3+42)
2. **Version format**: MAJOR.MINOR.PATCH+BUILD (keep MAJOR.MINOR.PATCH unchanged, only increment BUILD)
3. **Read current version** from pubspec.yaml line ~19: `version: X.Y.Z+BUILD`
4. **Auto-increment**: BUILD number by +1
5. **Update pubspec.yaml**: Replace version line with new incremented version
6. **Add to commit**: Include updated pubspec.yaml in the same commit

## iOS Code Signing - CRITICAL RULES

**NEVER MODIFY CODE SIGNING SETTINGS - AUTOMATIC SIGNING WORKS PROPERLY**

**CRITICAL INSTRUCTIONS:**
1. **NEVER change** `CODE_SIGN_STYLE`, `CODE_SIGN_IDENTITY`, or `DEVELOPMENT_TEAM` in project.pbxproj
2. **NEVER modify** provisioning profile settings manually
3. **ALWAYS use** automatic code signing (Xcode manages certificates and profiles)
4. **NEVER touch** any signing configuration in Xcode project settings

**Current Working Configuration (DO NOT CHANGE):**
- `CODE_SIGN_STYLE = Automatic` (for all targets including VehicleLocationWidget)
- `DEVELOPMENT_TEAM = 372L6244K5` (auto-managed by Xcode)
- Automatic provisioning profile selection
- All certificates and profiles managed by Apple Developer account

**If Build Issues Occur:**
1. Check Apple Developer Center for valid certificates
2. Verify provisioning profiles are not expired
3. Use `flutter clean` and rebuild
4. Contact Apple Developer support for certificate issues
5. **DO NOT** modify any code signing settings in project files

**Root Cause of Previous Issues:**
- VehicleLocationWidget extension added in commit f1aaa7e required App Store distribution profile
- Issue was resolved by maintaining automatic signing configuration
- Manual signing changes caused more problems than they solved

## Android Build System Configuration (v4.0.3+35)

**Current Versions (Post-Upgrade):**
- **Gradle**: 8.7.0 (in `android/gradle/wrapper/gradle-wrapper.properties`)
- **Android Gradle Plugin**: 8.6.0 (in `android/settings.gradle`)
- **Kotlin**: 2.1.0 (in `android/settings.gradle`)
- **Java Target Compatibility**: 11 (in `android/app/build.gradle`)
- **Compile SDK**: 36 (in `android/app/build.gradle`)

**Key Configuration Files:**
```bash
android/gradle/wrapper/gradle-wrapper.properties:
  distributionUrl=https\://services.gradle.org/distributions/gradle-8.7-all.zip

android/settings.gradle:
  id "com.android.application" version "8.6.0" apply false
  id "org.jetbrains.kotlin.android" version "2.1.0" apply false

android/app/build.gradle:
  compileSdk = 36
  targetSdk = 36
  sourceCompatibility = JavaVersion.VERSION_11
  targetCompatibility = JavaVersion.VERSION_11
  jvmTarget = JavaVersion.VERSION_11
```

**Upgrade Benefits:**
- Eliminated all Flutter/Android build warnings (3 warnings fixed)
- Eliminated all Java compiler warnings (3 warnings fixed)
- Modern build toolchain compatibility
- Improved build performance and reliability
- Future-proofed for upcoming Flutter/Android updates

## Android Release

```bash
# Ensure keystore exists
android/app/upload-keystore.jks

# Build release APK
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release
```

## iOS Release - App Store Connect Upload

**CRITICAL: Transporter Upload Issues Resolved (v4.0.3+21)**

```bash
# RECOMMENDED: Use improved build script with proper export
./scripts/build_ios.sh
# - Uses Xcode exportArchive for proper App Store signing
# - Includes ExportOptions.plist for correct export configuration
# - Creates Transporter-compatible IPA files

# ALTERNATIVE: Flutter standard method (also works)
flutter build ipa --release
# IPA location: build/ios/ipa/YCITY+.ipa

# LEGACY: Don't use (creates development-signed IPA)
flutter build ios --release
# - Development signing only, Transporter will reject

# Transporter Upload (both methods work)
# Drag IPA to Transporter app or use:
xcrun altool --upload-app --type ios -f "path/to/ipa" --apiKey [KEY] --apiIssuer [ISSUER]
```

**Key Improvements (Latest):**
- **ExportOptions.plist**: Proper App Store export configuration
- **Automatic Signing**: Uses Apple Distribution certificates automatically during export
- **Transporter Compatible**: IPA files work with App Store Connect upload
- **NEVER modify signing in Xcode**: Automatic signing is properly configured

## App Store Connect Integration

- **Bundle ID**: `com.ilsan-ycity.ilsanycityplus`
- **Widget Extension**: `com.ilsan-ycity.ilsanycityplus.VehicleLocationWidget`
- **Deep Linking**: `ycityplus://` URL scheme for widget navigation
- **App Groups**: `group.com.ilsan-ycity.ilsanycityplus` for shared data

## Code Quality Requirements

### Mandatory Quality Checks

Before committing any changes, ensure:
1. **Flutter Analyze**: `flutter analyze` must show "No issues found!"
2. **All Tests Pass**: `flutter test` must complete successfully
3. **String Interpolation**: Use `'${variable}...'` instead of `variable + '...'`
4. **Debug Mode Only**: Use `if (kDebugMode)` for debug outputs
5. **Proper Imports**: Follow existing import organization patterns
6. **HTTP-Only Rule**: NEVER suggest HTTPS upgrades for parking system API - HTTP is intentional for performance

### Enhanced Exception Handling Pattern

Use specific exception types with meaningful error messages:
```dart
} on FormatException catch (e) {
  _log('URI 파싱 오류: $e');
} catch (e) {
  _log('예상치 못한 오류: $e');
}
```

### Constants Pattern for UI Timing

Extract magic numbers into named constants:
```dart
static const Duration _uiInitializationDelay = Duration(milliseconds: 1000);
static const Duration _navigationDelay = Duration(milliseconds: 200);
static const int _recentLaunchThresholdMs = 10000; // 10초
```

### Git Ignore Coverage

The `.gitignore` file excludes:
- iOS/macOS build artifacts (`ios/build/`, `*.xcarchive`, `*.ipa`, `*.dSYM/`)
- Swift Package Manager files (`**/Runner.xcworkspace/xcshareddata/swiftpm/`)
- Release entitlements (`**/*Release.entitlements`)
- Build output directories (`builds/`, `scripts/`)

## Troubleshooting Guide

### Flutter Development Issues

#### Flutter Command Not Found
```bash
# If flutter commands fail, Flutter is not in PATH
# Use full path instead:
/Users/jjh/.claude/flutter/bin/flutter doctor
/Users/jjh/.claude/flutter/bin/flutter build ios --release

# Or add to PATH temporarily:
export PATH="/Users/jjh/.claude/flutter/bin:$PATH"
```

#### CocoaPods Installation Issues (iOS)
```bash
# If "CocoaPods not installed" error occurs:
brew install cocoapods
cd ios && pod install

# If pod install fails with dependency conflicts:
cd ios && pod install --repo-update
```

#### Android SDK Issues
```bash
# If "No Android SDK found" error occurs:
# Install Android Studio first, then:
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools
```

#### Build Failures
```bash
# Clean rebuild process:
flutter clean
flutter pub get
cd ios && pod install  # iOS only
flutter build [platform] --release

# If iOS build fails with signing errors:
# DO NOT modify signing settings manually
# Check Apple Developer Center for certificate validity
```

### Widget Development Issues

#### Widget Not Updating
- **Android**: Check WorkManager scheduling in WidgetUpdateWorker.kt
- **iOS**: iOS widgets work independently without UIBackgroundModes - check Timeline Provider and system-managed scheduling
- **Both**: Confirm auto-refresh setting key consistency (`widget_auto_refresh`)

#### Widget Data Not Persisting
- **Android**: Check SharedPreferences key naming
- **iOS**: Verify UserDefaults App Group configuration
- **Both**: Ensure HomeWidgetService.initialize() is called properly
- **Debug Tools**: Use iOS widget debug dialog (⚙️ → 🔧 디버그) to check stored values

#### Widget Debug Dialog (iOS)
Access via Settings (⚙️) → Debug section:
- **위젯 디버그 정보**: Shows all stored widget data (user info, floor data, refresh status)
- **위젯 강제 새로고침**: Manually trigger widget timeline refresh
- Visible in both Debug and Release modes for easier testing

#### iOS Widget Logging
View iOS widget logs in Console.app:
```bash
# Filter by widget subsystem
log show --predicate 'subsystem == "com.ilsan-ycity.ilsanycityplus.VehicleLocationWidget"' --last 5m
```

### Debugging Guide

#### Network Issues - Multi-Vehicle Debugging
```dart
// Check logs for multiple vehicle parsing:
[VehicleLocationService] 다중 차량 시도 1/2, HTTPS URL: ...
[VehicleLocationService] HTTP 응답 성공, HTML 길이: 7632
[VehicleLocationService] HTML 전체 텍스트 분석 시작
[VehicleLocationService] 차량 번호 발견: 1
[VehicleLocationService] 차량 1: B3
[VehicleLocationService] 차량 번호 발견: 2
[VehicleLocationService] 차량 2: 출차됨
[VehicleLocationService] 다중 차량 감지됨: B3, 출차됨 (총 2개)

// Common issues:
- Timeout after 8s → Network connectivity
- "다중 차량 파싱 실패" → Check line-by-line parsing logic
- Vehicle selector not appearing → Check isMultipleVehicleMode state
- Vehicle selection not persisting → Check dual persistence (HomeWidget + SharedPreferences)
```

#### Parking History Issues
```dart
// Check logs for:
[ParkingHistoryService] 새로운 주차 이력 생성: B4층 (ID: 1)
[ParkingHistoryService] 출차 이벤트 감지되었으나 주차 중인 이력이 없음
[DatabaseHelper] 주차 이력 테이블 및 인덱스 생성 완료

// Database debugging:
- Check migration success
- Verify indexes created
- Look for constraint violations
```

## Common Development Tasks

### Adding New Floor Support
1. Update `validFloorCodes` in VehicleLocationService
2. Add floor color mapping in `ParkingFloorInfo.floorColorKey`
3. Update `_extractFloorFromText` regex patterns
4. Add floor color in both `ParkingHistoryScreen._getFloorColor` and `HomePageProvider._getFloorColor`

### Modifying Cache Behavior
```dart
// Change cache duration in VehicleLocationService
static const Duration _cacheExpiry = Duration(minutes: 5);

// Force cache refresh via Provider
final vehicleLocationProvider = context.read<VehicleLocationProvider>();
await vehicleLocationProvider.refreshVehicleLocation(userInfo);
```

### Adding New Provider
1. Create Provider class extending `ChangeNotifier`
2. Add to `MultiProvider` in `main.dart`
3. Access via `Consumer` widgets or `context.read<T>()`
4. Call `notifyListeners()` when state changes

### Database Migrations
Database version is managed in `DatabaseHelper._initDatabase()`. Current version: 2.
For new migrations:
1. Increment version number
2. Add migration logic in `_onUpgrade` method
3. Test upgrade path from previous versions

## QHD+ Resolution Warning Test Mode

**DO NOT DELETE DURING CLEANUP - This is a critical development tool**

The app includes a test mode system for debugging QHD+ resolution warnings on low-resolution devices.

### Purpose
- Test QHD+ resolution warning dialogs on devices that don't actually have QHD+ resolution
- Debug and validate warning UI without requiring high-resolution test devices
- Verify warning logic and user flows in development environment

### How to Activate Test Mode
**Test button is hidden by default for cleaner UI**

**To Enable Test Button:**
1. **Edit Code**: Change `&& false` to `&& true` in `home_page_provider.dart` line 636
2. **Location**: `if (Platform.isAndroid && kDebugMode && false)` → `if (Platform.isAndroid && kDebugMode && true)`
3. **Hot Reload**: Use `r` in terminal to apply changes

**To Use Test Mode:**
1. **Activate**: Click the bug icon button in the home screen header (Android debug mode only)
2. **Test**: Navigate to vehicle location screen to trigger warning dialog
3. **Verify**: Check test mode dialog displays with "테스트 모드 활성화됨" message
4. **Deactivate**: Use "테스트 종료" button in dialog or click bug icon again

**To Hide Button Again:** Change `&& true` back to `&& false` and hot reload

### Test Mode Features
- **Safe by Default**: Test mode is disabled by default (`_testModeEnabled = false`)
- **Debug Mode Only**: Test button only visible in Android debug builds
- **Visual Feedback**: Bug icon highlights orange when test mode is active
- **Test Dialog**: Special dialog variant with test mode indicators and controls
- **Easy Toggle**: One-click activation/deactivation via home screen button

### Cleanup Protection
All test mode code is protected with `cleanup 금지` comments to prevent accidental removal during code cleanup operations.

## Test Credentials

- **Single Vehicle Account**: 103동 4705호 시리얼번호 a008227
- **Multiple Vehicle Account**: 101동 4304호 시리얼번호 a033388
- **Expected Data**: 차량 1: B3층, 차량 2: 서비스 지역에 없음
- **UI Behavior**: Vehicle selector appears only for multiple vehicles, dynamic switching between B3/orange and X/grey

## Known Issues (Resolved)

- **Single Vehicle False Detection**: Fixed fallback logic that incorrectly identified single vehicles as multiple vehicles
- **State Synchronization**: Enhanced multi→single vehicle transition with complete state reset
- **UI Defensive Logic**: Added conditions to prevent vehicle selector display in single vehicle mode
