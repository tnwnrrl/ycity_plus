# Flutter 앱용 ProGuard 규칙

# Flutter 엔진 및 런타임 유지
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Google Play Core 라이브러리 유지
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Dart 관련 클래스 유지
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# HTTP 통신 관련 유지
-keep class okhttp3.** { *; }
-keep class retrofit2.** { *; }
-dontwarn okhttp3.**
-dontwarn retrofit2.**

# JSON 직렬화 유지
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# WebView 관련 유지
-keep class android.webkit.JavascriptInterface
-keep class * {
    @android.webkit.JavascriptInterface <methods>;
}

# SQLite 관련 유지
-keep class io.flutter.plugins.sqflite.** { *; }

# 디버깅을 위한 라인 번호 유지
-keepattributes SourceFile,LineNumberTable