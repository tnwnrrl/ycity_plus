package com.mycompany.YcityPlus

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import androidx.work.Data
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.ExistingPeriodicWorkPolicy
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern

/**
 * WorkManager 기반 백그라운드 위젯 업데이트 워커
 * 주기적으로 서버에서 차량 위치를 가져와 위젯을 업데이트합니다.
 */
class WidgetUpdateWorker(
    context: Context,
    workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {

    companion object {
        private const val WORK_NAME = "widget_update_work"
        private const val PERIODIC_WORK_NAME = "periodic_widget_update"
        
        /**
         * 즉시 위젯 업데이트 작업 예약
         */
        fun scheduleOneTimeUpdate(context: Context, dong: String, ho: String, serialNumber: String) {
            android.util.Log.d("WidgetUpdateWorker", "즉시 위젯 업데이트 작업 예약: ${dong}동 ${ho}호")
            
            val inputData = Data.Builder()
                .putString("dong", dong)
                .putString("ho", ho)
                .putString("serialNumber", serialNumber)
                .build()

            val workRequest = OneTimeWorkRequestBuilder<WidgetUpdateWorker>()
                .setInputData(inputData)
                .build()

            WorkManager.getInstance(context).enqueue(workRequest)
        }

        /**
         * 주기적 위젯 업데이트 작업 예약 (5분마다)
         */
        fun schedulePeriodicUpdates(context: Context, dong: String, ho: String, serialNumber: String) {
            android.util.Log.d("WidgetUpdateWorker", "주기적 위젯 업데이트 작업 예약: ${dong}동 ${ho}호 (5분마다)")
            
            val inputData = Data.Builder()
                .putString("dong", dong)
                .putString("ho", ho)
                .putString("serialNumber", serialNumber)
                .build()

            val workRequest = PeriodicWorkRequestBuilder<WidgetUpdateWorker>(15, TimeUnit.MINUTES)  // 최소 15분 간격 (Android 제한)
                .setInputData(inputData)
                .build()

            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(
                    PERIODIC_WORK_NAME,
                    ExistingPeriodicWorkPolicy.UPDATE,
                    workRequest
                )
        }

        /**
         * 주기적 위젯 업데이트 작업 취소
         */
        fun cancelPeriodicUpdates(context: Context) {
            android.util.Log.d("WidgetUpdateWorker", "주기적 위젯 업데이트 작업 취소")
            WorkManager.getInstance(context).cancelUniqueWork(PERIODIC_WORK_NAME)
        }
    }

    override suspend fun doWork(): Result {
        return try {
            android.util.Log.d("WidgetUpdateWorker", "백그라운드 위젯 업데이트 작업 시작")

            // SharedPreferences에서 최신 사용자 정보 읽기 (inputData는 스케줄 시점의 old 정보일 수 있음)
            val prefs = HomeWidgetPlugin.getData(applicationContext)
            val dong = prefs.getString("flutter.user_dong", "") ?: ""
            val ho = prefs.getString("flutter.user_ho", "") ?: ""
            val serialNumber = prefs.getString("flutter.user_serial_number", "") ?: ""

            if (dong.isEmpty() || ho.isEmpty() || serialNumber.isEmpty()) {
                android.util.Log.e("WidgetUpdateWorker", "사용자 정보가 불완전함: ${dong}동 ${ho}호 $serialNumber")
                return Result.failure()
            }
            
            // 위젯 자동 새로고침 설정 확인 (flutter. 접두사 사용)
            val widgetData = HomeWidgetPlugin.getData(applicationContext)
            val autoRefreshEnabled = widgetData.getBoolean("flutter.widget_auto_refresh", true)
            
            if (!autoRefreshEnabled) {
                android.util.Log.d("WidgetUpdateWorker", "위젯 자동 새로고침이 비활성화됨")
                return Result.success()
            }
            
            android.util.Log.d("WidgetUpdateWorker", "서버에서 차량 위치 데이터 가져오기 시도: ${dong}동 ${ho}호")
            
            // 서버에서 차량 위치 데이터 가져오기
            val success = fetchVehicleLocationFromServer(dong, ho, serialNumber)
            
            if (success) {
                // 위젯 업데이트 트리거
                updateAllWidgets()
                android.util.Log.d("WidgetUpdateWorker", "백그라운드 위젯 업데이트 성공")
                Result.success()
            } else {
                // 재시도 횟수 확인
                val retryCount = inputData.getInt("retry_count", 0)
                if (retryCount < 2) {  // 최대 2번 재시도
                    android.util.Log.w("WidgetUpdateWorker", "서버 데이터 가져오기 실패, 재시도 예정 (${retryCount + 1}/2)")
                    Result.retry()
                } else {
                    android.util.Log.e("WidgetUpdateWorker", "최대 재시도 횟수 초과, 실패 처리")
                    Result.failure()
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("WidgetUpdateWorker", "백그라운드 위젯 업데이트 중 오류", e)
            Result.failure()
        }
    }

    /**
     * 서버에서 차량 위치 데이터 가져오기
     */
    private suspend fun fetchVehicleLocationFromServer(
        dong: String,
        ho: String,
        serialNumber: String
    ): Boolean {
        return try {
            val baseUrl = "http://122.199.183.213/rtlsTag/main/action.do"
            val urlString = "$baseUrl?method=main.Main&dongId=$dong&hoId=$ho&serialId=$serialNumber"
            
            android.util.Log.d("WidgetUpdateWorker", "서버 요청: $urlString")
            
            val url = URL(urlString)
            val connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = 10000 // 10초 타임아웃 (WorkManager에서는 더 여유롭게)
            connection.readTimeout = 10000
            connection.setRequestProperty("Cache-Control", "no-cache")
            
            val responseCode = connection.responseCode
            if (responseCode == HttpURLConnection.HTTP_OK) {
                val reader = BufferedReader(InputStreamReader(connection.inputStream))
                val response = reader.use { it.readText() }
                
                android.util.Log.d("WidgetUpdateWorker", "서버 응답 수신, HTML 길이: ${response.length}")
                
                // 선택된 차량 인덱스 확인 (flutter. 접두사 사용)
                val updatedData = HomeWidgetPlugin.getData(applicationContext)
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
                
                android.util.Log.d("WidgetUpdateWorker", "다중차량 파싱 결과: $vehicleFloors")
                android.util.Log.d("WidgetUpdateWorker", "선택된 차량 $selectedVehicleIndex: $floorInfo")
                
                android.util.Log.d("WidgetUpdateWorker", "추출된 정보: $floorInfo ($colorKey)")
                
                // SharedPreferences에 저장 (commit: 동기 쓰기로 위젯 업데이트 전 보장)
                val widgetData = HomeWidgetPlugin.getData(applicationContext)
                val editor = widgetData.edit()
                editor.putString("flutter.floor_info", floorInfo)
                editor.putString("flutter.floor_color", colorKey)
                editor.putString("flutter.status_text", statusText)
                editor.putLong("flutter.last_update_timestamp", System.currentTimeMillis())
                editor.commit()
                
                connection.disconnect()
                true
            } else {
                android.util.Log.e("WidgetUpdateWorker", "서버 오류: HTTP $responseCode")
                connection.disconnect()
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("WidgetUpdateWorker", "네트워크 오류: ${e.message}")
            false
        }
    }

    /**
     * HTML에서 다중차량 층 정보 추출 (Flutter 로직과 동일)
     */
    private fun extractMultipleFloorsFromHTML(html: String): List<String> {
        android.util.Log.d("WidgetUpdateWorker", "다중차량 HTML 파싱 시작")
        
        val vehicleLocationMap = mutableMapOf<Int, String>()
        val lines = html.split("\n")
        var currentVehicleNumber: String? = null
        
        android.util.Log.d("WidgetUpdateWorker", "총 라인 수: ${lines.size}")
        
        for (i in lines.indices) {
            val line = lines[i].trim()
            
            if (line.isNotEmpty()) {
                android.util.Log.d("WidgetUpdateWorker", "라인 $i: \"$line\"")
            }
            
            // 차량 번호 패턴 찾기 (단독 숫자)
            if (line.matches("^\\s*[1-9]\\s*$".toRegex())) {
                currentVehicleNumber = line.trim()
                android.util.Log.d("WidgetUpdateWorker", "차량 번호 발견: $currentVehicleNumber (라인 $i)")
            }
            // 차량 번호가 있는 상태에서 층 정보 또는 상태 찾기
            else if (currentVehicleNumber != null && line.isNotEmpty()) {
                var floorInfo = ""
                
                android.util.Log.d("WidgetUpdateWorker", "차량 ${currentVehicleNumber}의 상태 라인 분석: \"$line\"")
                
                // B1-B4 층 정보 확인
                if (line.contains("B[1-4]".toRegex())) {
                    val match = "B[1-4]".toRegex().find(line)
                    floorInfo = match?.value ?: ""
                    android.util.Log.d("WidgetUpdateWorker", "차량 $currentVehicleNumber: B층 정보 감지 \"$floorInfo\"")
                }
                // "서비스 지역에 없음" 상태 확인
                else if (line.contains("서비스 지역에 없음") || 
                         line.contains("서비스지역") || 
                         line.contains("지역에 없음")) {
                    floorInfo = "출차됨"
                    android.util.Log.d("WidgetUpdateWorker", "차량 $currentVehicleNumber: 출차 상태 감지")
                }
                // 기타 "출차됨" 관련 키워드
                else if (line.contains("출차됨") || 
                         line.contains("출차") || 
                         line.contains("없음")) {
                    floorInfo = "출차됨"
                    android.util.Log.d("WidgetUpdateWorker", "차량 $currentVehicleNumber: 출차 키워드 감지")
                }
                
                if (floorInfo.isNotEmpty()) {
                    val vehicleNum = currentVehicleNumber.toIntOrNull()
                    if (vehicleNum != null) {
                        vehicleLocationMap[vehicleNum] = floorInfo
                        android.util.Log.d("WidgetUpdateWorker", "차량 $vehicleNum: $floorInfo → Map에 저장")
                    }
                } else {
                    android.util.Log.d("WidgetUpdateWorker", "차량 $currentVehicleNumber: 빈 결과로 인해 무시됨")
                }
                
                currentVehicleNumber = null // 다음 차량을 위해 초기화
            }
        }
        
        // Map을 차량 번호 순으로 정렬하여 일관된 순서 보장
        val result = if (vehicleLocationMap.isNotEmpty()) {
            val sortedVehicles = vehicleLocationMap.keys.sorted()
            sortedVehicles.map { vehicleLocationMap[it] ?: "출차됨" }
        } else {
            android.util.Log.d("WidgetUpdateWorker", "다중차량 파싱 실패, 단일차량 파싱으로 폴백")
            // 다중차량 파싱 실패 시 단일차량 파싱으로 폴백
            listOf(extractFloorFromHTML(html))
        }
        
        android.util.Log.d("WidgetUpdateWorker", "다중차량 파싱 최종 결과: $result")
        return result
    }
    
    /**
     * HTML에서 층 정보 추출 (단일차량 폴백용)
     */
    private fun extractFloorFromHTML(html: String): String {
        android.util.Log.d("WidgetUpdateWorker", "HTML 파싱 시작")

        // 1순위: carFloorNameArea 클래스에서 층 정보 추출 (가장 정확)
        val carFloorPattern = Pattern.compile("class=\"carFloorNameArea\"[^>]*>\\s*(B[1-4])\\s*<")
        val carFloorMatcher = carFloorPattern.matcher(html)
        if (carFloorMatcher.find()) {
            val floorCode = carFloorMatcher.group(1).uppercase()
            android.util.Log.d("WidgetUpdateWorker", "carFloorNameArea에서 층 정보 발견: $floorCode")
            return floorCode
        }

        // 2순위: td/span/div 태그 안에서 B1-B4만 있는 경우 (Flutter와 유사)
        val tagFloorPattern = Pattern.compile("<(?:td|span|div)[^>]*>\\s*(B[1-4])\\s*</(?:td|span|div)>", Pattern.CASE_INSENSITIVE)
        val tagMatcher = tagFloorPattern.matcher(html)
        if (tagMatcher.find()) {
            val floorCode = tagMatcher.group(1).uppercase()
            android.util.Log.d("WidgetUpdateWorker", "태그에서 층 정보 발견: $floorCode")
            return floorCode
        }

        // 3순위: 출차 관련 키워드 검색
        if (html.contains("서비스 지역에 없음") || html.contains("출차")) {
            android.util.Log.d("WidgetUpdateWorker", "출차 키워드 발견")
            return "출차됨"
        }

        android.util.Log.d("WidgetUpdateWorker", "층 정보를 찾을 수 없음, 출차됨으로 표시")
        return "출차됨"
    }

    /**
     * 층 코드에 따른 색상 키 반환
     */
    private fun getFloorColorKey(floorCode: String): String {
        return when (floorCode) {
            "B1" -> "blue"
            "B2" -> "green"
            "B3" -> "orange"
            "B4" -> "purple"
            else -> "grey"
        }
    }

    /**
     * 모든 위젯 업데이트 (broadcast 방식: 직접 호출 시 내부 HTTP 스레드가 doWork 완료 후 죽는 문제 방지)
     */
    private fun updateAllWidgets() {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(applicationContext)
            val componentName = ComponentName(applicationContext, VehicleLocationWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            android.util.Log.d("WidgetUpdateWorker", "위젯 업데이트 트리거: ${appWidgetIds.size}개 위젯")

            if (appWidgetIds.isNotEmpty()) {
                val intent = Intent(applicationContext, VehicleLocationWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                }
                applicationContext.sendBroadcast(intent)
            }
        } catch (e: Exception) {
            android.util.Log.e("WidgetUpdateWorker", "위젯 업데이트 트리거 중 오류", e)
        }
    }
}