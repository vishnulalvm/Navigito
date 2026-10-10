import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/location_input.dart';
import '../../../../core/widgets/dropped_pin.dart';
import '../../domain/entities/map_place.dart';
import '../../domain/entities/place_suggestion.dart';
import '../../domain/entities/recent_place.dart';
import '../../domain/entities/trip.dart';
import '../providers/home_providers.dart';

/// A place picked in [HomeSearchBar].
class PickedPlace {
  const PickedPlace({
    required this.id,
    required this.name,
    required this.position,
    this.subtitle = '',
    this.types = const [],
  });

  /// Google place id, or the app's own place id.
  final String id;
  final String name;
  final String subtitle;
  final LatLng position;

  /// Google place types when known (only fresh Google results carry them).
  final List<String> types;
}

/// Search field with a suggestion panel. Free results (recent picks, the app's
/// own places and trips) come first; Google Places results follow.
class HomeSearchBar extends ConsumerStatefulWidget {
  const HomeSearchBar({
    super.key,
    required this.onPlaceSelected,
    required this.dock,
    this.onUseMyLocation,
    this.onPreview,
    this.stopPicker = false,
    this.hintText = 'Search destinations, places, trips...',
  });

  final ValueChanged<PickedPlace> onPlaceSelected;

  /// Shows "Use my location" for an empty query when set.
  final VoidCallback? onUseMyLocation;

  /// Where typed coordinates, a pasted link or a plus code point, as soon as
  /// it's known, so the map can show it before it's picked; null once the
  /// text no longer names a location.
  final ValueChanged<LatLng?>? onPreview;

  /// For adding stops to a trip: only places are offered, the home trip list
  /// isn't filtered, and the field empties after each pick, ready for the
  /// next one.
  final bool stopPicker;
  final String hintText;

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
    widget.onPreview?.call(null);
    _focus.unfocus();
    if (widget.stopPicker) {
      _controller.clear();
    } else {
      if (text != null) _controller.text = text;
      ref.read(searchedPlaceProvider.notifier).state = filterPlace;
    }
    _search.clear();
    setState(() {});
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
    widget.onPlaceSelected(
      PickedPlace(
        id: p.placeId,
        name: p.name,
        subtitle: p.secondaryText,
        position: LatLng(p.latitude, p.longitude),
      ),
    );
  }

  void _pickMapPlace(MapPlace p) {
    _close(text: p.name, filterPlace: p.name);
    widget.onPlaceSelected(
      PickedPlace(
        id: p.id,
        name: p.name,
        subtitle: 'Popular place',
        position: LatLng(p.latitude, p.longitude),
      ),
    );
  }

  void _pickTrip(Trip t) {
    _close();
    context.push(AppRouter.tripDetail(t.id));
  }

  Future<void> _pickSuggestion(PlaceSuggestion s) async {
    _focus.unfocus();
    if (widget.stopPicker) {
      _controller.clear();
    } else {
      _controller.text = s.mainText;
      ref.read(searchedPlaceProvider.notifier).state = s.mainText;
    }
    final target = await _search.select(s);
    _search.clear();
    if (!mounted) return;
    setState(() {});
    if (target != null) {
      widget.onPlaceSelected(
        PickedPlace(
          id: s.placeId,
          name: s.mainText,
          subtitle: s.secondaryText,
          position: target,
          types: s.types,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not find that place. Try again.')),
      );
    }
  }

  /// A pasted link, coordinates or plus code: no Places call was needed.
  void _pickDirect(DirectLocation d) {
    final pos = d.position;
    if (pos == null) return;
    final coords = formatLatLng(pos);
    final name = d.name ?? coords;
    final id =
        'geo:${pos.latitude.toStringAsFixed(6)},'
        '${pos.longitude.toStringAsFixed(6)}';
    _close(text: name, filterPlace: d.name);
    // Kept with the recents, so it's one tap next time.
    ref
        .read(recentPlacesProvider.notifier)
        .add(
          RecentPlace(
            placeId: id,
            name: name,
            secondaryText: d.source.label,
            latitude: pos.latitude,
            longitude: pos.longitude,
            savedAt: DateTime.now(),
          ),
        );
    widget.onPlaceSelected(
      PickedPlace(
        id: id,
        name: name,
        subtitle: d.name == null ? d.source.label : coords,
        position: pos,
      ),
    );
  }

  void _onChanged(String q) {
    _search.onQueryChanged(q);
    if (q.isEmpty && !widget.stopPicker) {
      ref.read(searchedPlaceProvider.notifier).state = null;
    }
    setState(() {});
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Clipboard is empty')));
      return;
    }
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _onChanged(text);
  }

  void _useMyLocation() {
    _controller.clear();
    _close();
    widget.onUseMyLocation?.call();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // The search state is shared with the other screen's bar; only the
    // focused one drives its map.
    ref.listen(searchProvider.select((s) => s.direct?.position), (_, pos) {
      if (_focus.hasFocus) widget.onPreview?.call(pos);
    });
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
              onChanged: _onChanged,
              // Search key picks the top result, like tapping it.
              onSubmitted: (_) {
                if (options.isNotEmpty) options.first.onTap();
              },
              textInputAction: TextInputAction.search,
              textCapitalization: TextCapitalization.words,
              // Autocorrect turns place names like "Munnar" into other words.
              autocorrect: false,
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                prefixIcon: Icon(Icons.search, color: scheme.onSurfaceVariant),
                suffixIcon: _controller.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          widget.onPreview?.call(null);
                          _controller.clear();
                          _search.clear();
                          if (!widget.stopPicker) {
                            ref.read(searchedPlaceProvider.notifier).state =
                                null;
                          }
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
    final direct = search.direct;
    // A pasted location answers the query by itself.
    if (direct != null) {
      final pos = direct.position;
      if (pos == null) return const [];
      return [
        _Option(
          icon: switch (direct.source) {
            LocationSource.mapsLink => Icons.link,
            LocationSource.coordinates => Icons.pin_drop_outlined,
            LocationSource.plusCode => Icons.add_location_alt_outlined,
          },
          title: Text(
            direct.name ?? formatLatLng(pos),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: direct.name == null
              ? direct.source.label
              : '${direct.source.label} · ${formatLatLng(pos)}',
          trailing: widget.stopPicker ? 'Add' : 'Go',
          onTap: () => _pickDirect(direct),
        ),
      ];
    }
    return [
      if (query.isEmpty && widget.onUseMyLocation != null)
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
      if (!widget.stopPicker)
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

    final direct = search.direct;
    final loading = search.loading || (direct?.resolving ?? false);
    final noResults =
        direct == null &&
        search.searchesRemote &&
        !search.loading &&
        search.error == null &&
        options.isEmpty;
    final showTip = search.query.trim().isEmpty;

    final footer = direct?.resolving ?? false
        ? ListTile(
            dense: true,
            leading: const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            title: Text(
              direct!.source == LocationSource.mapsLink
                  ? 'Opening Google Maps link…'
                  : 'Finding plus code…',
            ),
          )
        : direct?.error != null
        ? ListTile(
            dense: true,
            leading: Icon(Icons.error_outline, color: scheme.error),
            title: Text(direct!.error!),
            trailing: TextButton(
              onPressed: _search.retry,
              child: const Text('Retry'),
            ),
          )
        : search.error != null
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

    if (options.isEmpty && footer == null && !loading && !showTip) {
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
            child: loading ? const LinearProgressIndicator() : null,
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                for (final o in options) o.build(context),
                ?footer,
                if (showTip) _PasteTip(onPaste: _paste),
              ],
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

/// Bottom of the empty panel: what else the field understands, with a
/// one-tap paste.
class _PasteTip extends StatelessWidget {
  const _PasteTip({required this.onPaste});

  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;

    Widget example(IconData icon, String text) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: muted),
          const SizedBox(width: 4),
          Text(text, style: theme.textTheme.labelSmall?.copyWith(color: muted)),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 18,
                color: scheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Have a location already?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: onPaste,
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.content_paste, size: 16),
                label: const Text('Paste'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Paste a Google Maps link, coordinates or a plus code to jump '
            'straight there.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              example(Icons.link, 'maps.app.goo.gl/…'),
              example(Icons.pin_drop_outlined, '9.9312, 76.2673'),
              example(Icons.add_location_alt_outlined, 'WJ8P+2V Kochi'),
            ],
          ),
        ],
      ),
    );
  }
}
