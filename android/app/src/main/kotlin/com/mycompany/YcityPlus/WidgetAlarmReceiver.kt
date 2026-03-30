package com.mycompany.YcityPlus

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.Executors
import java.util.regex.Pattern

/**
 * AlarmManager 기반 위젯 백그라운드 새로고침 Receiver
 * iOS와 유사하게 5분마다 서버에서 차량 위치를 가져와 위젯을 업데이트합니다.
 */
class WidgetAlarmReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "WidgetAlarmReceiver"
        private const val ACTION_REFRESH = "com.mycompany.YcityPlus.WIDGET_REFRESH"
        private const val REFRESH_INTERVAL_MS = 15 * 60 * 1000L // 15분

        /**
         * 15분마다 반복되는 알람 설정
         */
        fun scheduleAlarm(context: Context) {
            android.util.Log.d(TAG, "알람 스케줄링 시작 (15분 간격)")

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, WidgetAlarmReceiver::class.java).apply {
                action = ACTION_REFRESH
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            // 기존 알람 취소
            alarmManager.cancel(pendingIntent)

            // 5분마다 반복 알람 설정
            val triggerTime = SystemClock.elapsedRealtime() + REFRESH_INTERVAL_MS

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                // Doze 모드에서도 동작하도록 setExactAndAllowWhileIdle 사용
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    triggerTime,
                    pendingIntent
                )
            }

            android.util.Log.d(TAG, "다음 알람 예약됨: ${REFRESH_INTERVAL_MS / 1000}초 후")
        }

        /**
         * 알람 취소
         */
        fun cancelAlarm(context: Context) {
            android.util.Log.d(TAG, "알람 취소")

            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, WidgetAlarmReceiver::class.java).apply {
                action = ACTION_REFRESH
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                0,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            alarmManager.cancel(pendingIntent)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        android.util.Log.d(TAG, "알람 수신: ${intent.action}")

        when (intent.action) {
            ACTION_REFRESH, Intent.ACTION_BOOT_COMPLETED -> {
                // goAsync()로 BroadcastReceiver 생명주기 연장 (HTTP 완료까지 보장)
                val pendingResult = goAsync()
                Executors.newSingleThreadExecutor().execute {
                    try {
                        refreshWidgetData(context)
                        scheduleAlarm(context)
                    } finally {
                        pendingResult.finish()
                    }
                }
            }
        }
    }

    private fun refreshWidgetData(context: Context) {
        android.util.Log.d(TAG, "위젯 데이터 새로고침 시작")

        val widgetData = HomeWidgetPlugin.getData(context)
        val dong = widgetData.getString("flutter.user_dong", "") ?: ""
        val ho = widgetData.getString("flutter.user_ho", "") ?: ""
        val serialNumber = widgetData.getString("flutter.user_serial_number", "") ?: ""
        val autoRefreshEnabled = widgetData.getBoolean("flutter.widget_auto_refresh", true)

        android.util.Log.d(TAG, "사용자 정보: ${dong}동 ${ho}호, 자동새로고침: $autoRefreshEnabled")

        if (!autoRefreshEnabled) {
            android.util.Log.d(TAG, "자동 새로고침 비활성화됨, 스킵")
            return
        }

        if (dong.isEmpty() || ho.isEmpty() || serialNumber.isEmpty()) {
            android.util.Log.d(TAG, "사용자 정보 없음, 스킵")
            return
        }

        // 백그라운드 스레드에서 네트워크 요청
        Executors.newSingleThreadExecutor().execute {
            try {
                val baseUrl = "http://122.199.183.213/rtlsTag/main/action.do"
                val urlString = "$baseUrl?method=main.Main&dongId=$dong&hoId=$ho&serialId=$serialNumber"

                android.util.Log.d(TAG, "서버 요청: $urlString")

                val url = URL(urlString)
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 10000
                connection.readTimeout = 10000
                connection.setRequestProperty("Cache-Control", "no-cache")

                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val reader = BufferedReader(InputStreamReader(connection.inputStream))
                    val response = reader.use { it.readText() }

                    android.util.Log.d(TAG, "서버 응답 수신, HTML 길이: ${response.length}")

                    // 선택된 차량 인덱스 확인
                    val selectedVehicleIndex = widgetData.getInt("flutter.selected_vehicle_index", 1)

                    // HTML에서 층 정보 추출
                    val vehicleFloors = extractMultipleFloorsFromHTML(response)
                    val floorInfo = if (vehicleFloors.size >= selectedVehicleIndex) {
                        vehicleFloors[selectedVehicleIndex - 1]
                    } else {
                        if (vehicleFloors.isNotEmpty()) vehicleFloors[0] else extractFloorFromHTML(response)
                    }

                    val colorKey = getFloorColorKey(floorInfo)
                    val statusText = if (floorInfo == "출차됨") "출차됨" else "현재 차량 위치"

                    android.util.Log.d(TAG, "추출된 정보: $floorInfo ($colorKey)")

                    // SharedPreferences에 저장 (commit: 동기 쓰기로 위젯 업데이트 전 보장)
                    val editor = widgetData.edit()
                    editor.putString("flutter.floor_info", floorInfo)
                    editor.putString("flutter.floor_color", colorKey)
                    editor.putString("flutter.status_text", statusText)
                    editor.putLong("flutter.last_update_timestamp", System.currentTimeMillis())
                    editor.commit()

                    // 위젯 업데이트 트리거
                    updateAllWidgets(context)

                    android.util.Log.d(TAG, "위젯 업데이트 완료")
                } else {
                    android.util.Log.e(TAG, "서버 오류: HTTP $responseCode")
                }

                connection.disconnect()

            } catch (e: Exception) {
                android.util.Log.e(TAG, "네트워크 오류: ${e.message}")
            }
        }
    }

    private fun updateAllWidgets(context: Context) {
        try {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, VehicleLocationWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            android.util.Log.d(TAG, "위젯 업데이트 트리거: ${appWidgetIds.size}개")

            if (appWidgetIds.isNotEmpty()) {
                val intent = Intent(context, VehicleLocationWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, appWidgetIds)
                }
                context.sendBroadcast(intent)
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "위젯 업데이트 트리거 중 오류", e)
        }
    }

    // HTML 파싱 함수들 (VehicleLocationWidgetProvider와 동일)
    private fun extractMultipleFloorsFromHTML(html: String): List<String> {
        val vehicleLocationMap = mutableMapOf<Int, String>()
        val lines = html.split("\n")
        var currentVehicleNumber: String? = null

        for (i in lines.indices) {
            val line = lines[i].trim()

            if (line.matches("^\\s*[1-9]\\s*$".toRegex())) {
                currentVehicleNumber = line.trim()
            } else if (currentVehicleNumber != null && line.isNotEmpty()) {
                var floorInfo = ""

                if (line.contains("B[1-4]".toRegex())) {
                    val match = "B[1-4]".toRegex().find(line)
                    floorInfo = match?.value ?: ""
                } else if (line.contains("서비스 지역에 없음") ||
                           line.contains("서비스지역") ||
                           line.contains("지역에 없음")) {
                    floorInfo = "출차됨"
                } else if (line.contains("출차됨") ||
                           line.contains("출차") ||
                           line.contains("없음")) {
                    floorInfo = "출차됨"
                }

                if (floorInfo.isNotEmpty()) {
                    val vehicleNum = currentVehicleNumber.toIntOrNull()
                    if (vehicleNum != null) {
                        vehicleLocationMap[vehicleNum] = floorInfo
                    }
                }

                currentVehicleNumber = null
            }
        }

        return if (vehicleLocationMap.isNotEmpty()) {
            val sortedVehicles = vehicleLocationMap.keys.sorted()
            sortedVehicles.map { vehicleLocationMap[it] ?: "출차됨" }
        } else {
            listOf(extractFloorFromHTML(html))
        }
    }

    private fun extractFloorFromHTML(html: String): String {
        android.util.Log.d(TAG, "HTML 파싱 시작")

        // 1순위: carFloorNameArea 클래스에서 층 정보 추출 (가장 정확)
        val carFloorPattern = Pattern.compile("class=\"carFloorNameArea\"[^>]*>\\s*(B[1-4])\\s*<")
        val carFloorMatcher = carFloorPattern.matcher(html)
        if (carFloorMatcher.find()) {
            val floorCode = carFloorMatcher.group(1).uppercase()
            android.util.Log.d(TAG, "carFloorNameArea에서 층 정보 발견: $floorCode")
            return floorCode
        }

        // 2순위: td/span/div 태그 안에서 B1-B4만 있는 경우 (Flutter와 유사)
        val tagFloorPattern = Pattern.compile("<(?:td|span|div)[^>]*>\\s*(B[1-4])\\s*</(?:td|span|div)>", Pattern.CASE_INSENSITIVE)
        val tagMatcher = tagFloorPattern.matcher(html)
        if (tagMatcher.find()) {
            val floorCode = tagMatcher.group(1).uppercase()
            android.util.Log.d(TAG, "태그에서 층 정보 발견: $floorCode")
            return floorCode
        }

        // 3순위: 출차 관련 키워드 검색
        if (html.contains("서비스 지역에 없음") || html.contains("출차")) {
            android.util.Log.d(TAG, "출차 키워드 발견")
            return "출차됨"
        }

        android.util.Log.d(TAG, "층 정보를 찾을 수 없음, 출차됨으로 표시")
        return "출차됨"
    }

    private fun getFloorColorKey(floorCode: String): String {
        return when (floorCode) {
            "B1" -> "blue"
            "B2" -> "green"
            "B3" -> "orange"
            "B4" -> "purple"
            else -> "grey"
        }
    }
}
