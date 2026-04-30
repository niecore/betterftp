import 'package:flutter/material.dart';

/// Caps the horizontal extent of page content on tablets and other
/// wide displays, while letting the content fill the available width
/// on phones. Wrap the body of every top-level screen with this.
///
/// Centers the bounded content horizontally; the surrounding area
/// continues to be filled by the [Scaffold]'s `backgroundColor`,
/// keeping the brand's flat-color background edge-to-edge.
class PageMaxWidth extends StatelessWidget {
  /// The phone-like maximum width applied on tablets/desktop. 480pt sits
  /// just above iPhone Pro Max width (430pt), so phones never get capped
  /// but iPads stop the layout from stretching into awkward territory.
  static const double defaultMaxWidth = 480;

  final Widget child;
  final double maxWidth;

  const PageMaxWidth({
    super.key,
    required this.child,
    this.maxWidth = defaultMaxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
