import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../providers/home_providers.dart';

class HomeSearchBar extends ConsumerStatefulWidget {
  const HomeSearchBar({super.key, required this.onPlaceSelected});

  final ValueChanged<LatLng> onPlaceSelected;

  @override
  ConsumerState<HomeSearchBar> createState() => _HomeSearchBarState();
}

class _HomeSearchBarState extends ConsumerState<HomeSearchBar> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final suggestions = ref.watch(searchProvider);
    final notifier = ref.read(searchProvider.notifier);

    return Column(
      children: [
        Material(
          color: scheme.surface,
          elevation: 3,
          borderRadius: BorderRadius.circular(32),
          child: TextField(
            controller: _controller,
            onChanged: (q) {
              notifier.onQueryChanged(q);
              if (q.isEmpty) {
                ref.read(searchedPlaceProvider.notifier).state = null;
              }
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search destinations, places, trips...',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
              prefixIcon: Icon(Icons.location_on, color: scheme.primary),
              suffixIcon: _controller.text.isEmpty
                  ? const Icon(Icons.mic_none)
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        _controller.clear();
                        notifier.clear();
                        ref.read(searchedPlaceProvider.notifier).state = null;
                        setState(() {});
                      },
                    ),
            ),
          ),
        ),
        suggestions.when(
          data: (items) => items.isEmpty
              ? const SizedBox.shrink()
              : Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(blurRadius: 6, color: Colors.black26),
                    ],
                  ),
                  child: Column(
                    children: [
                      for (final s in items)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(
                            s.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () async {
                            FocusScope.of(context).unfocus();
                            _controller.text = s.description;
                            ref.read(searchedPlaceProvider.notifier).state = s
                                .description
                                .split(',')
                                .first
                                .trim();
                            final target = await notifier.select(s);
                            if (target != null) widget.onPlaceSelected(target);
                          },
                        ),
                    ],
                  ),
                ),
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
