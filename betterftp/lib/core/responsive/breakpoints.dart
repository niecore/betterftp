import 'package:flutter/widgets.dart';

/// Responsive breakpoints used across the app.
///
/// Centralising the thresholds here gives us a single source of
/// truth for "what counts as a tablet?" and "what counts as a
/// compact-height phone?". Adjust the numbers below to retune the
/// whole app at once.
extension ResponsiveContext on BuildContext {
  /// Material's canonical tablet test. iPhone Pro Max tops out at
  /// 428pt wide; iPad Mini is 744pt. Anything ≥ 600 is the tablet
  /// family (iPad Mini, iPad, iPad Pro 11"/13", and Android tablets
  /// like the Galaxy Tab line).
  bool get isTablet => MediaQuery.sizeOf(this).shortestSide >= 600;

  /// Compact-height phones — iPhone SE 1st/2nd/3rd gen (667pt)
  /// through iPhone 13 mini (812pt). Used to tighten paddings and
  /// font sizes inside the running-test HUD where vertical space is
  /// at a premium. 825 catches the mini line but leaves regular
  /// iPhone 13 (844pt) in the standard tier.
  bool get isCompactHeight => MediaQuery.sizeOf(this).height < 825;
}
