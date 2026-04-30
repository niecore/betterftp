import 'package:flutter/material.dart';

import '../../core/responsive/breakpoints.dart';

/// A flex body region for top-level screens. Pairs with a fixed
/// action area (typically buttons) below to produce the app-wide
/// "centre-on-tablet, top-on-phone, scroll-on-overflow" layout.
///
/// On tablets the [child] is vertically centred within the available
/// space, so the content floats in the middle of the canvas instead
/// of being pinned to the top with a yawning gap below. On phones it
/// top-aligns and lets a [SingleChildScrollView] absorb any overflow.
///
/// Must be used as a child of a parent flex (Column/Row) — the
/// internal [Expanded] consumes whatever space the parent has after
/// fixed siblings have been laid out.
class ResponsiveScreenBody extends StatelessWidget {
  final Widget child;
  const ResponsiveScreenBody({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Align(
              alignment:
                  context.isTablet ? Alignment.center : Alignment.topCenter,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
