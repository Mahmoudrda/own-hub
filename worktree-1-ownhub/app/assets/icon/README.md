# Drop the app icon master here

Required: `icon-1024.png` — exactly 1024x1024, PNG, **no alpha channel**, no
transparency, no rounded corners. Apple rejects an icon with alpha; both
platforms apply their own mask, so baking in corners looks wrong.

Optional: `icon-foreground.png` for the Android adaptive icon. Keep the artwork
inside the middle ~66% or the launcher will crop it.

Then follow the three steps in the `flutter_launcher_icons` comment at the
bottom of `pubspec.yaml`.

`tool/release_preflight.sh` fails until `icon-1024.png` is here.
