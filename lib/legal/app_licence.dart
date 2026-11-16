import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The asset with the full GPL-3.0 text (the `LICENSE` file of the repository).
const String kAppLicenceAsset = 'LICENSE';

/// The licence notice (`NOTICE.md`): the GPL section 7 additional permission
/// for the Google Play libraries and the reserved name, icon and screenshots.
const String kAppNoticeAsset = 'NOTICE.md';

/// Diapo is free software under GPL-3.0-only with an additional permission:
/// its own entry in the licences page carries the notice and the full text,
/// both bundled as assets so they read offline.
void registerAppLicence({AssetBundle? bundle}) {
  LicenseRegistry.addLicense(() async* {
    final assets = bundle ?? rootBundle;
    final notice = await assets.loadString(kAppNoticeAsset);
    final licence = await assets.loadString(kAppLicenceAsset);
    yield LicenseEntryWithLineBreaks(['Diapo'], '$notice\n\n$licence');
  });
}
