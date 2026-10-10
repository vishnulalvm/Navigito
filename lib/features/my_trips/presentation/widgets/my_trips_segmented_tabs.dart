import 'package:flutter/material.dart';

import '../../domain/repositories/my_trips_repository.dart';

class MyTripsSegmentedTabs extends StatelessWidget {
  const MyTripsSegmentedTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final MyTripsTab selected;
  final ValueChanged<MyTripsTab> onChanged;

  static const _labels = {
    MyTripsTab.saved: 'Saved',
    MyTripsTab.mine: 'My Trips',
    MyTripsTab.liked: 'Liked',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (final tab in MyTripsTab.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(tab),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tab == selected
                        ? scheme.surfaceContainerHighest
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _labels[tab]!,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tab == selected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
