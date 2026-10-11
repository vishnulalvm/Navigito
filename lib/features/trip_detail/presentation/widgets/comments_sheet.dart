import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/snackbar.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/widgets/ensure_signed_in.dart';
import '../../domain/entities/trip_comment.dart';
import '../../domain/entities/trip_detail.dart';
import '../../domain/usecases/manage_trip_comments.dart';
import '../providers/trip_detail_providers.dart';

/// Comments on [trip], with a box to add one, in a draggable sheet.
Future<void> showCommentsSheet(BuildContext context, TripDetail trip) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scroll) => _CommentsSheet(trip: trip, scroll: scroll),
      ),
    );

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.trip, required this.scroll});
  final TripDetail trip;
  final ScrollController scroll;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _input = TextEditingController();
  bool _sending = false;

  String get _tripId => widget.trip.id;

  @override
  void initState() {
    super.initState();
    widget.scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    widget.scroll.removeListener(_maybeLoadMore);
    _input.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    final pos = widget.scroll.position;
    if (pos.pixels > pos.maxScrollExtent - 300) {
      ref.read(tripCommentsProvider(_tripId).notifier).loadMore();
    }
  }

  Future<void> _send() async {
    if (_sending || _input.text.trim().isEmpty) return;
    if (!await ensureSignedIn(context, ref, reason: 'Sign in to comment')) {
      return;
    }
    setState(() => _sending = true);
    final error = await ref
        .read(tripCommentsProvider(_tripId).notifier)
        .add(_input.text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (error == null) {
      _input.clear();
      if (widget.scroll.hasClients) widget.scroll.jumpTo(0);
    }
    showErrorSnack(context, error);
  }

  Future<void> _confirmDelete(TripComment comment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This removes it for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final error = await ref
        .read(tripCommentsProvider(_tripId).notifier)
        .delete(comment);
    if (mounted) showErrorSnack(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final async = ref.watch(tripCommentsProvider(_tripId));
    final notifier = ref.read(tripCommentsProvider(_tripId).notifier);
    final me = ref.watch(authUserProvider.select((u) => u.valueOrNull?.id));
    final ownTrip = me != null && me == widget.trip.authorId;
    final count = ref.watch(
      tripDetailProvider(_tripId).select((t) => t.valueOrNull?.comments),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            count == null || count == 0 ? 'Comments' : 'Comments · $count',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => Center(
              child: TextButton.icon(
                onPressed: () => ref.invalidate(tripCommentsProvider(_tripId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Could not load comments. Retry'),
              ),
            ),
            data: (comments) => comments.isEmpty
                ? ListView(
                    controller: widget.scroll,
                    children: [
                      const SizedBox(height: 64),
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 40,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No comments yet. Start the conversation.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  )
                : ListView.builder(
                    controller: widget.scroll,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: comments.length + (notifier.hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == comments.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final c = comments[i];
                      final canDelete =
                          me != null && (c.userId == me || ownTrip);
                      return _CommentTile(
                        comment: c,
                        isAuthor: c.userId == widget.trip.authorId,
                        onDelete: canDelete ? () => _confirmDelete(c) : null,
                      );
                    },
                  ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            8,
            8,
            8 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    // Signed out, a tap asks to sign in instead of typing.
                    readOnly: me == null,
                    minLines: 1,
                    maxLines: 4,
                    maxLength: ManageTripComments.maxLength,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                    onTap: () => ensureSignedIn(
                      context,
                      ref,
                      reason: 'Sign in to comment',
                    ),
                    decoration: InputDecoration(
                      hintText: me == null
                          ? 'Sign in to comment'
                          : 'Add a comment…',
                      counterText: '',
                      filled: true,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Send',
                        onPressed: _input.text.trim().isEmpty ? null : _send,
                        icon: const Icon(Icons.send_rounded),
                      ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.isAuthor,
    this.onDelete,
  });

  final TripComment comment;

  /// Written by the trip's author.
  final bool isAuthor;
  final VoidCallback? onDelete;

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    if (d.inDays < 1) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return DateFormat('d MMM y').format(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final avatar = comment.authorAvatarUrl;

    return InkWell(
      onLongPress: onDelete,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: avatar.isEmpty ? null : NetworkImage(avatar),
              onBackgroundImageError: avatar.isEmpty ? null : (_, _) {},
              child: avatar.isEmpty ? const Icon(Icons.person, size: 18) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text(
                        comment.authorName,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (isAuthor)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Author',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      Text(
                        _ago(comment.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(comment.body, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
            if (onDelete != null)
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
