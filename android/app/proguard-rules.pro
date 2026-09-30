# Chainway DeviceAPI & RFID/Barcode SDK
-keep class com.rscja.** { *; }
-keep interface com.rscja.** { *; }
-dontwarn com.rscja.**

# Zebra / OEM peripherals
-keep class com.zebra.** { *; }
-keep interface com.zebra.** { *; }
-dontwarn com.zebra.**

# App native and MainActivity
-keep class com.segel.possible_recovery.** { *; }

# Flutter JNI and plugins
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**

# Mobile scanner / ML Kit
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.* { *; }
-keep class com.google.android.libraries.barhopper.* { *; }
-keep class com.google.photos.* { *; }
-keepclassmembers class * extends java.lang.Enum {
    <fields>;
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Preserve JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
}
