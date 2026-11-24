# flutter_local_notifications uses Gson with generic types to store scheduled notifications.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class com.dexterous.** { *; }
-keep class com.ryanheise.** { *; }
