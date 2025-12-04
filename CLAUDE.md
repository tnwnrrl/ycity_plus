# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# YCity Plus - Vehicle Location Tracking & Parking History App

Flutter mobile application for apartment complex parking management with automatic parking history tracking and analytics.

## Directory Structure

### Key File Locations
```
lib/
├── main.dart                           # App entry point with MultiProvider setup
├── models/                             # Data models
│   ├── user_info.dart                  # User data model
│   ├── parking_floor_info.dart         # Vehicle location model  
│   ├── parking_history.dart            # History data model
│   └── vehicle_service_error.dart      # Error handling model
├── providers/                          # State management
│   ├── app_state_provider.dart         # Global app state
│   ├── user_info_provider.dart         # User data management
│   ├── vehicle_location_provider.dart  # Location & multi-vehicle logic
│   └── parking_history_provider.dart   # History & analytics
├── services/                           # Business logic layer
│   ├── vehicle_location_service.dart   # Core API & parsing logic
│   ├── parking_history_service.dart    # Background event processing
│   ├── home_widget_service.dart        # Cross-platform widget updates
│   ├── preferences_service.dart        # Local storage wrapper
│   ├── user_info_service.dart          # Database operations
│   └── android_resolution_warning_service.dart # QHD+ detection
├── screens/                            # UI screens
│   ├── home_page_provider.dart         # Main screen with Consumer widgets
│   ├── vehicle_location_screen.dart    # Location display screen
│   ├── parking_history_screen.dart     # History & statistics
│   └── android_resolution_guide_screen.dart # Resolution fix guide
├── widgets/                            # Reusable UI components
└── database/
    └── database_helper.dart            # SQLite database management

android/app/src/main/kotlin/com/mycompany/YcityPlus/
├── VehicleLocationWidgetProvider.kt    # Android widget provider
└── WidgetUpdateWorker.kt              # WorkManager background tasks

ios/
├── VehicleLocationWidget/             # iOS widget extension
└── Runner/Info.plist                 # iOS permissions & configuration

scripts/
├── build_ios.sh                      # Organized iOS IPA build
└── build_android.sh                  # Organized Android APK/AAB build
```

## Architecture Overview

### Provider State Management Architecture (Current)
```
MultiProvider (Root)
├── AppStateProvider (Global State)
│   ├── Theme mode management (light/dark)
│   ├── Network connectivity status
│   └── App initialization state
├── UserInfoProvider (User Data)
│   ├── Database integration via UserInfoService
│   ├── User validation and CRUD operations
│   └── Current user session management
├── VehicleLocationProvider (Location State)
│   ├── Real-time vehicle position tracking
│   ├── Integration with VehicleLocationService
│   ├── Error handling and retry logic
│   └── Caching and refresh management
└── ParkingHistoryProvider (History & Analytics)
    ├── Historical parking data management
    ├── Statistics calculation and caching
    └── Integration with ParkingHistoryService
```

### Service Layer Architecture
```
VehicleLocationService (Primary) - Enhanced Multiple Vehicle Support
├── HTTP API communication with parking system (122.199.183.213)
├── Unlimited vehicle parsing with line-by-line HTML analysis
├── Dual cache system (single + multiple vehicle caches with LRU eviction)
├── HTTP client reuse for performance optimization
├── Dong number sanitization ("103동" → "103")
└── Cross-platform parsing consistency (Flutter + iOS widget)

VehicleLocationProvider (State Management) - Multi-Vehicle Architecture
├── Unified state management for 1+ vehicles
├── Dynamic vehicle selection with reactive UI updates
├── Optimistic updates with rollback capability
├── Provider pattern integration with Consumer widgets
└── SharedPreferences + HomeWidget dual persistence

ParkingHistoryService (Event Tracking)
├── Automatic entry/exit detection for multiple vehicles
├── Background event processing via Future.microtask()
├── Statistics calculation with Provider integration
└── SQLite database operations with multi-vehicle support

PreferencesService (Local Storage) - Extended Multi-Vehicle
├── SharedPreferences wrapper with vehicle selection persistence
├── Last parked floor persistence per vehicle
├── Multi-vehicle metadata storage (count, selected index)
└── Dual persistence strategy coordination

UserInfoService (Database)
├── SQLite database management (v2 schema)
├── User information CRUD with Provider integration
└── Migration handling and database initialization

HomeWidgetService (Widget Updates) - Multi-Vehicle Widget Support
├── iOS home screen widget updates with vehicle selection
├── Android widget provider integration
├── Multi-vehicle information storage and retrieval
├── Selected vehicle persistence across app/widget boundary
└── Platform-specific cross-platform vehicle display consistency

AndroidResolutionWarningService (QHD+ Warning System)
├── QHD+ resolution detection (horizontal ≥1440px)
├── Test mode functionality for development/debugging
├── Platform-specific warning logic (Android only)
└── Resolution type classification and validation

WidgetUpdateWorker (Android Background Updates) - NEW in v4.0.3+26
├── WorkManager-based periodic background tasks (15-minute intervals)
├── Server communication from widget context
├── HTML parsing identical to main app logic
├── SharedPreferences data persistence
└── Automatic widget provider updates
```

### Database Schema (v2)
```sql
-- User information table
user_info (
  id INTEGER PRIMARY KEY,
  dong TEXT NOT NULL,
  ho TEXT NOT NULL,
  serial_number TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  UNIQUE(dong, ho, serial_number)
)

-- Parking history table (added in v2)
parking_history (
  id INTEGER PRIMARY KEY,
  dong TEXT NOT NULL,
  ho TEXT NOT NULL,
  serial_number TEXT NOT NULL,
  floor TEXT NOT NULL,
  entry_time TEXT NOT NULL,
  exit_time TEXT,
  parking_duration_minutes INTEGER,
  status TEXT NOT NULL DEFAULT 'parked',
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)

-- Indexes for performance
CREATE INDEX idx_parking_user ON parking_history(dong, ho, serial_number)
CREATE INDEX idx_parking_entry_time ON parking_history(entry_time)
CREATE INDEX idx_parking_status ON parking_history(status)
CREATE INDEX idx_parking_floor ON parking_history(floor)
```

## Development Commands

### ⚠️ IMPORTANT: Use Organized Build Scripts
**ALWAYS use organized build scripts instead of direct Flutter commands**

```bash
# ✅ PREFERRED: Organized Build Scripts (Use These)
./scripts/build_ios.sh                 # iOS IPA 빌드 (App Store Connect 업로드용)
./scripts/build_android.sh apk         # Android APK 빌드
./scripts/build_android.sh aab         # Android AAB 빌드
./scripts/build_android.sh both        # APK + AAB 동시 빌드

# ✅ ALTERNATIVE: Flutter standard method for App Store Connect
flutter build ipa --release            # Creates proper IPA for Transporter upload

# ❌ AVOID: Manual build commands (legacy - files saved to wrong location)
flutter build apk --release            # Don't use - wrong directory
flutter build ios --release            # Don't use - no version in filename, can't upload to App Store
flutter build appbundle --release      # Don't use - wrong directory
```

### Running & Testing
```bash
# ⚠️ CRITICAL: Flutter Path Setup
# Flutter may not be in PATH. If commands fail, use full path:
/Users/jjh/.claude/flutter/bin/flutter [command]

# Run on specific devices
flutter run -d "iPhone 16 Pro"          # iOS simulator
flutter run -d "emulator-5554"          # Android emulator

# ⚠️ CRITICAL: iPhone 실제 기기 테스트 방법
# iPhone 실제 기기에서는 debug 모드에서 Flutter framework 크래시 이슈 발생
# 반드시 release 모드로 실행해야 정상 작동
flutter run -d "00008140-00186D0C0882201C" --release    # ✅ iPhone 실제 기기 (MUST use --release)
# ❌ flutter run -d "00008140-00186D0C0882201C" --debug  # NEVER use - causes crash

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

## Key Implementation Patterns

### Multi-Vehicle Provider Architecture (Current)
```
HomePageProvider.build()
├── Consumer<UserInfoProvider> → Load user data  
├── Consumer<VehicleLocationProvider> → Multi-vehicle location & selection
├── Consumer<ParkingHistoryProvider> → History & statistics
├── Consumer<AppStateProvider> → Theme & app state
└── _buildVehicleSelector() → Dynamic UI (appears when 2+ vehicles)

VehicleLocationProvider.fetchMultipleVehicleLocation()
├── Call VehicleLocationService.getMultipleVehicleLocationInfoWithErrorHandling()
├── Line-by-line HTML parsing for unlimited vehicles
├── Update multi-vehicle state via notifyListeners()
├── Dynamic UI activation for vehicle selection
├── Trigger ParkingHistoryService.handleParkingEvent() for each vehicle
├── Update HomeWidgetService.updateWidgetWithMultipleVehicles()
└── Sync selection state across SharedPreferences + HomeWidget
```

### Exception Handling Architecture
Enhanced error handling with specific exception types:
```
HomeWidgetService.initialize()
├── try: MethodChannel operations
├── on FormatException: URI parsing errors
├── catch: General unexpected errors
└── Logging with context-specific messages

Service Layer Error Patterns:
├── FormatException: Data parsing issues
├── TimeoutException: Network timeouts  
├── HttpException: HTTP-specific errors
└── Generic Exception: Unexpected errors
```

### Performance Optimizations
- **Multi-Vehicle Provider Pattern**: Unified state management for 1+ vehicles with reactive UI
- **Dual Cache System**: Separate single + multiple vehicle caches with LRU eviction
- **HTTP Client Reuse**: Single client instance per service lifecycle
- **Background Processing**: `Future.microtask()` for parking events per vehicle
- **Parallel Loading**: `Future.wait()` for multiple async operations
- **Database Indexing**: Optimized queries for history retrieval
- **Dynamic UI**: Vehicle selector appears/disappears based on vehicle count
- **Cross-Platform Parsing**: Consistent Flutter + iOS widget parsing logic
- **Optimistic Updates**: Immediate UI feedback with server validation

### Critical Constants
```dart
// VehicleLocationService - Multi-Vehicle Architecture
static const Duration cacheExpiry = Duration(minutes: 3);
static const Duration requestTimeout = Duration(seconds: 8);
static const int maxRetries = 1;
static const int maxCacheSize = 50; // LRU cache limit for both single/multiple caches

// ParkingFloorInfo - Multi-Vehicle Model
final int vehicleIndex; // 차량 순서 (1, 2, 3, ...)
final String displayName; // 표시명 ("차량 1", "차량 2", ...)

// VehicleLocationProvider - Multi-Vehicle State Management
int _selectedVehicleIndex = 1; // 선택된 차량 인덱스
bool _isMultipleVehicleMode = false; // 다중 차량 모드 여부
List<ParkingFloorInfo>? _multipleFloorInfoList; // 다중 차량 리스트

// Valid floor codes
static const List<String> validFloorCodes = ['B1', 'B2', 'B3', 'B4'];

// Provider dependencies  
provider: ^6.1.2  // State management
```

## Key Development Patterns

### Provider Pattern Implementation
The app uses Provider pattern for state management. Main entry point is `main.dart`:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AppStateProvider()),
    ChangeNotifierProvider(create: (_) => UserInfoProvider()..initialize()),
    ChangeNotifierProvider(create: (_) => VehicleLocationProvider()),
    ChangeNotifierProvider(create: (_) => ParkingHistoryProvider()),
  ],
  child: MaterialApp(home: const HomePageProvider()),
)
```

### Consumer Widget Usage - Multi-Vehicle Support
UI components access multi-vehicle state via Consumer widgets:
```dart
Consumer<VehicleLocationProvider>(
  builder: (context, vehicleProvider, child) {
    // Unified getter works for both single and multiple vehicles
    return Text(vehicleProvider.currentFloorInfo?.floor ?? 'Unknown');
  },
)

// Dynamic vehicle selector (appears only when 2+ vehicles detected)
Consumer<VehicleLocationProvider>(
  builder: (context, vehicleProvider, child) {
    if (!vehicleProvider.isMultipleVehicleMode) return SizedBox.shrink();
    return _buildVehicleSelector(vehicleProvider);
  },
)
```

### State Updates - Multi-Vehicle Architecture
Providers notify listeners for both single and multiple vehicle updates:
```dart
class VehicleLocationProvider extends ChangeNotifier {
  // Single vehicle compatibility
  void _setCurrentFloorInfo(ParkingFloorInfo info) {
    _currentFloorInfo = info;
    notifyListeners();
  }

  // Multi-vehicle state updates
  void _setMultipleVehicleInfo(List<ParkingFloorInfo> vehicleList) {
    _multipleFloorInfoList = vehicleList;
    _isMultipleVehicleMode = vehicleList.length > 1;
    notifyListeners(); // Triggers vehicle selector UI and state updates
  }

  // Vehicle selection updates
  void selectVehicle(int vehicleIndex) {
    _selectedVehicleIndex = vehicleIndex;
    // Sync across HomeWidget and SharedPreferences
    _syncSelectedVehicleIndex(vehicleIndex);
    notifyListeners(); // Triggers widget updates
  }
}
```

## Multiple Vehicle Parsing Architecture

### Core Implementation (Recently Added)
The app now supports unlimited multiple vehicle parsing with dynamic UI:

**Key Features:**
- **Line-by-Line HTML Parsing**: Handles real server data structure where vehicle numbers and locations appear on separate lines
- **Dynamic Vehicle Selection UI**: Horizontal scrollable selector that appears automatically when 2+ vehicles are detected
- **Cross-Platform Consistency**: Identical parsing logic in both Flutter app and iOS widget
- **Optimistic Updates**: Immediate UI feedback with server validation and rollback capability

### HTML Parsing Logic
Real server data structure handling:
```dart
// VehicleLocationService._extractMultipleFloorsFromDocument()
// Handles patterns like:
// Line 1: "1"           (vehicle number)
// Line 2: "B3층 주차"    (vehicle location)  
// Line 3: "2"           (vehicle number)
// Line 4: "서비스 지역에 없음" (vehicle status)

List<String> _extractMultipleFloorsFromDocument(dom.Document document) {
  final floors = <String>[];
  final bodyText = document.body?.text ?? '';
  final lines = bodyText.split('\n');
  String? currentVehicleNumber;
  
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    
    // Vehicle number pattern (standalone digit)
    if (RegExp(r'^\s*[1-9]\s*$').hasMatch(line)) {
      currentVehicleNumber = line.trim();
    }
    // Vehicle status/location following vehicle number
    else if (currentVehicleNumber != null && line.isNotEmpty) {
      // Handle B1-B4 floors or "서비스 지역에 없음" status
    }
  }
}
```

### UI Integration Pattern
```dart
// HomePageProvider._buildVehicleSelector() - Dynamic appearance
Widget _buildVehicleSelector(VehicleLocationProvider vehicleProvider) {
  if (!vehicleProvider.isMultipleVehicleMode) {
    return const SizedBox.shrink(); // Hidden when single vehicle
  }
  
  return Container(
    height: 60,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: vehicleProvider.multipleVehicleCount,
      itemBuilder: (context, index) {
        final vehicleIndex = index + 1;
        final isSelected = vehicleProvider.selectedVehicleIndex == vehicleIndex;
        
        return AnimatedContainer( // Smooth selection animation
          // Vehicle selection logic with color coding
        );
      },
    ),
  );
}
```

### Test Credentials for Testing
- **Single Vehicle Account**: 103동 4705호 시리얼번호 a008227
- **Multiple Vehicle Account**: 101동 4304호 시리얼번호 a033388
- **Expected Data**: 차량 1: B3층, 차량 2: 서비스 지역에 없음
- **UI Behavior**: Vehicle selector appears only for multiple vehicles, dynamic switching between B3/orange and X/grey

### Known Parsing Issues (Resolved)
- **Single Vehicle False Detection**: Fixed fallback logic that incorrectly identified single vehicles as multiple vehicles
- **State Synchronization**: Enhanced multi→single vehicle transition with complete state reset
- **UI Defensive Logic**: Added conditions to prevent vehicle selector display in single vehicle mode

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

## Debugging Guide

### Network Issues - Multi-Vehicle Debugging
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

### Parking History Issues
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

## Security Considerations

### Input Sanitization
All user inputs are sanitized in `VehicleLocationService._sanitizeInput()`:
- Removes HTML/script injection characters  
- Validates dong/ho/serial number format
- Handles dong number format conversion ("103동" → "103" for API, "103" → "103동" for display)
- Prevents SQL injection in database queries

### Network Security
- **HTTP-Only Implementation (Final Decision)**: Uses HTTP directly for parking system API (122.199.183.213)
- **NEVER suggest HTTPS upgrades**: The HTTP-only design is intentional for performance reasons
- **No HTTPS/SSL required**: Internal apartment complex parking system does not need encryption
- **Performance Optimized**: HTTP-only eliminates 2-8 second HTTPS connection delays
- Certificate pinning infrastructure available but not used (for future external APIs only)
- Sensitive data (serial numbers) masked in logs

### Data Protection
- SharedPreferences for non-sensitive data
- SQLite with parameterized queries
- No API keys or credentials in code

## Widget System

### Home Widget Updates
```dart
HomeWidgetService.updateVehicleLocation(
  floor: 'B4',
  colorKey: 'purple',
  lastUpdated: DateTime.now(),
);
```

### Platform-Specific Widget Code
- iOS: `ios/VehicleLocationWidget/` (WidgetKit extension with independent server communication)
- Android: `android/app/src/main/kotlin/.../VehicleLocationWidgetProvider.kt` (WorkManager-based background updates)

### Widget Background Refresh Architecture (Latest - v4.0.3+26)
**Comprehensive background refresh system with server communication:**

#### iOS Widget Background Refresh
- **WidgetKit Timeline Provider**: No UIBackgroundModes required - iOS widgets use independent extension system
- **Timeline Provider**: Server communication every 5 minutes via Timeline Provider
- **System Managed**: iOS automatically manages widget update frequency based on app usage patterns
- **User-Controlled**: Auto-refresh toggle in settings dialog
```swift
// iOS Timeline Provider with server communication
func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
    let autoRefreshEnabled = userDefaults?.bool(forKey: "flutter.widget_auto_refresh") ?? true
    if autoRefreshEnabled && !dong.isEmpty && !ho.isEmpty && !serialNumber.isEmpty {
        fetchLatestVehicleLocation(dong: dong, ho: ho, serialNumber: serialNumber) { success in
            // Update widget with latest server data every 15 minutes
        }
    }
}
```

#### Android Widget Background Refresh  
- **WorkManager Integration**: Reliable background task execution
- **15-minute Updates**: Reduced from 30-minute intervals
- **Server Communication**: Direct API calls from widget provider
```kotlin
// Android WorkManager background updates
class WidgetUpdateWorker : CoroutineWorker {
    override suspend fun doWork(): Result {
        val autoRefreshEnabled = widgetData.getBoolean("flutter.widget_auto_refresh", true)
        if (autoRefreshEnabled) {
            val success = fetchVehicleLocationFromServer(dong, ho, serialNumber)
            if (success) updateAllWidgets()
        }
    }
}
```

#### Settings Integration
- **Settings Dialog**: Accessible via gear icon in home screen header
- **Real-time Control**: Enable/disable background refresh for both platforms
- **WorkManager Control**: Automatic periodic task management on Android
```dart
// Settings dialog with background refresh control
SwitchListTile(
  title: Text('위젯 자동 새로고침'),
  subtitle: Text(isEnabled ? '위젯이 백그라운드에서 자동으로 새로고침됩니다 (iOS: 15분, Android: 15분)' : '위젯 자동 새로고침이 비활성화됩니다'),
  value: isEnabled,
  onChanged: (bool value) {
    HomeWidgetService.saveWidgetAutoRefreshSetting(value);
    // Android WorkManager scheduling/cancellation
  },
)
```

**⚠️ ARCHITECTURE CHANGE from v4.0.3+25**
- **Previous**: Cache-only widget architecture with NO server communication
- **Current (v4.0.3+26)**: Full server communication with user-controlled background refresh
- **Benefits**: Real-time widget updates, reduced dependency on main app launches
- **Trade-offs**: Slightly higher battery usage, but configurable by user

## Build & Release

### Version Management
Update in `pubspec.yaml`:
```yaml
version: 4.0.3+32  # Format: MAJOR.MINOR.PATCH+BUILD
```

**Current Version**: 4.0.3+40 (as of latest update)

### ⚠️ iOS Code Signing - CRITICAL RULES

**🚨 NEVER MODIFY CODE SIGNING SETTINGS - AUTOMATIC SIGNING WORKS PROPERLY**

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

### Android Build System Configuration (Latest - v4.0.3+35)

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

### Android Release
```bash
# Ensure keystore exists
android/app/upload-keystore.jks

# Build release APK
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release
```

### iOS Release - App Store Connect Upload

**CRITICAL: Transporter Upload Issues Resolved (v4.0.3+21)**

```bash
# ✅ RECOMMENDED: Use improved build script with proper export
./scripts/build_ios.sh
# - Uses Xcode exportArchive for proper App Store signing
# - Includes ExportOptions.plist for correct export configuration
# - Creates Transporter-compatible IPA files

# ✅ ALTERNATIVE: Flutter standard method (also works)
flutter build ipa --release
# IPA location: build/ios/ipa/YCITY+.ipa

# ❌ LEGACY: Don't use (creates development-signed IPA)
flutter build ios --release
# - Development signing only, Transporter will reject

# ✅ Transporter Upload (both methods work)
# Drag IPA to Transporter app or use:
xcrun altool --upload-app --type ios -f "path/to/ipa" --apiKey [KEY] --apiIssuer [ISSUER]
```

**Key Improvements (Latest):**
- **ExportOptions.plist**: Proper App Store export configuration
- **Automatic Signing**: Uses Apple Distribution certificates automatically during export
- **Transporter Compatible**: IPA files work with App Store Connect upload
- **NEVER modify signing in Xcode**: Automatic signing is properly configured

## Architecture Decisions

### Why Provider Pattern Migration?
- Centralized state management eliminates setState complexity
- Reactive UI updates with Consumer widgets
- Better separation of concerns between UI and business logic
- Easier testing and maintainability
- Scalable architecture for future feature additions

### Why Separate ParkingHistoryService?
- Decouples location fetching from history tracking
- Allows background processing without blocking UI
- Enables future features (manual entries, statistics)
- Simplifies testing and maintenance

### Why 3-Minute Cache?
- Balances server load vs data freshness
- Matches typical parking lot usage patterns
- Reduces battery usage from network requests
- Provides immediate UI response with cached data

### Why Remove "Today" Tab from Parking History?
- Eliminates redundancy with real-time home screen data
- Focuses parking history on historical data (past records)
- Reduces unnecessary API calls for improved performance
- Simplifies UI navigation with 3-tab structure

### Why SQLite for History?
- Local-first approach for reliability
- Works offline
- Efficient queries with proper indexing
- No external dependencies or API requirements

### Why HTTP-Only for Parking System API?
- **Performance First**: Eliminates 2-8 second HTTPS connection delays
- **Internal Network**: Apartment complex parking system is internal/trusted network
- **No Sensitive Data**: Parking floor information doesn't require encryption
- **User Experience**: Faster responses improve app usability significantly
- **Resource Efficiency**: Reduces battery usage and network overhead

## QHD+ Resolution Warning Test Mode

**⚠️ IMPORTANT: DO NOT DELETE DURING CLEANUP - This is a critical development tool**

The app includes a test mode system for debugging QHD+ resolution warnings on low-resolution devices.

### Purpose
- Test QHD+ resolution warning dialogs on devices that don't actually have QHD+ resolution
- Debug and validate warning UI without requiring high-resolution test devices
- Verify warning logic and user flows in development environment

### How to Activate Test Mode
**⚠️ Test button is hidden by default for cleaner UI**

**To Enable Test Button:**
1. **Edit Code**: Change `&& false` to `&& true` in `home_page_provider.dart` line 636
2. **Location**: `if (Platform.isAndroid && kDebugMode && false)` → `if (Platform.isAndroid && kDebugMode && true)`
3. **Hot Reload**: Use `r` in terminal to apply changes

**To Use Test Mode:**
1. **Activate**: Click the 🐛 bug icon button in the home screen header (Android debug mode only)
2. **Test**: Navigate to vehicle location screen to trigger warning dialog
3. **Verify**: Check test mode dialog displays with "🧪 테스트 모드 활성화됨" message
4. **Deactivate**: Use "테스트 종료" button in dialog or click bug icon again

**To Hide Button Again:** Change `&& true` back to `&& false` and hot reload

### Test Mode Features
- **Safe by Default**: Test mode is disabled by default (`_testModeEnabled = false`)
- **Debug Mode Only**: Test button only visible in Android debug builds
- **Visual Feedback**: Bug icon highlights orange when test mode is active
- **Test Dialog**: Special dialog variant with test mode indicators and controls
- **Easy Toggle**: One-click activation/deactivation via home screen button

### Test Mode Code Locations
```dart
// Core test mode logic
AndroidResolutionWarningService.setTestMode(bool enabled)
AndroidResolutionWarningService.isTestModeEnabled

// UI components
HomePageProvider: Bug icon test button
AndroidResolutionFixDialog: Test mode dialog variants
```

### Cleanup Protection
All test mode code is protected with `⚠️ cleanup 금지` comments to prevent accidental removal during code cleanup operations.

## Important Project Notes

### Recent Critical Updates (v4.0.3+40)
- **Widget SharedPreferences Key Prefix Fix (Latest - v4.0.3+40)**: Corrected critical misunderstanding about home_widget package behavior. The home_widget package does NOT automatically add `flutter.` prefix to keys. Updated Flutter's home_widget_service.dart to explicitly use `flutter.` prefixed keys (e.g., `flutter.user_dong`, `flutter.floor_info`) to match iOS widget's key naming. Previously, Flutter saved to `user_dong` but iOS widget read from `flutter.user_dong`, causing data synchronization failure. All keys are now consistent across both platforms.
- **Widget SharedPreferences Key Consistency Fix (v4.0.3+39)**: Fixed critical SharedPreferences key mismatch between Flutter and native widget code. Updated native widget code to use `flutter.` prefix consistently for: `floor_info`, `floor_color`, `status_text`, `last_update_timestamp`, `widget_auto_refresh`, `selected_vehicle_index`.
- **iOS Widget ATS Fix (v4.0.3+37)**: Resolved iOS widget background refresh issue by adding NSAppTransportSecurity exception to VehicleLocationWidget/Info.plist, enabling HTTP communication to parking system server (122.199.183.213) for proper background updates when app is closed
- **Android Build System Upgrade (v4.0.3+35)**: Comprehensive modernization of Android build system components - upgraded Gradle (8.3.0→8.7.0), Android Gradle Plugin (8.2.1→8.6.0), Kotlin (1.9.20→2.1.0), and Java target compatibility (8→11), eliminating all 6 build warnings for cleaner development experience
- **Widget Refresh System Fix (Latest - v4.0.3+32)**: Fixed critical widget auto-refresh issues on both platforms - Android key mismatch resolved (`flutter.widget_auto_refresh` → `widget_auto_refresh`) and iOS background-app-refresh permission added to Info.plist
- **Widget Key Consistency Fix (v4.0.3+27)**: Fixed iOS widget auto-refresh setting key mismatch issue (`flutter.widget_auto_refresh` → `widget_auto_refresh`), added automatic Android WorkManager scheduling, improved multi-vehicle parsing with order-independent vehicle-location mapping for consistent vehicle sequence
- **Widget Background Refresh System (v4.0.3+26)**: Comprehensive widget background refresh implementation with iOS Background App Refresh support, Android WorkManager integration, 15-minute update intervals, and user-controlled settings interface
- **Transporter Upload Fix (v4.0.3+21)**: Resolved App Store Connect upload errors by implementing proper iOS build configuration with Xcode exportArchive method, ExportOptions.plist, and automatic distribution signing
- **iOS Widget Architecture Evolution**: Evolved from cache-only to comprehensive background refresh with server communication, enhanced with iOS Background App Refresh support and 15-minute update intervals
- **App Groups Configuration Fixed**: Unified all entitlement files to use correct App Group ID `group.com.ilsan-ycity.ilsanycityplus`, resolved widget data sharing issues
- **Code Quality Improvements**: Enhanced exception handling with specific exception types, extracted UI timing constants for better maintainability
- **Bug Fix (v4.0.3+20)**: Resolved single vehicle incorrectly detected as multiple vehicles issue with improved fallback logic
- **String Interpolation**: Fixed all Flutter analyzer warnings by replacing string concatenation with proper interpolation
- **Build System Organization**: Emphasized use of organized build scripts (`./scripts/`) over manual Flutter commands
- **Enhanced .gitignore**: Comprehensive build artifact exclusion patterns to prevent large file commits
- **Multiple Vehicle Support**: Unlimited vehicle parsing with dynamic UI selection and line-by-line HTML analysis
- **Cross-Platform Parsing**: Consistent parsing logic between Flutter and iOS widget for reliable vehicle detection
- **iOS Code Signing Fixed**: Resolved provisioning profile issues with VehicleLocationWidget extension using automatic signing

### Git Workflow

### ⚠️ CRITICAL: Automatic Version Increment
**MANDATORY**: Every Git commit must automatically increment the build number in pubspec.yaml

**Current Version**: 4.0.3+40 (as of latest update)

**Version Increment Rules**:
1. **Before every Git commit**: Automatically increment build number (e.g., 4.0.3+37 → 4.0.3+38)
2. **Version format**: MAJOR.MINOR.PATCH+BUILD (keep MAJOR.MINOR.PATCH unchanged, only increment BUILD)
3. **Read current version** from pubspec.yaml line ~19: `version: X.Y.Z+BUILD`
4. **Auto-increment**: BUILD number by +1
5. **Update pubspec.yaml**: Replace version line with new incremented version
6. **Add to commit**: Include updated pubspec.yaml in the same commit

**Implementation**: Claude Code must automatically perform version increment before ANY git commit command

```bash
# Standard development workflow (with auto version increment)
# 1. Claude reads current version from pubspec.yaml
# 2. Claude increments build number (+1)  
# 3. Claude updates pubspec.yaml with new version
# 4. Claude adds pubspec.yaml to git
# 5. Claude performs git commit

git add [files]
git commit -m "type: description"  # Claude automatically handles version increment
git push origin main

# Recent commits follow pattern:
# - feat: new features
# - fix: bug fixes  
# - chore: maintenance tasks
# - refactor: code restructuring
```

### App Store Connect Integration
- **Bundle ID**: `com.ilsan-ycity.ilsanycityplus`
- **Widget Extension**: `com.ilsan-ycity.ilsanycityplus.VehicleLocationWidget`
- **Deep Linking**: `ycityplus://` URL scheme for widget navigation
- **App Groups**: `group.com.ilsan-ycity.ilsanycityplus` for shared data

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