# R8 / ProGuard rules for the release build.
#
# Keep these minimal and justified. Every over-broad `-keep` costs binary size
# and hides a genuine reflection problem rather than fixing it.

# Flutter engine and plugin registration happen through reflection.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Kotlin metadata, used by reflection in some plugins.
-keep class kotlin.Metadata { *; }

# When Firebase lands, its own consumer rules ship inside the artifacts and are
# applied automatically. Do NOT pre-emptively add broad -keep rules for it here;
# add only what a real release-build crash proves is needed.
