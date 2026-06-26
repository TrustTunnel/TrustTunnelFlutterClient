# adg_share

`adg_share` is a local Flutter plugin for opening the native share UI on Android and iOS.

The package provides:

- typed share request models
- text, URI, and file payload support
- Android `ACTION_SEND` / `ACTION_SEND_MULTIPLE`
- iOS `UIActivityViewController`
- file name override support for shared files
- iPad share origin support through `sharePositionOrigin`

## Supported platforms

| Platform | Status |
| --- | --- |
| Android | Supported |
| iOS | Supported |
| Web | Not implemented |
| macOS | Not implemented |
| Windows | Not implemented |
| Linux | Not implemented |

## Usage

```dart
import 'dart:ui';

import 'package:adg_share/adg_share.dart';

final result = await const AdgShare().share(
  ShareRequest(
    content: const [
      ShareText('Hello from AdGuard Mail Team!'),
      ShareUri(Uri.parse('https://adguard.com')),
    ],
    subject: 'Share example',
    chooserTitle: 'Send with',
    sharePositionOrigin: const Rect.fromLTWH(120, 240, 1, 1),
    excludedTargets: const [ShareTarget.airDrop],
  ),
);

switch (result) {
  case ShareSuccess():
    // Native share sheet was opened and completed.
  case ShareDismissed():
    // The user closed the sheet without completing the share.
  case ShareUnavailable():
    // Sharing is not available on the current platform.
  case ShareFailure(:final error):
    // Validation or platform mapping failed.
}
```

## File sharing

Use `ShareFile` to share files by path:

```dart
final result = await const AdgShare().share(
  ShareRequest(
    content: const [
      ShareFile(
        path: '/tmp/report.pdf',
        mimeType: 'application/pdf',
        fileNameOverride: 'mail-report.pdf',
      ),
    ],
  ),
);
```

If `fileNameOverride` is passed, the package creates a temporary copy with the desired display name before opening the native share UI.

## Notes

- `ShareTarget` exclusions are currently applied only on iOS.
- The package reports whether the native share sheet was shown or dismissed, but it does not confirm delivery to the target app.
- Unsupported or missing platform implementations are surfaced as `ShareFailure` with the underlying implementation error.
