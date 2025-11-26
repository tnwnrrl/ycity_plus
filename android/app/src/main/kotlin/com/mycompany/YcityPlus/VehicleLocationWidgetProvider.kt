package com.mycompany.YcityPlus

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.regex.Pattern

class VehicleLocationWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        android.util.Log.d("VehicleLocationWidget", "onUpdate 호출됨 - 위젯 개수: ${appWidgetIds.size}")
        
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    private fun updateAppWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        try {
            android.util.Log.d("VehicleLocationWidget", "updateAppWidget 호출됨")
            
            // SharedPreferences에서 사용자 정보 및 설정 읽기
            val widgetData = HomeWidgetPlugin.getData(context)
            val dong = widgetData.getString("flutter.user_dong", "") ?: ""
            val ho = widgetData.getString("flutter.user_ho", "") ?: ""
            val serialNumber = widgetData.getString("flutter.user_serial_number", "") ?: ""
            val autoRefreshEnabled = widgetData.getBoolean("flutter.widget_auto_refresh", true)
            
            android.util.Log.d("VehicleLocationWidget", "자동 새로고침 설정: $autoRefreshEnabled")
            android.util.Log.d("VehicleLocationWidget", "사용자 정보: ${dong}동 ${ho}호 $serialNumber")
            
            // 백그라운드에서 서버 데이터 새로고침 시도
            if (autoRefreshEnabled && dong.isNotEmpty() && ho.isNotEmpty() && serialNumber.isNotEmpty()) {
                fetchLatestVehicleLocation(context, dong, ho, serialNumber) { success ->
                    android.util.Log.d("VehicleLocationWidget", "서버 새로고침 결과: ${if (success) "성공" else "실패"}")
                    
                    // 최신 데이터로 위젯 업데이트 (flutter. 접두사 우선, 없으면 일반 키로 폴백)
                    val updatedData = HomeWidgetPlugin.getData(context)
                    val floorInfo = updatedData.getString("flutter.floor_info", null) ?: updatedData.getString("floor_info", "위치 정보 없음") ?: "위치 정보 없음"
                    val colorKey = updatedData.getString("flutter.floor_color", null) ?: updatedData.getString("floor_color", "grey") ?: "grey"
                    
                    android.util.Log.d("VehicleLocationWidget", "최종 데이터:")
                    android.util.Log.d("VehicleLocationWidget", "  - floor_info: $floorInfo")
                    android.util.Log.d("VehicleLocationWidget", "  - floor_color: $colorKey")
                    
                    displayWidgetContent(context, appWidgetManager, appWidgetId, floorInfo, colorKey)
                }
            } else {
                // 캐시된 데이터만 사용 (flutter. 접두사 우선, 없으면 일반 키로 폴백)
                val floorInfo = widgetData.getString("flutter.floor_info", null) ?: widgetData.getString("floor_info", "위치 정보 없음") ?: "위치 정보 없음"
                val colorKey = widgetData.getString("flutter.floor_color", null) ?: widgetData.getString("floor_color", "grey") ?: "grey"
                
                android.util.Log.d("VehicleLocationWidget", "캐시된 데이터 사용:")
                android.util.Log.d("VehicleLocationWidget", "  - floor_info: $floorInfo")
                android.util.Log.d("VehicleLocationWidget", "  - floor_color: $colorKey")
                
                displayWidgetContent(context, appWidgetManager, appWidgetId, floorInfo, colorKey)
            }
            
        } catch (e: Exception) {
            android.util.Log.e("VehicleLocationWidget", "위젯 업데이트 중 오류", e)
            
            // 오류 시 기본 위젯 표시
            val views = RemoteViews(context.packageName, R.layout.vehicle_location_widget)
            views.setTextViewText(R.id.floor_text, "오류")
            views.setTextColor(R.id.floor_text, Color.GRAY)
            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    // 백그라운드에서 서버 데이터 새로고침 함수
    private fun fetchLatestVehicleLocation(
        context: Context,
        dong: String,
        ho: String,
        serialNumber: String,
        callback: (Boolean) -> Unit
    ) {
        // 백그라운드 스레드에서 네트워크 요청 수행
        Executors.newSingleThreadExecutor().execute {
            try {
                // API URL 구성
                val baseUrl = "http://122.199.183.213/rtlsTag/main/action.do"
                val urlString = "$baseUrl?method=main.Main&dongId=$dong&hoId=$ho&serialId=$serialNumber"
                
                android.util.Log.d("VehicleLocationWidget", "서버 요청 시작: $urlString")
                
                val url = URL(urlString)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 8000 // 8초 타임아웃
                connection.readTimeout = 8000
                connection.setRequestProperty("Cache-Control", "no-cache")
                
                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val reader = BufferedReader(InputStreamReader(connection.inputStream))
                    val response = reader.use { it.readText() }
                    
                    android.util.Log.d("VehicleLocationWidget", "서버 응답 수신, HTML 길이: ${response.length}")
                    
                    // 선택된 차량 인덱스 확인 (flutter. 접두사 사용)
                    val updatedData = HomeWidgetPlugin.getData(context)
                    val selectedVehicleIndex = updatedData.getInt("flutter.selected_vehicle_index", 1)
                    
                    // HTML에서 다중차량 층 정보 추출
                    val vehicleFloors = extractMultipleFloorsFromHTML(response)
                    val floorInfo = if (vehicleFloors.size >= selectedVehicleIndex) {
                        vehicleFloors[selectedVehicleIndex - 1] // 0-based 인덱스로 변환
                    } else {
                        // 선택된 차량이 없으면 첫 번째 차량 또는 단일차량 파싱
                        if (vehicleFloors.isNotEmpty()) vehicleFloors[0] else extractFloorFromHTML(response)
                    }
                    
                    val colorKey = getFloorColorKey(floorInfo)
                    val statusText = if (floorInfo == "출차됨") "출차됨" else "현재 차량 위치"
                    
                    android.util.Log.d("VehicleLocationWidget", "다중차량 파싱 결과: $vehicleFloors")
                    android.util.Log.d("VehicleLocationWidget", "선택된 차량 $selectedVehicleIndex: $floorInfo")
                    
                    android.util.Log.d("VehicleLocationWidget", "추출된 정보: $floorInfo ($colorKey)")
                    
                    // SharedPreferences에 저장 (flutter. 접두사 사용하여 Flutter와 일관성 유지)
                    val widgetData = HomeWidgetPlugin.getData(context)
                    val editor = widgetData.edit()
                    editor.putString("flutter.floor_info", floorInfo)
                    editor.putString("flutter.floor_color", colorKey)
                    editor.putString("flutter.status_text", statusText)
                    // 마지막 업데이트 시간 저장
                    editor.putLong("flutter.last_update_timestamp", System.currentTimeMillis())
                    editor.apply()
                    
                    callback(true)
                } else {
                    android.util.Log.e("VehicleLocationWidget", "서버 오류: HTTP $responseCode")
                    callback(false)
                }
                
                connection.disconnect()
                
            } catch (e: Exception) {
                android.util.Log.e("VehicleLocationWidget", "네트워크 오류: ${e.message}")
                callback(false)
            }
        }
    }
    
    // HTML에서 다중차량 층 정보 추출 (Flutter 로직과 동일)
    private fun extractMultipleFloorsFromHTML(html: String): List<String> {
        android.util.Log.d("VehicleLocationWidget", "다중차량 HTML 파싱 시작")
        
        val vehicleLocationMap = mutableMapOf<Int, String>()
        val lines = html.split("\n")
        var currentVehicleNumber: String? = null
        
        android.util.Log.d("VehicleLocationWidget", "총 라인 수: ${lines.size}")
        
        for (i in lines.indices) {
            val line = lines[i].trim()
            
            if (line.isNotEmpty()) {
                android.util.Log.d("VehicleLocationWidget", "라인 $i: \"$line\"")
            }
            
            // 차량 번호 패턴 찾기 (단독 숫자)
            if (line.matches("^\\s*[1-9]\\s*$".toRegex())) {
                currentVehicleNumber = line.trim()
                android.util.Log.d("VehicleLocationWidget", "차량 번호 발견: $currentVehicleNumber (라인 $i)")
            }
            // 차량 번호가 있는 상태에서 층 정보 또는 상태 찾기
            else if (currentVehicleNumber != null && line.isNotEmpty()) {
                var floorInfo = ""
                
                android.util.Log.d("VehicleLocationWidget", "차량 ${currentVehicleNumber}의 상태 라인 분석: \"$line\"")
                
                // B1-B4 층 정보 확인
                if (line.contains("B[1-4]".toRegex())) {
                    val match = "B[1-4]".toRegex().find(line)
                    floorInfo = match?.value ?: ""
                    android.util.Log.d("VehicleLocationWidget", "차량 $currentVehicleNumber: B층 정보 감지 \"$floorInfo\"")
                }
                // "서비스 지역에 없음" 상태 확인
                else if (line.contains("서비스 지역에 없음") || 
                         line.contains("서비스지역") || 
                         line.contains("지역에 없음")) {
                    floorInfo = "출차됨"
                    android.util.Log.d("VehicleLocationWidget", "차량 $currentVehicleNumber: 출차 상태 감지")
                }
                // 기타 "출차됨" 관련 키워드
                else if (line.contains("출차됨") || 
                         line.contains("출차") || 
                         line.contains("없음")) {
                    floorInfo = "출차됨"
                    android.util.Log.d("VehicleLocationWidget", "차량 $currentVehicleNumber: 출차 키워드 감지")
                }
                
                if (floorInfo.isNotEmpty()) {
                    val vehicleNum = currentVehicleNumber.toIntOrNull()
                    if (vehicleNum != null) {
                        vehicleLocationMap[vehicleNum] = floorInfo
                        android.util.Log.d("VehicleLocationWidget", "차량 $vehicleNum: $floorInfo → Map에 저장")
                    }
                } else {
                    android.util.Log.d("VehicleLocationWidget", "차량 $currentVehicleNumber: 빈 결과로 인해 무시됨")
                }
                
                currentVehicleNumber = null // 다음 차량을 위해 초기화
            }
        }
        
        // Map을 차량 번호 순으로 정렬하여 일관된 순서 보장
        val result = if (vehicleLocationMap.isNotEmpty()) {
            val sortedVehicles = vehicleLocationMap.keys.sorted()
            sortedVehicles.map { vehicleLocationMap[it] ?: "출차됨" }
        } else {
            android.util.Log.d("VehicleLocationWidget", "다중차량 파싱 실패, 단일차량 파싱으로 폴백")
            // 다중차량 파싱 실패 시 단일차량 파싱으로 폴백
            listOf(extractFloorFromHTML(html))
        }
        
        android.util.Log.d("VehicleLocationWidget", "다중차량 파싱 최종 결과: $result")
        return result
    }
    
    // HTML에서 층 정보 추출 (단일차량 폴백용)
    private fun extractFloorFromHTML(html: String): String {
        android.util.Log.d("VehicleLocationWidget", "HTML 파싱 시작")
        
        // B1-B4 층 정보 패턴 검색
        val floorPattern = Pattern.compile("(?i)B[1-4](?:층)?", Pattern.CASE_INSENSITIVE)
        val matcher = floorPattern.matcher(html)
        
        if (matcher.find()) {
            var floorCode = matcher.group()
            // "층" 제거하고 대문자로 정규화
            floorCode = floorCode.replace("층", "").uppercase()
            
            android.util.Log.d("VehicleLocationWidget", "층 정보 발견: $floorCode")
            return floorCode
        }
        
        // 출차 관련 키워드 검색
        val exitKeywords = arrayOf("출차", "서비스", "없음", "확인", "불가")
        for (keyword in exitKeywords) {
            if (html.contains(keyword)) {
                android.util.Log.d("VehicleLocationWidget", "출차 키워드 발견: $keyword")
                return "출차됨"
            }
        }
        
        android.util.Log.d("VehicleLocationWidget", "층 정보를 찾을 수 없음, 출차됨으로 표시")
        return "출차됨"
    }
    
    // 층 코드에 따른 색상 키 반환
    private fun getFloorColorKey(floorCode: String): String {
        return when (floorCode) {
            "B1" -> "blue"
            "B2" -> "green"
            "B3" -> "orange"
            "B4" -> "purple"
            else -> "grey"
        }
    }
    
    // 위젯 내용 표시 함수
    private fun displayWidgetContent(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        floorInfo: String,
        colorKey: String
    ) {
        // RemoteViews 생성
        val views = RemoteViews(context.packageName, R.layout.vehicle_location_widget)
        
        // 층별 색상 설정 (완전 불투명 배경)
        val color = getFloorColor(colorKey)
        views.setInt(R.id.widget_background, "setBackgroundColor", color)
        
        // 출차됨인 경우 X 텍스트로 표시, 아니면 층 정보
        if (floorInfo == "출차됨") {
            views.setTextViewText(R.id.floor_text, "X")
            views.setTextColor(R.id.floor_text, Color.WHITE)
            views.setFloat(R.id.floor_text, "setTextSize", getResponsiveTextSize("X"))
        } else {
            views.setTextViewText(R.id.floor_text, floorInfo)
            views.setTextColor(R.id.floor_text, Color.WHITE)
            views.setFloat(R.id.floor_text, "setTextSize", getResponsiveTextSize(floorInfo))
        }

        // 위젯 크기 확인 및 업데이트 시간 표시 (큰 위젯에서만)
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
        
        // 큰 위젯인 경우 (대략 2x1 크기 이상)
        if (minWidth >= 180 && minHeight >= 80) {
            // 마지막 업데이트 시간 표시
            val lastUpdateTime = getLastUpdateTime(context)
            views.setTextViewText(R.id.update_time_text, lastUpdateTime)
            views.setViewVisibility(R.id.update_time_text, android.view.View.VISIBLE)
            android.util.Log.d("VehicleLocationWidget", "큰 위젯 감지 (${minWidth}x${minHeight}) - 업데이트 시간 표시: $lastUpdateTime")
        } else {
            // 작은 위젯인 경우 업데이트 시간 숨김
            views.setViewVisibility(R.id.update_time_text, android.view.View.GONE)
            android.util.Log.d("VehicleLocationWidget", "작은 위젯 감지 (${minWidth}x${minHeight}) - 업데이트 시간 숨김")
        }

        // 위젯 클릭 시 앱 실행 액션 설정
        val intentUri = Uri.parse("ycityplus://vehicle_location")
        val intent = Intent(Intent.ACTION_VIEW, intentUri)
        intent.setPackage(context.packageName)
        
        val pendingIntent = PendingIntent.getActivity(
            context,
            appWidgetId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        views.setOnClickPendingIntent(R.id.widget_background, pendingIntent)
        
        // 위젯 업데이트
        appWidgetManager.updateAppWidget(appWidgetId, views)
    }
    
    private fun getFloorColor(colorKey: String): Int {
        return when (colorKey) {
            "blue" -> Color.parseColor("#2563EB")     // blue-600
            "green" -> Color.parseColor("#16A34A")    // green-600
            "orange" -> Color.parseColor("#EA580C")   // orange-600
            "purple" -> Color.parseColor("#9333EA")   // purple-600
            "red" -> Color.parseColor("#DC2626")      // red-600
            else -> Color.parseColor("#6B7280")       // gray-600
        }
    }

    /**
     * 반응형 텍스트 크기 계산
     * 텍스트 길이에 따라 폰트 크기를 동적으로 조정하여 위젯 크기에 맞춤
     */
    private fun getResponsiveTextSize(text: String): Float {
        return when {
            text.length <= 1 -> 48f          // "X", "B1" 등 짧은 텍스트
            text.length <= 3 -> 42f          // "B10" 등 중간 텍스트  
            text.length <= 6 -> 36f          // "위치 정보" 등 긴 텍스트
            text.length <= 10 -> 28f         // "위치 확인 불가" 등 매우 긴 텍스트
            else -> 24f                      // 그 외 초장문 텍스트
        }
    }
    
    /**
     * 마지막 업데이트 시간을 "몇 분 전" 형태로 계산
     */
    private fun getLastUpdateTime(context: Context): String {
        val widgetData = HomeWidgetPlugin.getData(context)
        // flutter. 접두사 우선, 없으면 일반 키로 폴백
        var lastUpdateTimestamp = widgetData.getLong("flutter.last_update_timestamp", 0L)
        if (lastUpdateTimestamp == 0L) {
            lastUpdateTimestamp = widgetData.getLong("last_update_timestamp", 0L)
        }
        
        // timestamp가 0이면 정보 없음
        if (lastUpdateTimestamp == 0L) {
            return "정보 없음"
        }
        
        val currentTime = System.currentTimeMillis()
        val timeDifference = currentTime - lastUpdateTimestamp
        val minutes = (timeDifference / (1000 * 60)).toInt()
        
        return when {
            minutes < 1 -> "방금 전"
            minutes < 60 -> "${minutes}분 전"
            else -> {
                val hours = minutes / 60
                "${hours}시간 전"
            }
        }
    }
}