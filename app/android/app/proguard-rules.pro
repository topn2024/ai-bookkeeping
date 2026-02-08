# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-dontwarn io.flutter.embedding.**

# Only keep classes that need JNI/reflection access (not all app classes)
-keep class com.example.ai_bookkeeping.SecureKeyStore { *; }
-keep class com.example.ai_bookkeeping.MainActivity { *; }
-keep class com.example.ai_bookkeeping.BsPatchHelper { *; }
-keep class com.example.ai_bookkeeping.GestureWakeHandler { *; }
-keep class com.example.ai_bookkeeping.PaymentNotificationListenerService { *; }
-keep class com.example.ai_bookkeeping.ScreenReaderService { *; }
-keep class com.example.ai_bookkeeping.VoiceWakeupService { *; }
-keep class com.example.ai_bookkeeping.QuickAddWidgetProvider { *; }
-keep class com.example.ai_bookkeeping.TodayStatsWidgetProvider { *; }

# Gson (if used)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# OkHttp (if used)
-dontwarn okhttp3.**
-dontwarn okio.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# Keep model classes (adjust package name as needed)
-keep class com.example.ai_bookkeeping.models.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom views
-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet);
}

-keepclasseswithmembers class * {
    public <init>(android.content.Context, android.util.AttributeSet, int);
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Keep Serializable implementations
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }
-keep class com.google.crypto.tink.** { *; }
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# Voice/Audio related
-keep class com.dooboolab.audiorecorder.** { *; }
-keep class com.konovalov.vad.** { *; }
-dontwarn com.konovalov.vad.**

# WebSocket
-keep class org.java_websocket.** { *; }
-dontwarn org.java_websocket.**

# HTTP Client
-keep class org.apache.http.** { *; }
-dontwarn org.apache.http.**

# Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-dontwarn kotlinx.coroutines.**

# Keep R8 from removing the debug information
-keepattributes SourceFile,LineNumberTable

# Keep annotations
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations
