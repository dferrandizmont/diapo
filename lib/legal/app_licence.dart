import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The asset with the full GPL-3.0 text (the `LICENSE` file of the repository).
const String kAppLicenceAsset = 'LICENSE';

/// The licence notice (`NOTICE.md`): the GPL section 7 additional permission
/// for the Google Play libraries and the reserved name, icon and screenshots.
const String kAppNoticeAsset = 'NOTICE.md';

/// Diapo is free software under GPL-3.0-only with an additional permission.
///
/// Its own entry in the licences page carries only the notice (`NOTICE.md`):
/// Flutter's tool-generated entry for the root package (registered under the
/// package name `diapo`) already carries the full `LICENSE` text, so the two
/// are grouped into a single entry and the GPL text is not shown twice.
void registerAppLicence({AssetBundle? bundle}) {
  LicenseRegistry.addLicense(() async* {
    final assets = bundle ?? rootBundle;
    final notice = await assets.loadString(kAppNoticeAsset);
    yield LicenseEntryWithLineBreaks(['diapo'], notice);
  });
}
