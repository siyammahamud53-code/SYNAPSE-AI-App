# SYNAPSE AI ProGuard Rules
# Keep Flutter framework
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep custom classes
-keep class com.synapse.ai.** { *; }

# Keep serialization
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

# Keep Retrofit
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}
-keep @retrofit2.http.* class *

# Keep Gson
-keep class com.google.gson.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Keep Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep TensorFlow Lite
-keep class org.tensorflow.** { *; }
-keep class org.tensorflow.lite.** { *; }

# Keep CameraX
-keep class androidx.camera.** { *; }
-keep class androidx.camera.core.** { *; }

# Keep ML Kit
-keep class com.google.mlkit.** { *; }

# Keep Accessibility
-keep class android.accessibilityservice.** { *; }
-keep class android.view.accessibility.** { *; }

# Keep Telecom
-keep class android.telecom.** { *; }

# Keep System Services
-keep class android.app.** { *; }
-keep class android.content.** { *; }

# Keep Permissions
-keep class android.Manifest { *; }
-keep class android.Manifest$permission { *; }

# Remove debug code
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
    public static *** w(...);
    public static *** e(...);
}

# Optimize
-optimizationpasses 5
-dontskipnonpubliclibraryclassmembers
-printseeds seeds.txt
-printusage unused.txt
-printmapping mapping.txt

# Obfuscate
-repackageclasses 'com.synapse.ai'
-allowaccessmodification
-mergeinterfacesaggressively

# Flutter specific
-keep class io.flutter.app.FlutterActivity
-keep class io.flutter.embedding.android.FlutterActivity
-keep class io.flutter.embedding.android.FlutterFragmentActivity
-keep class io.flutter.embedding.android.FlutterView
-keep class io.flutter.plugin.common.MethodChannel
-keep class io.flutter.plugin.common.EventChannel
-keep class io.flutter.plugin.common.BasicMessageChannel

# Keep all Flutter plugins
-keep class * extends io.flutter.plugin.common.PluginRegistry.ActivityResultListener { *; }
-keep class * extends io.flutter.plugin.common.PluginRegistry.RequestPermissionsResultListener { *; }

# Dont warn about missing classes
-dontwarn javax.annotation.**
-dontwarn javax.inject.**
-dontwarn sun.misc.Unsafe
-dontwarn org.apache.commons.**
-dontwarn org.slf4j.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn kotlin.**

# Keep custom application class
-keep class com.synapse.ai.SynapseApplication { *; }

# Keep services
-keep class com.synapse.ai.services.AccessibilityService { *; }
-keep class com.synapse.ai.services.CallService { *; }
-keep class com.synapse.ai.services.ForegroundService { *; }

# Keep receivers
-keep class com.synapse.ai.receivers.BootReceiver { *; }
-keep class com.synapse.ai.receivers.ConnectivityReceiver { *; }

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Keep native libraries
-keep class com.synapse.ai.NativeLib { *; }
