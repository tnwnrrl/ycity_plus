package com.mycompany.YcityPlus

import android.content.Context
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

/**
 * 백그라운드 조회에서 본 차량별 층 변화를 앱이 나중에 주차 기록에 반영하도록 쌓아 두는 대기열
 *
 * 형식은 Flutter 의 BackgroundParkingEventService 와 같다:
 * flutter.parking_event_queue = [{"t": 밀리초, "u": "동|호|시리얼", "v": 차량 순서, "f": "B1"|"출차됨"}]
 * 여기서는 대기열에 덧붙이기만 하고, 앱은 flutter.parking_event_cursor 에 반영한 위치만 쓴다.
 */
object ParkingEventQueue {
    private const val TAG = "ParkingEventQueue"
    private const val QUEUE_KEY = "flutter.parking_event_queue"
    private const val CURSOR_KEY = "flutter.parking_event_cursor"
    private const val MAX_EVENTS = 200

    private val rowSplitter = "tagLocationAction(".toRegex(RegexOption.LITERAL)
    private val carNumberPattern = "class=\"carNameArea\">\\s*(\\d+)\\s*<".toRegex()
    private val carFloorPattern = "class=\"carFloorNameArea\">\\s*([^<]*?)\\s*<".toRegex()
    private val floorCodePattern = "^B[1-4]$".toRegex(RegexOption.IGNORE_CASE)

    /**
     * 서버 HTML 의 차량 행(tagLocationAction)마다 차량 번호와 층을 읽는다.
     * 층을 확실히 읽지 못한 차량은 빼서, 잘못된 출차가 기록되지 않게 한다.
     */
    fun parseVehicleFloors(html: String): Map<Int, String> {
        val result = sortedMapOf<Int, String>()
        // 행 하나는 다음 </tr> 까지 (마지막 행이 페이지 끝 스크립트 문구까지 포함하지 않도록)
        val rows = html.split(rowSplitter).drop(1).map { it.substringBefore("</tr>") }
        rows.forEachIndexed { index, row ->
            val vehicle = carNumberPattern.find(row)?.groupValues?.get(1)?.toIntOrNull() ?: (index + 1)
            val floorText = carFloorPattern.find(row)?.groupValues?.get(1)?.trim() ?: ""
            val floor = when {
                floorCodePattern.matches(floorText) -> floorText.uppercase()
                row.contains("없음") -> "출차됨"
                else -> null
            }
            if (floor != null) result[vehicle] = floor
        }
        return result
    }

    /** 서버 응답에서 읽은 층이 직전 대기 기록과 다르면 대기열에 덧붙인다 */
    fun record(context: Context, dong: String, ho: String, serialNumber: String, html: String) {
        try {
            val floors = parseVehicleFloors(html)
            if (floors.isEmpty()) {
                android.util.Log.d(TAG, "차량 행을 읽지 못해 기록하지 않음")
                return
            }

            val prefs = HomeWidgetPlugin.getData(context)
            val cursor = prefs.getString(CURSOR_KEY, null)?.toLongOrNull() ?: 0L
            val existing = try {
                JSONArray(prefs.getString(QUEUE_KEY, "[]"))
            } catch (e: Exception) {
                JSONArray()
            }

            // 앱이 이미 반영한 항목은 버린다
            val pending = mutableListOf<JSONObject>()
            for (i in 0 until existing.length()) {
                val event = existing.optJSONObject(i) ?: continue
                if (event.optLong("t") > cursor) pending.add(event)
            }

            val userKey = "$dong|$ho|$serialNumber"
            val now = System.currentTimeMillis()
            var appended = 0
            floors.forEach { (vehicle, floor) ->
                val lastFloor = pending.lastOrNull {
                    it.optString("u") == userKey && it.optInt("v") == vehicle
                }?.optString("f")
                if (lastFloor != floor) {
                    pending.add(JSONObject().put("t", now).put("u", userKey).put("v", vehicle).put("f", floor))
                    appended++
                }
            }

            if (appended == 0 && pending.size == existing.length()) return

            val trimmed = JSONArray()
            pending.takeLast(MAX_EVENTS).forEach { trimmed.put(it) }
            prefs.edit().putString(QUEUE_KEY, trimmed.toString()).commit()
            android.util.Log.d(TAG, "층 변화 ${appended}건 기록 (대기 ${trimmed.length()}건): $floors")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "대기열 기록 실패", e)
        }
    }
}
