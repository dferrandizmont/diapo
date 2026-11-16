/// The version of the app, as in `version:` of `pubspec.yaml` without the
/// build number. It is a constant so the app needs no plugin to show it; a
/// test keeps the two in step.
const String kAppVersion = '0.1.1';

/// The App Store id of the app, for opening its page from the settings. iOS has
/// no id yet (the app is not in the App Store), so the "Rate" row is hidden on
/// iOS while this is null. Set it when the listing exists.
const String? kAppStoreId = null;
