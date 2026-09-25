import 'dart:io';

/// App-wide settings. Replace the AdMob IDs with your own before publishing
/// (the values below are Google's official *test* IDs).
class AppConfig {
  static const appName = 'دليل الموارد البشرية';

  /// Ad-free trial length after first install.
  static const trialDays = 30;

  /// Non-consumable product created in Google Play Console / App Store
  /// Connect, priced at 99 EGP.
  static const removeAdsProductId = 'remove_ads';
  static const removeAdsFallbackPrice = '99 جنيه';

  /// Show a full-screen ad once every N opened documents.
  static const interstitialEvery = 5;

  static String get bannerAdUnitId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/2934735716'
      : 'ca-app-pub-3940256099942544/6300978111';

  static String get interstitialAdUnitId => Platform.isIOS
      ? 'ca-app-pub-3940256099942544/4411468910'
      : 'ca-app-pub-3940256099942544/1033173712';
}
