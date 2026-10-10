# Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Flutter deferred components / Play Core (referenced but optional)
-dontwarn com.google.android.play.core.**

# Keep annotations, generics and line numbers for crash reports
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
-keepattributes SourceFile, LineNumberTable
-renamesourcefileattribute SourceFile

# Dio / OkHttp-style networking
-dontwarn okio.**
-dontwarn javax.annotation.**

# flutter_secure_storage (uses AndroidX security/crypto + Tink)
-keep class com.it_nomads.fluttersecurestorage.** { *; }
-keep class androidx.security.crypto.** { *; }
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.concurrent.**

# Kotlin
-dontwarn kotlin.**
-keep class kotlin.Metadata { *; }

# Strip verbose logging in release
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
}
