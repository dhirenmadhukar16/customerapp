# =========================================================
# REQUIRED CLASS METADATA
# =========================================================

-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod


# =========================================================
# FLUTTER
# Flutter and plugins normally provide their own R8 rules.
# Do not keep every Flutter class because it disables shrinking.
# =========================================================

-dontwarn io.flutter.embedding.**
-dontwarn io.flutter.plugins.**


# =========================================================
# DIO / OKHTTP / OKIO
# Dio itself is implemented in Dart.
# Avoid blanket keep rules for OkHttp.
# =========================================================

-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**


# =========================================================
# WEBVIEW JAVASCRIPT BRIDGE
# Required when payment/webview integrations expose methods
# through @JavascriptInterface.
# =========================================================

-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

-keepattributes JavascriptInterface


# =========================================================
# RAZORPAY
# Keep this only if Razorpay SDK is still included and used.
# =========================================================

-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }


# =========================================================
# GOOGLE PLAY CORE
# Suppress optional deferred-component warnings.
# Do not keep every Play Core class.
# =========================================================

-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication


# =========================================================
# HTML/PDF SUPPORT
# =========================================================

-dontwarn org.ccil.cowan.tagsoup.**


# =========================================================
# ENUMS USED THROUGH REFLECTION
# =========================================================

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}