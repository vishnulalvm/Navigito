import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Height of the drag handle + header row, used to size a collapsed sheet.
const double kMapSheetHeaderHeight = 84;

/// Space a floating search bar takes at the top of a map screen, under the
/// status bar.
const double kMapSearchAreaHeight = 84;

const double _sheetRadius = 28;

/// Space the docked header gives back: the hidden handle and some padding.
const double _dockedHeaderShrink = 24;

/// Size limits and dock progress for a [MapSheet] under a floating search
/// bar.
class MapSheetController {
  MapSheetController({this.initialFraction = 0.45}) {
    sheet.addListener(_onSheetChanged);
  }

  /// Preferred resting height, as a fraction of the screen.
  final double initialFraction;

  /// How far below its top stop the sheet starts blending into the search bar.
  static const _dockRange = 0.12;

  /// Docked, the sheet tucks this far into the search area's bottom padding
  /// so its title sits close under the search bar.
  static const _dockLift = 12.0;

  final sheet = DraggableScrollableController();

  /// Latest sheet extent (fraction of screen); null until the sheet reports.
  final size = ValueNotifier<double?>(null);

  /// 0 while the sheet is low, 1 once it is docked under the search bar; the
  /// sheet and search bar blend into one surface as it rises.
  final dock = ValueNotifier<double>(0);

  // Latest layout values, kept for animating outside build.
  double minSize = 0.2;
  double initialSize = 0.45;
  double maxSize = 1;
  bool _disposed = false;

  /// Works out the limits for a screen [height]. Collapsed, the header sits
  /// just above [bottomSpace]; expanded, the sheet docks under the search bar.
  void layout({
    required double height,
    required double topInset,
    required double bottomSpace,
  }) {
    minSize = ((bottomSpace + kMapSheetHeaderHeight) / height).clamp(0.1, 0.5);
    maxSize = (1 - (topInset + kMapSearchAreaHeight - _dockLift) / height)
        .clamp(0.6, 1.0);
    initialSize = initialFraction.clamp(minSize, maxSize);
  }

  /// The controller can notify while the sheet is being built, and rebuilding
  /// a listener then throws, so defer the update to after the frame.
  void _onSheetChanged() {
    if (!sheet.isAttached) return;
    final value = sheet.size;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!_disposed) _setSize(value);
      });
    } else {
      _setSize(value);
    }
  }

  void _setSize(double value) {
    size.value = value;
    dock.value = ((value - (maxSize - _dockRange)) / _dockRange).clamp(0, 1);
  }

  double get currentSize => sheet.isAttached ? sheet.size : initialSize;

  Future<void> animateTo(double target) async {
    if (!sheet.isAttached) return;
    await sheet.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> collapse() => animateTo(minSize);
  Future<void> rest() => animateTo(initialSize);

  void dispose() {
    _disposed = true;
    sheet.removeListener(_onSheetChanged);
    size.dispose();
    dock.dispose();
    sheet.dispose();
  }
}

/// Bottom sheet over a map with a pinned header. As it nears the top it
/// docks under the search bar: corners flatten, the shadow and handle fade,
/// and the header tightens up.
class MapSheet extends StatelessWidget {
  const MapSheet({
    super.key,
    required this.controller,
    required this.header,
    required this.slivers,
  });

  final MapSheetController controller;

  /// Row under the drag handle; stays pinned while the content scrolls.
  final Widget header;
  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: controller.sheet,
      initialChildSize: controller.initialSize,
      minChildSize: controller.minSize,
      maxChildSize: controller.maxSize,
      snap: true,
      snapSizes: [controller.initialSize],
      builder: (context, scrollController) {
        final content = CustomScrollView(
          controller: scrollController,
          slivers: [
            // Rebuilt with the dock progress so the header can tighten up
            // under the search bar.
            ValueListenableBuilder<double>(
              valueListenable: controller.dock,
              builder: (context, dock, _) => SliverPersistentHeader(
                pinned: true,
                delegate: _HeaderDelegate(dock: dock, child: header),
              ),
            ),
            ...slivers,
          ],
        );

        return ValueListenableBuilder<double>(
          valueListenable: controller.dock,
          child: content,
          builder: (context, dock, child) {
            final radius = BorderRadius.vertical(
              top: Radius.circular(_sheetRadius * (1 - dock)),
            );
            return DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    blurRadius: 16,
                    color: Colors.black.withValues(alpha: 0.38 * (1 - dock)),
                  ),
                ],
              ),
              child: ClipRRect(borderRadius: radius, child: child),
            );
          },
        );
      },
    );
  }
}

/// Pinned so the header stays reachable while the list scrolls; a hairline
/// fades in once content slides under it.
class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  _HeaderDelegate({required this.dock, required this.child});

  final double dock;
  final Widget child;

  @override
  double get minExtent => kMapSheetHeaderHeight - _dockedHeaderShrink * dock;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final scheme = Theme.of(context).colorScheme;
    final scrolledUnder = shrinkOffset > 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: scrolledUnder
                ? scheme.outlineVariant.withValues(alpha: 0.7)
                : scheme.outlineVariant.withValues(alpha: 0),
          ),
        ),
      ),
      child: Column(
        children: [
          // Docked under the search bar the sheet can only be dragged down,
          // and the handle would read as a seam, so it collapses away.
          SizedBox(height: 10 * (1 - dock)),
          Opacity(
            opacity: 1 - dock,
            child: Container(
              width: 40 - 16 * dock,
              height: 4 * (1 - dock),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_HeaderDelegate old) =>
      old.child != child || old.dock != dock;
}

/// Fills in behind the search bar as the sheet docks, so the two read as one
/// surface instead of a pill floating over the map. Place it in a [Stack].
class MapSearchBackdrop extends StatelessWidget {
  const MapSearchBackdrop({super.key, required this.controller});

  final MapSheetController controller;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: MediaQuery.paddingOf(context).top + kMapSearchAreaHeight,
      child: ValueListenableBuilder<double>(
        valueListenable: controller.dock,
        builder: (context, dock, _) => IgnorePointer(
          ignoring: dock == 0,
          child: Opacity(
            opacity: Curves.easeIn.transform(dock),
            child: ColoredBox(color: Theme.of(context).colorScheme.surface),
          ),
        ),
      ),
    );
  }
}

/// Rides on top of the sheet, at its right edge or, with [left], across
/// it; hides once the sheet docks. Place it in a [Stack] the height of the
/// screen.
class MapSheetFab extends StatelessWidget {
  const MapSheetFab({
    super.key,
    required this.controller,
    required this.screenHeight,
    required this.child,
    this.left,
  });

  final MapSheetController controller;
  final double screenHeight;
  final Widget child;
  final double? left;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double?>(
      valueListenable: controller.size,
      builder: (context, reported, _) {
        final size = reported ?? controller.initialSize;
        final atTop = size >= controller.maxSize - 0.03;
        return Positioned(
          left: left,
          right: 16,
          bottom: size * screenHeight + 12,
          child: IgnorePointer(
            ignoring: atTop,
            child: AnimatedOpacity(
              opacity: atTop ? 0 : 1,
              duration: const Duration(milliseconds: 150),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
