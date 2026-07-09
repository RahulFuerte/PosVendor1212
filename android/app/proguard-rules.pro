# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Razorpay (kept in case re-integrated later)
-keepattributes *Annotation*
-dontwarn com.razorpay.**

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
