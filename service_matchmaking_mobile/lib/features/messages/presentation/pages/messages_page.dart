import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../app/app_semantic_colors.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/brand_header.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/messages_repository.dart';
import '../bloc/messages_bloc.dart';
import '../bloc/messages_event.dart';
import '../bloc/messages_state.dart';

const _quickEmojis = [
  '😀', '😂', '😍', '👍', '🙏', '❤️', '😢', '😮',
  '🔥', '🎉', '👏', '😅', '🤔', '😎', '😊', '👌',
  '💯', '🥳', '😴', '🙌', '😉', '🤝', '📷', '⏰',
];

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, this.initialRoomId});

  final String? initialRoomId;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _messageController = TextEditingController();
  final _conversationSearchController = TextEditingController();
  final _imagePicker = ImagePicker();
  bool _showConversationListOnMobile = true;
  bool _isComposing = false;
  String _conversationSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _showConversationListOnMobile = widget.initialRoomId == null;
    _conversationSearchController.addListener(() {
      setState(() {
        _conversationSearchQuery = _conversationSearchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _conversationSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthBloc>().state.user;

    return BlocProvider(
      create: (context) => MessagesBloc(context.read<MessagesRepository>())
        ..add(
          MessagesStarted(
            initialRoomId: widget.initialRoomId,
            currentUserId: currentUser?.id,
          ),
        ),
      child: Scaffold(
        bottomNavigationBar: const AppBottomNav(currentLocation: '/messages'),
        body: SafeArea(
          child: BlocConsumer<MessagesBloc, MessagesState>(
            listener: (context, state) {
              if (state.status == MessagesStatus.failure && state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.errorMessage!)),
                );
              }
            },
            builder: (context, state) {
              final conversations = state.conversations;
              final activeRoomId = state.activeRoomId;
              final currentUserId = state.currentUserId;
              final isMobile = MediaQuery.sizeOf(context).width < 900;

              if (!isMobile) {
                return Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        children: [
                          _conversationsHeader(context, conversations.length),
                          Expanded(
                            child: state.status == MessagesStatus.loading
                                ? const Center(child: CircularProgressIndicator())
                                : _conversationsList(context, conversations, activeRoomId),
                          ),
                        ],
                      ),
                    ),
                    VerticalDivider(color: Theme.of(context).colorScheme.outlineVariant),
                    Expanded(
                      flex: 6,
                      child: _chatPanel(
                        context,
                        state,
                        activeRoomId,
                        currentUserId: currentUserId,
                      ),
                    ),
                  ],
                );
              }

              if (_showConversationListOnMobile || activeRoomId == null) {
                return Column(
                  children: [
                    _conversationsHeader(context, conversations.length),
                    Expanded(
                      child: state.status == MessagesStatus.loading
                          ? const Center(child: CircularProgressIndicator())
                          : _conversationsList(context, conversations, activeRoomId),
                    ),
                  ],
                );
              }

              return _chatPanel(
                context,
                state,
                activeRoomId,
                currentUserId: currentUserId,
                onBackMobile: () => setState(() => _showConversationListOnMobile = true),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _conversationsHeader(BuildContext context, int count) {
    return Column(
      children: [
        BrandHeader(
          title: 'Messages',
          onBack: () => context.pop(),
          subtitle: count == 0 ? 'Aucune conversation' : '$count conversation${count > 1 ? 's' : ''} en cours',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: TextField(
            controller: _conversationSearchController,
            style: const TextStyle(fontSize: 13.5),
            decoration: InputDecoration(
              hintText: 'Rechercher une conversation',
              prefixIcon: const Icon(Icons.search, size: 20),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
      ],
    );
  }

  Widget _conversationsList(
    BuildContext context,
    List<Conversation> conversations,
    String? activeRoomId,
  ) {
    final filtered = _conversationSearchQuery.isEmpty
        ? conversations
        : conversations
            .where((c) => c.otherUserName.toLowerCase().contains(_conversationSearchQuery))
            .toList();

    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                conversations.isEmpty
                    ? 'Aucune conversation pour le moment'
                    : 'Aucun resultat pour cette recherche',
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 8),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 16,
        color: Theme.of(context).colorScheme.outlineVariant,
      ),
      itemBuilder: (context, index) {
        final conv = filtered[index];
        final selected = conv.roomId == activeRoomId;
        final unread = conv.unreadCount > 0;
        final theme = Theme.of(context);
        final subtitleText = conv.lastMessage?.trim().isNotEmpty == true
            ? conv.lastMessage!.trim()
            : (conv.requestTitle?.trim().isNotEmpty == true
                ? 'Poste: ${conv.requestTitle!.trim()}'
                : 'Aucun message');

        return ListTile(
          selected: selected,
          leading: CircleAvatar(
            foregroundImage: (conv.otherUserAvatarUrl != null && conv.otherUserAvatarUrl!.isNotEmpty)
                ? NetworkImage(conv.otherUserAvatarUrl!)
                : null,
            child: Text(
              conv.otherUserName.isEmpty ? 'U' : conv.otherUserName[0].toUpperCase(),
            ),
          ),
          title: Text(conv.otherUserName, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
            subtitleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: unread
                ? TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)
                : null,
          ),
          trailing: unread
              ? Container(
                  constraints: const BoxConstraints(minWidth: 19),
                  height: 19,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? theme.colorScheme.primary
                        : theme.colorScheme.tertiary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${conv.unreadCount}',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onTertiary,
                    ),
                  ),
                )
              : null,
          onTap: () {
            context.read<MessagesBloc>().add(MessagesConversationOpened(conv.roomId));
            setState(() => _showConversationListOnMobile = false);
          },
        );
      },
    );
  }

  Widget _chatPanel(
    BuildContext context,
    MessagesState state,
    String? activeRoomId, {
    String? currentUserId,
    VoidCallback? onBackMobile,
  }) {
    final hasActiveConversation = activeRoomId != null;
    final activeConversation = _conversationForRoom(state.conversations, activeRoomId);
    final timeline = _buildTimeline(state.activeMessages);

    return Column(
      children: [
        _chatTopBar(
          context,
          activeRoomId == null ? 'Selectionnez une conversation' : 'Discussion',
          onBack: onBackMobile,
        ),
        if (activeConversation != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  foregroundImage: (activeConversation.otherUserAvatarUrl != null &&
                          activeConversation.otherUserAvatarUrl!.isNotEmpty)
                      ? NetworkImage(activeConversation.otherUserAvatarUrl!)
                      : null,
                  child: Text(
                    activeConversation.otherUserName.isEmpty
                        ? 'U'
                        : activeConversation.otherUserName[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeConversation.otherUserName,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.isOtherTyping
                            ? 'En train d\'ecrire...'
                            : (activeConversation.requestTitle?.trim().isNotEmpty == true
                                ? 'Poste concerné: ${activeConversation.requestTitle}'
                                : 'Conversation liée à une demande'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: state.isOtherTyping
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              fontStyle: state.isOtherTyping ? FontStyle.italic : null,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (hasActiveConversation && !state.isSocketConnected)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Theme.of(context).colorScheme.errorContainer,
            child: Row(
              children: [
                const Icon(Icons.wifi_off, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Connexion perdue. Tentative de reconnexion...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    context.read<MessagesBloc>().add(const MessagesReconnectRequested());
                  },
                  child: const Text('Reconnecter'),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(12),
            itemCount: timeline.length,
            itemBuilder: (context, index) {
              final item = timeline[timeline.length - 1 - index];

              if (item is DateTime) {
                return _DateSeparator(date: item);
              }

              final message = item as ChatMessage;
              final mine = currentUserId != null && message.senderId == currentUserId;
              final colors = Theme.of(context).colorScheme;
              final semantic = context.semanticColors;
              final bubbleBg = mine ? semantic.bubbleOut : semantic.bubbleIn;
              final bubbleFg = mine ? semantic.bubbleOutForeground : semantic.bubbleInForeground;
              final hasImage = message.mediaUrl != null && message.mediaUrl!.isNotEmpty;

              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: EdgeInsets.symmetric(
                    horizontal: hasImage ? 6 : 14,
                    vertical: hasImage ? 6 : 10,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(mine ? 18 : 6),
                      bottomRight: Radius.circular(mine ? 6 : 18),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (hasImage)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            message.mediaUrl!,
                            width: 220,
                            height: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 220,
                              height: 220,
                              color: colors.surfaceContainerHighest,
                              alignment: Alignment.center,
                              child: const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      if (message.content.trim().isNotEmpty) ...[
                        if (hasImage)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                            child: Text(message.content, style: TextStyle(color: bubbleFg)),
                          )
                        else
                          Text(message.content, style: TextStyle(color: bubbleFg)),
                      ],
                      Padding(
                        padding: EdgeInsets.only(
                          top: 6,
                          left: hasImage ? 8 : 0,
                          right: hasImage ? 8 : 0,
                          bottom: hasImage ? 4 : 0,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              DateFormat('HH:mm').format(message.createdAt),
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: bubbleFg.withValues(alpha: 0.7),
                              ),
                            ),
                            if (mine) ...[
                              const SizedBox(width: 4),
                              Icon(
                                message.isRead ? Icons.done_all : Icons.done,
                                size: 14,
                                color: message.isRead
                                    ? colors.primary
                                    : bubbleFg.withValues(alpha: 0.7),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: 'Emoji',
                onPressed: activeRoomId == null ? null : _showEmojiPicker,
                icon: const Icon(Icons.emoji_emotions_outlined),
              ),
              IconButton(
                tooltip: 'Joindre une photo',
                onPressed: activeRoomId == null
                    ? null
                    : () => _pickAndSendImage(context, activeRoomId),
                icon: const Icon(Icons.image_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  enabled: activeRoomId != null,
                  minLines: 1,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (value) {
                    final composing = value.trim().isNotEmpty;
                    if (composing != _isComposing) {
                      _isComposing = composing;
                      if (activeRoomId != null) {
                        context.read<MessagesBloc>().add(MessagesTypingRequested(composing));
                      }
                    }
                  },
                  decoration: const InputDecoration(
                    hintText: 'Votre message...',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: activeRoomId == null
                    ? null
                    : () {
                        final text = _messageController.text.trim();
                        if (text.isEmpty) return;
                        context.read<MessagesBloc>().add(
                              MessagesSendRequested(
                                roomId: activeRoomId,
                                content: text,
                              ),
                            );
                        _messageController.clear();
                        _isComposing = false;
                      },
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndSendImage(BuildContext context, String roomId) async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
        requestFullMetadata: false,
      );
      if (!context.mounted || file == null) {
        return;
      }
      context.read<MessagesBloc>().add(
            MessagesImageSendRequested(roomId: roomId, filePath: file.path),
          );
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selection d\'image indisponible: ${e.message ?? e.code}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de choisir la photo: $e')),
      );
    }
  }

  Future<void> _showEmojiPicker() async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _quickEmojis
              .map(
                (emoji) => InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () => Navigator.of(sheetContext).pop(emoji),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(emoji, style: const TextStyle(fontSize: 26)),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (emoji == null || !mounted) return;

    final text = _messageController.text;
    final selection = _messageController.selection;
    final insertAt = selection.start >= 0 ? selection.start : text.length;
    final removeEnd = selection.end >= 0 ? selection.end : insertAt;
    final newText = text.replaceRange(insertAt, removeEnd, emoji);
    _messageController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: insertAt + emoji.length),
    );
  }

  List<Object> _buildTimeline(List<ChatMessage> messages) {
    final items = <Object>[];
    DateTime? lastDay;

    for (final message in messages) {
      final day = DateTime(
        message.createdAt.year,
        message.createdAt.month,
        message.createdAt.day,
      );
      if (lastDay == null || day != lastDay) {
        items.add(day);
        lastDay = day;
      }
      items.add(message);
    }

    return items;
  }

  Conversation? _conversationForRoom(List<Conversation> conversations, String? roomId) {
    if (roomId == null || roomId.isEmpty) {
      return null;
    }

    try {
      return conversations.firstWhere((conversation) => conversation.roomId == roomId);
    } catch (_) {
      return null;
    }
  }

  /// Barre plate (pas de degrade) pour la vue d'une conversation ouverte,
  /// distincte de l'en-tete de marque utilise sur la liste des conversations.
  Widget _chatTopBar(BuildContext context, String title, {VoidCallback? onBack}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  String _label() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (date == today) return 'Aujourd\'hui';
    if (date == yesterday) return 'Hier';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _label(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ),
      ),
    );
  }
}
