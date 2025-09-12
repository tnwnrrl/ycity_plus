package com.mycompany.YcityPlus

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val WIDGET_CLICK_CHANNEL = "ycityplus/widget_click"
    private val WORK_MANAGER_CHANNEL = "ycityplus/workmanager"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // MethodChannel 설정
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            // 위젯 클릭 이벤트 처리
            MethodChannel(messenger, WIDGET_CLICK_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "getWidgetClickIntent" -> {
                        val uri = intent?.data?.toString()
                        result.success(uri)
                    }
                    else -> result.notImplemented()
                }
            }
            
            // WorkManager 백그라운드 업데이트 처리
            MethodChannel(messenger, WORK_MANAGER_CHANNEL).setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleOneTimeUpdate" -> {
                        val dong = call.argument<String>("dong") ?: ""
                        val ho = call.argument<String>("ho") ?: ""
                        val serialNumber = call.argument<String>("serialNumber") ?: ""
                        
                        if (dong.isNotEmpty() && ho.isNotEmpty() && serialNumber.isNotEmpty()) {
                            WidgetUpdateWorker.scheduleOneTimeUpdate(this, dong, ho, serialNumber)
                            result.success(true)
                        } else {
                            result.error("INVALID_PARAMS", "사용자 정보가 불완전합니다", null)
                        }
                    }
                    "schedulePeriodicUpdates" -> {
                        val dong = call.argument<String>("dong") ?: ""
                        val ho = call.argument<String>("ho") ?: ""
                        val serialNumber = call.argument<String>("serialNumber") ?: ""
                        
                        if (dong.isNotEmpty() && ho.isNotEmpty() && serialNumber.isNotEmpty()) {
                            WidgetUpdateWorker.schedulePeriodicUpdates(this, dong, ho, serialNumber)
                            result.success(true)
                        } else {
                            result.error("INVALID_PARAMS", "사용자 정보가 불완전합니다", null)
                        }
                    }
                    "cancelPeriodicUpdates" -> {
                        WidgetUpdateWorker.cancelPeriodicUpdates(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        
        // 위젯 클릭으로 인한 앱 시작 처리
        handleWidgetClick()
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleWidgetClick()
    }
    
    private fun handleWidgetClick() {
        android.util.Log.d("MainActivity", "handleWidgetClick() 호출됨")
        
        intent?.data?.let { uri ->
            android.util.Log.d("MainActivity", "🎯 위젯 클릭 URI 수신: $uri")
            
            if (uri.toString().startsWith("ycityplus://vehicle_location")) {
                android.util.Log.d("MainActivity", "✅ 차량위치 URL 스킴 확인됨 - Flutter에 이벤트 전달")
                
                // 위젯 클릭으로 앱이 시작되었음을 SharedPreferences에 저장
                val sharedPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
                sharedPrefs.edit().apply {
                    putBoolean("flutter.widget_launched_app", true)
                    putLong("flutter.widget_launch_time", System.currentTimeMillis())
                    apply()
                }
                android.util.Log.d("MainActivity", "💾 위젯 클릭 시작 플래그 저장 완료")
                
                // Flutter에 위젯 클릭 이벤트 전달
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    android.util.Log.d("MainActivity", "📢 Flutter 엔진 확인됨 - MethodChannel 호출")
                    MethodChannel(messenger, WIDGET_CLICK_CHANNEL)
                        .invokeMethod("onWidgetClicked", uri.toString())
                    android.util.Log.d("MainActivity", "🚀 Flutter에 onWidgetClicked 이벤트 전달 완료")
                } ?: run {
                    android.util.Log.e("MainActivity", "❌ Flutter 엔진이 null임 - 이벤트 전달 불가")
                }
            } else {
                android.util.Log.d("MainActivity", "❌ 인식되지 않는 URL 스킴: ${uri.toString()}")
            }
        } ?: run {
            android.util.Log.d("MainActivity", "Intent data가 null임 - 위젯 클릭이 아님")
        }
    }
}
