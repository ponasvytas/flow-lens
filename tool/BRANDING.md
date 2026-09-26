# Updating the app logo

Edit `assets/logo.svg` in Inkscape. Keep a transparent 1024 x 1024 page, with the
artwork centered inside approximately 896 x 896. Save the SVG; manual PNG exports
are unnecessary. Exporting the *drawing* instead of the *page* discards page padding.

The script makes a clean `assets/branding/logo.svg` copy without Inkscape editor
metadata. The toolbar loads that SVG through `FlowLogo`, with a light-purple color filter
on its dark background. Its 30px canvas includes the master padding, leaving
approximately 26px of visible artwork. Other callers can use the widget's theme
default or an explicit color. `flutter_svg` is a normal app dependency.

## Generate all configured icons on Windows

The existing `.local/logo-venv` already has Pillow. On a fresh checkout, create a
Python environment and install `Pillow>=11,<13` (also in `tool/requirements-logo.txt`).
Flutter/Dart must be on PATH; run `flutter pub get` after pulling dependencies.

With Inkscape open, run from the repository root in PowerShell:

```powershell
$inkscapePath = Get-Process inkscape | Select-Object -First 1 -ExpandProperty Path
.local/logo-venv/Scripts/python.exe tool/update_branding.py --inkscape "$inkscapePath"
```

Alternatively pass the installed executable's full path, set the `INKSCAPE`
environment variable, or put `inkscape` on PATH. For a conventional installation:

```powershell
.local/logo-venv/Scripts/python.exe tool/update_branding.py --inkscape "C:/Program Files/Inkscape/bin/inkscape.exe"
```

The script does not modify the master SVG. It exports the page with Inkscape,
derives platform artwork with Pillow, invokes `dart run flutter_launcher_icons`,
then applies web-specific variants and a Windows ICO with multiple sizes.
It makes no Azure image-generation calls. Generated assets belong in Git.

| Output | Treatment |
| --- | --- |
| `assets/logo-transparent.png` | 1024px page export, preserving master margins |
| `assets/branding/logo.svg` | Clean vector copy for Flutter, same geometry as the master |
| `assets/branding/launcher.png` | 740px artwork on opaque white, legacy Android/iOS/Apple touch |
| `assets/branding/android-foreground.png` | 440px artwork on transparent 1024px canvas, fitting the 66/108 safe circle |
| `assets/branding/android-monochrome.png` | Same geometry and padding, monochrome for Android themed icons |
| `assets/branding/ios-dark.png` | Light-purple mark, transparent background |
| `assets/branding/ios-tinted.png` | White mark on black, grayscale input for system tinting |
| `assets/branding/macos.png` | Purple mark on an inset white rounded tile, transparent outer margin |
| `web/favicon.svg` | Transparent vector, light-purple fill in dark browser appearance |
| `web/favicon.png` | Transparent 32px fallback |
| `web/icons/Icon-192.png`, `Icon-512.png` | Transparent regular PWA icons |
| `web/icons/Icon-maskable-*.png` | Opaque white, artwork within the central 80% safe circle |
| `web/icons/apple-touch-icon.png` | Separate opaque 180px Apple touch icon |
| `windows/runner/resources/app_icon.ico` | Transparent 16/24/32/48/64/128/256px images |

The package generates Android resources and Apple asset catalogs from the inputs
configured in `pubspec.yaml`. The script checks image transparency, Android safe
bounds, Windows sizes, and all iOS catalog references and dimensions. A comparison
sheet is saved to `.local/branding-preview.png`; orange circles are preview guides,
not part of the assets.

Always use this script for a full refresh. Running `dart run flutter_launcher_icons`
alone overwrites the web maskable variants and multi-size Windows ICO with generic
outputs. The SVG favicon responds to the browser's preferred color scheme; the
PNG fallback retains the purple mark. Neither has a baked-in background.

## Verification

```powershell
cmd /c dart format lib test
cmd /c flutter analyze
cmd /c flutter test test/phone_workspace_test.dart
cmd /c flutter build web
```

Restart the app after dependency/asset changes. Refresh the browser; favicon and
installed-app icon caches may require closing the tab or reinstalling the PWA.
The in-app SVG scales on Linux too; Linux desktop packaging is not configured by
`flutter_launcher_icons` and is separate from these generated targets.

## Apple Liquid Glass on a Mac

The generated iOS catalog contains conventional default, dark and tinted variants.
It is ready for checking in Xcode, but this Windows workflow cannot validate an
iOS/macOS build or create a layered Liquid Glass icon.

On a Mac with Xcode 26 or newer, import the master SVG into Icon Composer, configure
the background and material/layer properties, and preview the appearance variants.
Save the `.icon` document into the native project and set up the Runner target to
use it according to Xcode's Icon Composer workflow. Open `ios/Runner.xcworkspace`
for the Flutter iOS project and validate on a simulator/device. Retain the raster
catalog as needed for deployment targets and fallback behavior. Once the Icon
Composer integration is in place, review/disable this generator's iOS setting so
future runs do not reset the Runner app-icon selection.
