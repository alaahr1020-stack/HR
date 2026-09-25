import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Owns the "free with ads / 30-day ad-free trial / 99 EGP lifetime unlock"
/// rules. Screens only ask [showAds] and call [buyRemoveAds].
class Monetization extends ChangeNotifier {
  static const _kFirstLaunch = 'first_launch_ms';
  static const _kPurchased = 'remove_ads_purchased';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  late SharedPreferences _prefs;

  DateTime _firstLaunch = DateTime.now();
  bool _purchased = false;
  bool _storeAvailable = false;
  bool _adsInitialized = false;
  ProductDetails? _product;
  String? lastError;
  bool busy = false;

  InterstitialAd? _interstitial;
  int _opensSinceAd = 0;

  bool get purchased => _purchased;
  DateTime get trialEnd =>
      _firstLaunch.add(const Duration(days: AppConfig.trialDays));
  bool get inTrial => DateTime.now().isBefore(trialEnd);
  int get trialDaysLeft {
    final left = trialEnd.difference(DateTime.now());
    return left.isNegative ? 0 : (left.inHours / 24).ceil();
  }

  bool get showAds => !_purchased && !inTrial;
  String get price => _product?.price ?? AppConfig.removeAdsFallbackPrice;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final first = _prefs.getInt(_kFirstLaunch);
    if (first == null) {
      await _prefs.setInt(_kFirstLaunch, _firstLaunch.millisecondsSinceEpoch);
    } else {
      _firstLaunch = DateTime.fromMillisecondsSinceEpoch(first);
    }
    _purchased = _prefs.getBool(_kPurchased) ?? false;

    // Store setup must never block app start-up.
    unawaited(_initStore());
    await _initAdsIfNeeded();
  }

  Future<void> _initStore() async {
    try {
      _storeAvailable = await _iap.isAvailable();
      if (!_storeAvailable) return;
      _sub = _iap.purchaseStream.listen(_onPurchases, onError: (Object e) {
        lastError = '$e';
        busy = false;
        notifyListeners();
      });
      final resp =
          await _iap.queryProductDetails({AppConfig.removeAdsProductId});
      if (resp.productDetails.isNotEmpty) _product = resp.productDetails.first;
      // Re-grants the unlock after reinstall or on a new phone.
      await _iap.restorePurchases();
      notifyListeners();
    } catch (e) {
      debugPrint('Store init failed: $e');
    }
  }

  Future<void> _initAdsIfNeeded() async {
    if (!showAds || _adsInitialized) return;
    try {
      await MobileAds.instance.initialize();
      _adsInitialized = true;
      _loadInterstitial();
    } catch (e) {
      debugPrint('Ads init failed: $e');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      if (p.productID != AppConfig.removeAdsProductId) continue;
      switch (p.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _setPurchased();
        case PurchaseStatus.error:
          lastError = p.error?.message ?? 'تعذر إتمام الشراء';
        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          break;
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
    busy = false;
    notifyListeners();
  }

  Future<void> _setPurchased() async {
    _purchased = true;
    await _prefs.setBool(_kPurchased, true);
    _interstitial?.dispose();
    _interstitial = null;
  }

  /// Returns false when the store is unavailable (e.g. no Google Play).
  Future<bool> buyRemoveAds() async {
    lastError = null;
    if (!_storeAvailable || _product == null) {
      lastError = 'المتجر غير متاح حالياً، حاول مرة أخرى لاحقاً';
      notifyListeners();
      return false;
    }
    busy = true;
    notifyListeners();
    return _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: _product!),
    );
  }

  Future<void> restore() async {
    if (!_storeAvailable) return;
    busy = true;
    notifyListeners();
    await _iap.restorePurchases();
    // restorePurchases may emit nothing when there is nothing to restore.
    Future.delayed(const Duration(seconds: 5), () {
      if (busy) {
        busy = false;
        notifyListeners();
      }
    });
  }

  void _loadInterstitial() {
    if (!showAds) return;
    InterstitialAd.load(
      adUnitId: AppConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  /// Call when the user opens a document; shows an interstitial every
  /// [AppConfig.interstitialEvery] opens.
  void onDocumentOpened() {
    if (!showAds) return;
    _opensSinceAd++;
    final ad = _interstitial;
    if (_opensSinceAd < AppConfig.interstitialEvery || ad == null) return;
    _opensSinceAd = 0;
    _interstitial = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _loadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _loadInterstitial();
      },
    );
    ad.show();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _interstitial?.dispose();
    super.dispose();
  }
}
