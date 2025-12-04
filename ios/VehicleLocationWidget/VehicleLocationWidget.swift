import WidgetKit
import SwiftUI
import Foundation
import os.log

// 위젯 전용 로거 (콘솔에서 확인 가능)
let widgetLogger = Logger(subsystem: "com.ilsan-ycity.ilsanycityplus.VehicleLocationWidget", category: "Widget")

struct VehicleLocationWidget: Widget {
    let kind: String = "VehicleLocationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            VehicleLocationWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("YCITY+ 주차 위치")
        .description("차량 주차 층 정보를 표시합니다")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), floorInfo: "B1", colorKey: "blue", statusText: "주차 위치")
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), floorInfo: "B1", colorKey: "blue", statusText: "주차 위치")
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.ilsan-ycity.ilsanycityplus")
        let currentTime = Date()

        // 새로고침 카운터 증가 및 저장 (flutter. 접두사 사용하여 Flutter에서 읽을 수 있도록)
        let refreshCount = (userDefaults?.integer(forKey: "flutter.widget_refresh_count") ?? 0) + 1
        userDefaults?.set(refreshCount, forKey: "flutter.widget_refresh_count")
        userDefaults?.set(currentTime.timeIntervalSince1970, forKey: "flutter.widget_last_refresh_time")
        userDefaults?.synchronize()

        // OS 로거 사용 (Console.app에서 확인 가능)
        widgetLogger.info("🔄 getTimeline 호출됨 (횟수: \(refreshCount))")
        widgetLogger.info("📅 현재 시간: \(currentTime.description)")

        // 디버그 로깅 추가
        print("[VehicleLocationWidget] ========================================")
        print("[VehicleLocationWidget] getTimeline 호출됨 (횟수: \(refreshCount))")
        print("[VehicleLocationWidget] 현재 시간: \(currentTime)")
        print("[VehicleLocationWidget] UserDefaults 생성됨: \(userDefaults != nil)")

        // 🔍 디버그: UserDefaults의 모든 키 출력
        if let allKeys = userDefaults?.dictionaryRepresentation() {
            print("[VehicleLocationWidget] 📋 UserDefaults 전체 키 목록 (\(allKeys.count)개):")
            for (key, value) in allKeys.sorted(by: { $0.key < $1.key }) {
                if key.contains("flutter") || key.contains("user") || key.contains("floor") || key.contains("widget") {
                    print("[VehicleLocationWidget]   - \(key): \(value)")
                }
            }
        }

        // 사용자 정보 조회 (백그라운드 새로고침용)
        let dong = userDefaults?.string(forKey: "flutter.user_dong") ?? ""
        let ho = userDefaults?.string(forKey: "flutter.user_ho") ?? ""
        let serialNumber = userDefaults?.string(forKey: "flutter.user_serial_number") ?? ""

        // 위젯 자동 새로고침 설정 확인 (flutter. 접두사 사용)
        let autoRefreshEnabled = userDefaults?.object(forKey: "flutter.widget_auto_refresh") as? Bool ?? true

        widgetLogger.info("👤 사용자 정보: \(dong)동 \(ho)호 \(serialNumber.isEmpty ? "(시리얼 없음)" : "***")")
        widgetLogger.info("⚙️ 자동 새로고침: \(autoRefreshEnabled ? "활성화" : "비활성화")")

        print("[VehicleLocationWidget] 자동 새로고침 설정: \(autoRefreshEnabled)")
        print("[VehicleLocationWidget] 사용자 정보: \(dong)동 \(ho)호 \(serialNumber)")
        
        // 백그라운드에서 서버 데이터 새로고침 시도
        if autoRefreshEnabled && !dong.isEmpty && !ho.isEmpty && !serialNumber.isEmpty {
            widgetLogger.info("🌐 서버 요청 시작...")

            fetchLatestVehicleLocation(dong: dong, ho: ho, serialNumber: serialNumber, userDefaults: userDefaults) { success in
                widgetLogger.info("📡 서버 응답: \(success ? "✅ 성공" : "❌ 실패")")
                print("[VehicleLocationWidget] 서버 새로고침 결과: \(success ? "성공" : "실패")")

                // 서버 요청 성공 여부 저장 (flutter. 접두사 사용)
                userDefaults?.set(success, forKey: "flutter.widget_last_fetch_success")
                userDefaults?.synchronize()

                // 최신 데이터로 위젯 업데이트 (flutter. 접두사 우선, 없으면 일반 키로 폴백)
                let floorInfo = userDefaults?.string(forKey: "flutter.floor_info") ?? userDefaults?.string(forKey: "floor_info") ?? "위치 정보 없음"
                let colorKey = userDefaults?.string(forKey: "flutter.floor_color") ?? userDefaults?.string(forKey: "floor_color") ?? "grey"
                let statusText = userDefaults?.string(forKey: "flutter.status_text") ?? userDefaults?.string(forKey: "status_text") ?? "차량 정보 없음"

                widgetLogger.info("📊 최종 데이터: \(floorInfo) (\(colorKey))")
                print("[VehicleLocationWidget] 최종 데이터:")
                print("[VehicleLocationWidget]   - floor_info: \(floorInfo)")
                print("[VehicleLocationWidget]   - floor_color: \(colorKey)")
                print("[VehicleLocationWidget]   - status_text: \(statusText)")

                var entry = SimpleEntry(
                    date: Date(),
                    floorInfo: floorInfo,
                    colorKey: colorKey,
                    statusText: statusText
                )
                entry.refreshCount = refreshCount
                entry.lastRefreshTime = currentTime
                entry.serverFetchSuccess = success

                // 5분마다 업데이트 (단축하여 더 자주 시도)
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
                widgetLogger.info("⏰ 다음 업데이트 예정: \(nextUpdate.description)")
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            }
        } else {
            if dong.isEmpty || ho.isEmpty || serialNumber.isEmpty {
                widgetLogger.warning("⚠️ 사용자 정보 없음 - 캐시 데이터만 사용")
                print("[VehicleLocationWidget] ⚠️ 사용자 정보가 비어있음! dong='\(dong)', ho='\(ho)', serial='\(serialNumber)'")
            }

            // 캐시된 데이터만 사용 (flutter. 접두사 우선, 없으면 일반 키로 폴백)
            let floorInfo = userDefaults?.string(forKey: "flutter.floor_info") ?? userDefaults?.string(forKey: "floor_info") ?? "위치 정보 없음"
            let colorKey = userDefaults?.string(forKey: "flutter.floor_color") ?? userDefaults?.string(forKey: "floor_color") ?? "grey"
            let statusText = userDefaults?.string(forKey: "flutter.status_text") ?? userDefaults?.string(forKey: "status_text") ?? "차량 정보 없음"

            widgetLogger.info("📦 캐시 데이터 사용: \(floorInfo) (\(colorKey))")
            print("[VehicleLocationWidget] 캐시된 데이터 사용:")
            print("[VehicleLocationWidget]   - floor_info: \(floorInfo)")
            print("[VehicleLocationWidget]   - floor_color: \(colorKey)")
            print("[VehicleLocationWidget]   - status_text: \(statusText)")

            var entry = SimpleEntry(
                date: Date(),
                floorInfo: floorInfo,
                colorKey: colorKey,
                statusText: statusText
            )
            entry.refreshCount = refreshCount
            entry.lastRefreshTime = currentTime
            entry.serverFetchSuccess = false

            // 5분마다 업데이트 (단축하여 더 자주 시도)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date()
            widgetLogger.info("⏰ 다음 업데이트 예정: \(nextUpdate.description)")
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

// 백그라운드에서 서버 데이터 새로고침 함수
func fetchLatestVehicleLocation(dong: String, ho: String, serialNumber: String, userDefaults: UserDefaults?, completion: @escaping (Bool) -> Void) {
    // API URL 구성
    let baseUrl = "http://122.199.183.213/rtlsTag/main/action.do"
    let urlString = "\(baseUrl)?method=main.Main&dongId=\(dong)&hoId=\(ho)&serialId=\(serialNumber)"
    
    guard let url = URL(string: urlString) else {
        print("[VehicleLocationWidget] 잘못된 URL: \(urlString)")
        completion(false)
        return
    }
    
    print("[VehicleLocationWidget] 서버 요청 시작: \(urlString)")
    
    // HTTP 요청 설정 (타임아웃 8초)
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.timeoutInterval = 8.0
    request.cachePolicy = .reloadIgnoringLocalCacheData
    
    // 네트워크 요청 수행
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("[VehicleLocationWidget] 네트워크 오류: \(error.localizedDescription)")
            completion(false)
            return
        }
        
        guard let data = data, let htmlString = String(data: data, encoding: .utf8) else {
            print("[VehicleLocationWidget] 데이터 파싱 실패")
            completion(false)
            return
        }
        
        print("[VehicleLocationWidget] 서버 응답 수신, HTML 길이: \(htmlString.count)")
        
        // HTML에서 층 정보 추출
        let floorInfo = extractFloorFromHTML(htmlString)
        let colorKey = getFloorColorKey(floorInfo)
        let statusText = floorInfo == "출차됨" ? "출차됨" : "현재 차량 위치"
        
        print("[VehicleLocationWidget] 추출된 정보: \(floorInfo) (\(colorKey))")
        
        // UserDefaults에 저장 (flutter. 접두사 사용하여 Flutter와 일관성 유지)
        userDefaults?.set(floorInfo, forKey: "flutter.floor_info")
        userDefaults?.set(colorKey, forKey: "flutter.floor_color")
        userDefaults?.set(statusText, forKey: "flutter.status_text")
        // 마지막 업데이트 시간 저장 (milliseconds)
        userDefaults?.set(Date().timeIntervalSince1970 * 1000, forKey: "flutter.last_update_timestamp")
        userDefaults?.synchronize()
        
        completion(true)
    }.resume()
}

// HTML에서 층 정보 추출
func extractFloorFromHTML(_ html: String) -> String {
    print("[VehicleLocationWidget] HTML 파싱 시작")
    
    // B1-B4 층 정보 패턴 검색
    let floorPattern = "(?i)B[1-4](?:층)?"
    if let regex = try? NSRegularExpression(pattern: floorPattern) {
        let range = NSRange(location: 0, length: html.count)
        if let match = regex.firstMatch(in: html, range: range) {
            let matchRange = Range(match.range, in: html)!
            var floorCode = String(html[matchRange])
            
            // "층" 제거하고 대문자로 정규화
            floorCode = floorCode.replacingOccurrences(of: "층", with: "").uppercased()
            
            print("[VehicleLocationWidget] 층 정보 발견: \(floorCode)")
            return floorCode
        }
    }
    
    // 출차 관련 키워드 검색
    let exitKeywords = ["출차", "서비스", "없음", "확인", "불가"]
    for keyword in exitKeywords {
        if html.contains(keyword) {
            print("[VehicleLocationWidget] 출차 키워드 발견: \(keyword)")
            return "출차됨"
        }
    }
    
    print("[VehicleLocationWidget] 층 정보를 찾을 수 없음, 출차됨으로 표시")
    return "출차됨"
}

func getFloorColorKey(_ floorCode: String) -> String {
    switch floorCode {
    case "B1":
        return "blue"
    case "B2":
        return "green"
    case "B3":
        return "orange"
    case "B4":
        return "purple"
    default:
        return "grey"
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let floorInfo: String
    let colorKey: String
    let statusText: String
    var refreshCount: Int = 0  // 새로고침 카운터 (디버그용)
    var lastRefreshTime: Date? = nil  // 마지막 새로고침 시간 (디버그용)
    var serverFetchSuccess: Bool = false  // 서버 요청 성공 여부 (디버그용)
}

struct VehicleLocationWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // 배경색 (완전 불투명)
            getFloorColor(entry.colorKey)
            
            if family == .systemMedium {
                // 큰 위젯: 층 정보 + 업데이트 시간
                VStack(spacing: 4) {
                    // 층 정보 (메인)
                    if entry.floorInfo == "출차됨" {
                        Text("X")
                            .font(.system(size: 36, weight: .black, design: .default))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    } else {
                        Text(entry.floorInfo)
                            .font(.system(size: 36, weight: .black, design: .default))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                    
                    // 마지막 업데이트 시간 (작은 텍스트)
                    Text(getTimeAgoText(entry.date))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            } else {
                // 작은 위젯: 기존 방식 (층 정보만)
                if entry.floorInfo == "출차됨" {
                    Text("X")
                        .font(.system(size: getResponsiveTextSize("X"), weight: .black, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                } else {
                    Text(entry.floorInfo)
                        .font(.system(size: getResponsiveTextSize(entry.floorInfo), weight: .black, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .widgetURL(URL(string: "ycityplus://vehicle_location"))
    }
    
    private func getFloorColor(_ colorKey: String) -> Color {
        switch colorKey {
        case "blue":
            return Color(red: 0x25/255.0, green: 0x63/255.0, blue: 0xEB/255.0) // blue-600
        case "green":
            return Color(red: 0x16/255.0, green: 0xA3/255.0, blue: 0x4A/255.0) // green-600
        case "orange":
            return Color(red: 0xEA/255.0, green: 0x58/255.0, blue: 0x0C/255.0) // orange-600
        case "purple":
            return Color(red: 0x93/255.0, green: 0x33/255.0, blue: 0xEA/255.0) // purple-600
        case "red":
            return Color(red: 0xDC/255.0, green: 0x26/255.0, blue: 0x26/255.0) // red-600
        default:
            return Color(red: 0x6B/255.0, green: 0x72/255.0, blue: 0x80/255.0) // gray-600
        }
    }
    
    /// 반응형 텍스트 크기 계산
    /// 텍스트 길이에 따라 폰트 크기를 동적으로 조정하여 위젯 크기에 맞춤
    private func getResponsiveTextSize(_ text: String) -> CGFloat {
        switch text.count {
        case 0...1:
            return 48.0  // "X", "B1" 등 짧은 텍스트
        case 2...3:
            return 42.0  // "B10" 등 중간 텍스트
        case 4...6:
            return 36.0  // "위치 정보" 등 긴 텍스트
        case 7...10:
            return 28.0  // "위치 확인 불가" 등 매우 긴 텍스트
        default:
            return 24.0  // 그 외 초장문 텍스트
        }
    }
    
    /// 마지막 업데이트 시간을 "몇 분 전" 형태로 변환
    private func getTimeAgoText(_ date: Date) -> String {
        // UserDefaults에서 실제 마지막 업데이트 시간 읽기 (flutter. 접두사 우선)
        let userDefaults = UserDefaults(suiteName: "group.com.ilsan-ycity.ilsanycityplus")
        let lastUpdateTimestamp = userDefaults?.double(forKey: "flutter.last_update_timestamp") ?? userDefaults?.double(forKey: "last_update_timestamp") ?? 0
        
        // timestamp가 0이면 정보 없음
        if lastUpdateTimestamp == 0 {
            return "정보 없음"
        }
        
        // milliseconds를 seconds로 변환
        let lastUpdateDate = Date(timeIntervalSince1970: lastUpdateTimestamp / 1000)
        let now = Date()
        let timeDifference = now.timeIntervalSince(lastUpdateDate)
        let minutes = Int(timeDifference / 60)
        
        if minutes < 1 {
            return "방금 전"
        } else if minutes < 60 {
            return "\(minutes)분 전"
        } else {
            let hours = minutes / 60
            return "\(hours)시간 전"
        }
    }
}
