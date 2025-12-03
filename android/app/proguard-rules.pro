# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keep class * extends java.util.ListResourceBundle { protected Object[][] getContents(); }
-keep class * extends android.app.Service
-keep class * extends android.content.BroadcastReceiver

# Timezone
-keep class tzdata.** { *; }

# Device Info Plus
-keep class com.example.device_info_plus.** { *; }

# Manter métodos de callback
-keepclasseswithmembernames class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Manter métodos nativos
-keepclasseswithmembers class * {
    native <methods>;
}