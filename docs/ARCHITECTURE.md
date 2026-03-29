# Architecture Documentation

This document describes the architecture and design patterns used in the YCity Plus application.

## Provider State Management Architecture

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

## Service Layer Architecture

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

## Database Schema (v2)

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

## Key Implementation Patterns

### Multi-Vehicle Provider Architecture

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

## Provider Pattern Implementation

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

### Core Implementation

The app supports unlimited multiple vehicle parsing with dynamic UI:

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

## Widget System Architecture

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

### Widget Background Refresh Architecture (v4.0.3+26)

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
