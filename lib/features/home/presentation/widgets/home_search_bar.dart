import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../domain/entities/map_place.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/entities/recent_place.dart';
import '../../domain/entities/trip.dart';
import '../providers/home_providers.dart';

/// Search field with a suggestion panel. Free results (recent picks, the app's
/// own places and trips) come first; Google Places results follow.
class HomeSearchBar extends ConsumerStatefulWidget {
  const HomeSearchBar({
    super.key,
    required this.onPlaceSelected,
    required this.onUseMyLocation,
    required this.dock,
  });

  final ValueChanged<LatLng> onPlaceSelected;
  final VoidCallback onUseMyLocation;

  /// Sheet dock progress: lifted pill over the map at 0, flat filled field on
  /// the sheet's surface at 1.
  final ValueListenable<double> dock;

  @override
  ConsumerState<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends ConsumerState<HomeSearchBar> {
  static const _searchAreaHeight = 84.0;

  final _controller = TextEditingController();
  late final _focus = FocusNode()..addListener(() => setState(() {}));

  SearchNotifier get _search => ref.read(searchProvider.notifier);

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Closes the panel and keyboard, leaving [text] in the field.
  void _close({String? text, String? filterPlace}) {
    _focus.unfocus();
    if (text != null) _controller.text = text;
    ref.read(searchedPlaceProvider.notifier).state = filterPlace;
    _search.clear();
  }

  void _pickRecent(RecentPlace p) {
    _close(text: p.name, filterPlace: p.name);
    // Re-saving moves it to the top; no API call needed.
    ref
        .read(recentPlacesProvider.notifier)
        .add(
          RecentPlace(
            placeId: p.placeId,
            name: p.name,
            secondaryText: p.secondaryText,
            latitude: p.latitude,
            longitude: p.longitude,
            savedAt: DateTime.now(),
          ),
        );
    widget.onPlaceSelected(LatLng(p.latitude, p.longitude));
  }

  void _pickMapPlace(MapPlace p) {
    _close(text: p.name, filterPlace: p.name);
    widget.onPlaceSelected(LatLng(p.latitude, p.longitude));
  }

  void _pickTrip(Trip t) {
    _close();
    context.push(AppRouter.tripDetail(t.id));
  }

  Future<void> _pickSuggestion(PlaceSuggestion s) async {
    _focus.unfocus();
    _controller.text = s.mainText;
    ref.read(searchedPlaceProvider.notifier).state = s.mainText;
    final target = await _search.select(s);
    _search.clear();
    if (!mounted) return;
    if (target != null) {
      widget.onPlaceSelected(target);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find that place. Try again.')),
      );
    }
  }

  void _useMyLocation() {
    _controller.clear();
    _close();
    widget.onUseMyLocation();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final search = ref.watch(searchProvider);
    final local = ref.watch(localMatchesProvider);
    final options = _options(search, local);

    return TapRegion(
      onTapOutside: (_) => _focus.unfocus(),
      child: Column(
        children: [
          ValueListenableBuilder<double>(
            valueListenable: widget.dock,
            builder: (context, dock, child) => Material(
              color: Color.lerp(
                scheme.surface,
                scheme.surfaceContainerHigh,
                dock,
              ),
              elevation: 3 * (1 - dock),
              borderRadius: BorderRadius.circular(32),
              child: child,
            ),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              onChanged: (q) {
                _search.onQueryChanged(q);
                if (q.isEmpty) {
                  ref.read(searchedPlaceProvider.notifier).state = null;
                }
                setState(() {});
              },
              // Search key picks the top result, like tapping it.
              onSubmitted: (_) {
                if (options.isNotEmpty) options.first.onTap();
              },
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.words,
              // Autocorrect turns place names like "Munnar" into other words.
              autocorrect: false,
              decoration: InputDecoration(
                hintText: 'Search destinations, places, trips...',
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _controller.clear();
                          _search.clear();
                          ref.read(searchedPlaceProvider.notifier).state = null;
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          if (_focus.hasFocus) _panel(context, search, options),
        ],
      ),
    );
  }

  /// Rows in display order; the first one is what the Search key picks.
  List<_Option> _options(SearchState search, LocalMatches local) {
    final query = search.query.trim();
    return [
      if (query.isEmpty)
        _Option(
          icon: Icons.my_location,
          title: const Text('Use my location'),
          onTap: _useMyLocation,
        ),
      for (final p in local.recents)
        _Option(
          icon: Icons.history,
          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: p.secondaryText,
          onTap: () => _pickRecent(p),
        ),
      for (final p in local.places)
        _Option(
          icon: Icons.photo_camera_outlined,
          title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: 'Popular place',
          onTap: () => _pickMapPlace(p),
        ),
      for (final t in local.trips)
        _Option(
          icon: Icons.route,
          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle:
              '${t.days} ${t.days == 1 ? 'day' : 'days'} · '
              '${t.stops} stops',
          onTap: () => _pickTrip(t),
        ),
      if (query.isNotEmpty)
        for (final s in search.places.where(
          (s) => !local.recents.any((r) => r.placeId == s.placeId),
        ))
          _Option(
            icon: Icons.place_outlined,
            title: _Highlighted(text: s.mainText, matches: s.mainMatches),
            subtitle: s.secondaryText,
            trailing: s.distanceMeters == null
                ? null
                : _formatDistance(s.distanceMeters!),
            onTap: () => _pickSuggestion(s),
          ),
    ];
  }

  Widget _panel(
    BuildContext context,
    SearchState search,
    List<_Option> options,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final maxHeight =
        (media.size.height -
                media.viewInsets.bottom -
                media.padding.top -
                _searchAreaHeight -
                24)
            .clamp(120.0, 380.0);

    final noResults =
        search.searchesRemote &&
        !search.loading &&
        search.error == null &&
        options.isEmpty;

    final footer = search.error != null
        ? ListTile(
            dense: true,
            leading: Icon(Icons.wifi_off, color: scheme.error),
            title: const Text('Could not load places'),
            trailing: TextButton(
              onPressed: _search.retry,
              child: const Text('Retry'),
            ),
          )
        : noResults
        ? const ListTile(
            dense: true,
            leading: Icon(Icons.search_off),
            title: Text('No places found'),
          )
        : null;

    if (options.isEmpty && footer == null && !search.loading) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(blurRadius: 6, color: Colors.black26)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Old results stay visible underneath while new ones load.
          SizedBox(
            height: 2,
            child: search.loading ? const LinearProgressIndicator() : null,
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [for (final o in options) o.build(context), ?footer],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDistance(int meters) {
    if (meters < 1000) return '$meters m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
  }
}

class _Option {
  const _Option({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final Widget title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback onTap;

  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: muted),
      title: title,
      subtitle: subtitle == null || subtitle!.isEmpty
          ? null
          : Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: muted),
            ),
      trailing: trailing == null
          ? null
          : Text(
              trailing!,
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
      onTap: onTap,
    );
  }
}

/// [text] with the ranges the user typed shown in bold.
class _Highlighted extends StatelessWidget {
  const _Highlighted({required this.text, required this.matches});

  final String text;
  final List<(int, int)> matches;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var at = 0;
    for (final (start, end) in matches) {
      if (start < at || end > text.length || start >= end) continue;
      if (start > at) spans.add(TextSpan(text: text.substring(at, start)));
      spans.add(
        TextSpan(
          text: text.substring(start, end),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      at = end;
    }
    if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
