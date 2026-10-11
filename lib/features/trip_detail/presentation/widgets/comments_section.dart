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

/// Comments on [trip], shown inline: a box to add one, the latest few, and
/// the rest on request. Lives inside the Overview tab's list.
class CommentsSection extends ConsumerStatefulWidget {
  const CommentsSection({super.key, required this.trip});
  final TripDetail trip;

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection> {
  /// Comments shown before "View all".
  static const _preview = 3;

  final _input = TextEditingController();
  bool _sending = false;
  bool _expanded = false;

  /// The input stays hidden until the user taps "Add comment".
  bool _composing = false;

  String get _tripId => widget.trip.id;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
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
      FocusScope.of(context).unfocus();
      setState(() => _composing = false);
    }
    showErrorSnack(context, error);
  }

  Future<void> _startComposing() async {
    if (!await ensureSignedIn(context, ref, reason: 'Sign in to comment')) {
      return;
    }
    if (mounted) setState(() => _composing = true);
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
    final scheme = theme.colorScheme;
    final async = ref.watch(tripCommentsProvider(_tripId));
    final notifier = ref.read(tripCommentsProvider(_tripId).notifier);
    final me = ref.watch(authUserProvider.select((u) => u.valueOrNull?.id));
    final ownTrip = me != null && me == widget.trip.authorId;
    final count = widget.trip.comments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                count == 0 ? 'Comments' : 'Comments ($count)',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!_composing)
              TextButton.icon(
                onPressed: _startComposing,
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: const Text('Add comment'),
              ),
          ],
        ),
        if (_composing) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: ManageTripComments.maxLength,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Add a comment…',
                    counterText: '',
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
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
        ],
        const SizedBox(height: 8),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Center(
            child: TextButton.icon(
              onPressed: () => ref.invalidate(tripCommentsProvider(_tripId)),
              icon: const Icon(Icons.refresh),
              label: const Text('Could not load comments. Retry'),
            ),
          ),
          data: (comments) {
            if (comments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No comments yet. Start the conversation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              );
            }
            final shown = _expanded
                ? comments
                : comments.take(_preview).toList();
            final more = _expanded
                ? notifier.hasMore
                : comments.length > _preview || notifier.hasMore;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final c in shown)
                  _CommentTile(
                    comment: c,
                    isAuthor: c.userId == widget.trip.authorId,
                    onDelete: me != null && (c.userId == me || ownTrip)
                        ? () => _confirmDelete(c)
                        : null,
                  ),
                if (more)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(
                      onPressed: () {
                        if (_expanded) {
                          notifier.loadMore();
                        } else {
                          setState(() => _expanded = true);
                        }
                      },
                      child: Text(
                        _expanded
                            ? 'Show older comments'
                            : 'View all ${count > 0 ? '$count ' : ''}comments',
                      ),
                    ),
                  ),
              ],
            );
          },
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
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
              PopupMenuButton<void>(
                tooltip: 'More',
                padding: EdgeInsets.zero,
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: scheme.onSurfaceVariant,
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: onDelete,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: scheme.error,
                        ),
                        const SizedBox(width: 12),
                        Text('Delete', style: TextStyle(color: scheme.error)),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
