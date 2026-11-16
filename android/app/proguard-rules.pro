# Keep the app's native channel entry points and camera sound implementation.
# Dispatch uses channel/method strings, not Kotlin reflection; these explicit
# boundaries cover carrete/media, carrete/media/pixels and carrete/system.
-keep,allowoptimization class io.github.dferrandizmont.carrete.MainActivity { *; }
-keep,allowoptimization class io.github.dferrandizmont.carrete.MediaChannel { *; }
-keep,allowoptimization class io.github.dferrandizmont.carrete.CameraSounds { *; }

# Preserve the EXIF API used by the media channel; internal helpers may shrink.
-keep,allowoptimization class androidx.exifinterface.media.ExifInterface { public *; }

# flutter_local_notifications 22.3.2 uses Gson 2.12.0, whose embedded gson.pro
# keeps Signature, annotations, TypeToken and its anonymous subclasses in R8
# full mode. The plugin's notification models carry AndroidX @Keep, preserving
# JSON fields and style names across updates and reboot rescheduling.
# Do not duplicate those consumer rules or keep the entire plugin/Gson package.
#
# flutter_secure_storage, camera_android_camerax, sensors_plus and
# image_picker_android register directly through GeneratedPluginRegistrant;
# their channel handlers need no extra reflection rules. CameraX supplies its
# own consumer rules for Camera2Config.DefaultProvider and quirks.
