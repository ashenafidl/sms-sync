# WorkManager + Room — WorkDatabase_Impl is instantiated via reflection
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
-keep class androidx.work.impl.** { *; }
-dontwarn androidx.work.**

# Room — keep all Room database implementations
-keep class * extends androidx.room.RoomDatabase
-keep class * implements androidx.room.RoomDatabase$Singleton
-keep @androidx.room.Entity class * { *; }
