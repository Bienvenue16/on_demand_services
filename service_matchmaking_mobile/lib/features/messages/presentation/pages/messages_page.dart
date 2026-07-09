import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../app/app_semantic_colors.dart';
import '../../../../core/audio/voice_recorder_service.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/brand_header.dart';
import '../../../../core/widgets/voice_message_player.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/messages_repository.dart';
import '../bloc/messages_bloc.dart';
import '../bloc/messages_event.dart';
import '../bloc/messages_state.dart';

const _quickEmojis = [
  '😀',
  '😂',
  '😍',
  '👍',
  '🙏',
  '❤️',
  '😢',
  '😮',
  '🔥',
  '🎉',
  '👏',
  '😅',
  '🤔',
  '😎',
  '😊',
  '👌',
  '💯',
  '🥳',
  '😴',
  '🙌',
  '😉',
  '🤝',
  '📷',
  '⏰',
];

const _quickReactions = ['❤️', '👍', '😂', '😮', '😢', '🙏'];

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
  final _voiceRecorder = VoiceRecorderService();
  bool _showConversationListOnMobile = true;
  bool _isComposing = false;
  String _conversationSearchQuery = '';
  String? _editingMessageId;
  bool _isRecording = false;
  Duration _recordingElapsed = Duration.zero;
  Timer? _recordingTicker;

  @override
  void initState() {
    super.initState();
    _showConversationListOnMobile = widget.initialRoomId == null;
    _conversationSearchController.addListener(() {
      setState(() {
        _conversationSearchQuery = _conversationSearchController.text
            .trim()
            .toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _conversationSearchController.dispose();
    _recordingTicker?.cancel();
    _voiceRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthBloc>().state.user;

    return BlocProvider(
      create: (context) =>
          MessagesBloc(context.read<MessagesRepository>())..add(
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
              if (state.status == MessagesStatus.failure &&
                  state.errorMessage != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
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
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _conversationsList(
                                    context,
                                    conversations,
                                    activeRoomId,
                                  ),
                          ),
                        ],
                      ),
                    ),
                    VerticalDivider(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
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
                          : _conversationsList(
                              context,
                              conversations,
                              activeRoomId,
                            ),
                    ),
                  ],
                );
              }

              return _chatPanel(
                context,
                state,
                activeRoomId,
                currentUserId: currentUserId,
                onBackMobile: () =>
                    setState(() => _showConversationListOnMobile = true),
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
          subtitle: count == 0
              ? 'Aucune conversation'
              : '$count conversation${count > 1 ? 's' : ''} en cours',
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
              .where(
                (c) => c.otherUserName.toLowerCase().contains(
                  _conversationSearchQuery,
                ),
              )
              .toList();

    Future<void> onRefresh() async {
      context.read<MessagesBloc>().add(
        const MessagesConversationsRefreshRequested(),
      );
    }

    if (filtered.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 96, horizontal: 24),
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
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
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
              foregroundImage:
                  (conv.otherUserAvatarUrl != null &&
                      conv.otherUserAvatarUrl!.isNotEmpty)
                  ? NetworkImage(conv.otherUserAvatarUrl!)
                  : null,
              child: Text(
                conv.otherUserName.isEmpty
                    ? 'U'
                    : conv.otherUserName[0].toUpperCase(),
              ),
            ),
            title: Text(
              conv.otherUserName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              subtitleText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: unread
                  ? TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    )
                  : null,
            ),
            trailing: unread
                ? SizedBox(
                    width: 32,
                    height: 19,
                    child: Container(
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
                    ),
                  )
                : null,
            onTap: () {
              setState(() {
                _editingMessageId = null;
                _messageController.clear();
                _isComposing = false;
              });
              context.read<MessagesBloc>().add(
                MessagesConversationOpened(conv.roomId),
              );
              context.read<MessagesBloc>().add(
                const MessagesReplyToRequested(null),
              );
              setState(() => _showConversationListOnMobile = false);
            },
          );
        },
      ),
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
    final activeConversation = _conversationForRoom(
      state.conversations,
      activeRoomId,
    );
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
                  foregroundImage:
                      (activeConversation.otherUserAvatarUrl != null &&
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
                            : (activeConversation.requestTitle
                                          ?.trim()
                                          .isNotEmpty ==
                                      true
                                  ? 'Poste concerné: ${activeConversation.requestTitle}'
                                  : 'Conversation liée à une demande'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: state.isOtherTyping
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          fontStyle: state.isOtherTyping
                              ? FontStyle.italic
                              : null,
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
                    context.read<MessagesBloc>().add(
                      const MessagesReconnectRequested(),
                    );
                  },
                  child: const Text('Reconnecter'),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              if (activeRoomId == null) return;
              context.read<MessagesBloc>().add(
                MessagesHistoryRefreshRequested(activeRoomId),
              );
            },
            child: ListView.builder(
              reverse: true,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: timeline.length,
              itemBuilder: (context, index) {
                final item = timeline[timeline.length - 1 - index];

                if (item is DateTime) {
                  return _DateSeparator(date: item);
                }

                final message = item as ChatMessage;
                final mine =
                    currentUserId != null && message.senderId == currentUserId;
                return _MessageBubble(
                  message: message,
                  mine: mine,
                  currentUserId: currentUserId,
                  onLongPress: activeRoomId == null
                      ? null
                      : () => _showMessageActions(context, message, mine),
                );
              },
            ),
          ),
        ),
        if (activeRoomId != null) _composerContextBar(context, state),
        _composerRow(context, activeRoomId),
      ],
    );
  }

  Widget _composerContextBar(BuildContext context, MessagesState state) {
    final theme = Theme.of(context);

    String? label;
    IconData icon = Icons.reply;
    VoidCallback? onCancel;

    if (_editingMessageId != null) {
      label = 'Modifier le message';
      icon = Icons.edit_outlined;
      onCancel = () {
        setState(() {
          _editingMessageId = null;
          _messageController.clear();
          _isComposing = false;
        });
      };
    } else if (state.replyingTo != null) {
      final reply = state.replyingTo!;
      label = reply.isDeleted
          ? 'Message supprimé'
          : (reply.content.trim().isNotEmpty
                ? reply.content.trim()
                : (reply.isVoice ? '🎤 Message vocal' : '📷 Photo'));
      icon = Icons.reply;
      onCancel = () => context.read<MessagesBloc>().add(
        const MessagesReplyToRequested(null),
      );
    }

    if (label == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: theme.colorScheme.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close, size: 18),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _composerRow(BuildContext context, String? activeRoomId) {
    final theme = Theme.of(context);

    if (_isRecording) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            IconButton(
              onPressed: _cancelRecording,
              icon: Icon(Icons.delete_outline, color: theme.colorScheme.error),
            ),
            const SizedBox(width: 4),
            Container(
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(_formatElapsed(_recordingElapsed)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Enregistrement en cours...',
                style: theme.textTheme.bodySmall,
              ),
            ),
            IconButton.filled(
              onPressed: activeRoomId == null
                  ? null
                  : () => _stopAndSendRecording(context, activeRoomId),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      );
    }

    return Padding(
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
                  setState(() => _isComposing = composing);
                  if (activeRoomId != null) {
                    context.read<MessagesBloc>().add(
                      MessagesTypingRequested(composing),
                    );
                  }
                }
              },
              decoration: InputDecoration(
                hintText: _editingMessageId != null
                    ? 'Modifier votre message...'
                    : 'Votre message...',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: activeRoomId == null
                ? null
                : () {
                    if (_isComposing) {
                      _sendCurrentText(context, activeRoomId);
                    } else {
                      _startRecording();
                    }
                  },
            icon: Icon(_isComposing ? Icons.send : Icons.mic),
          ),
        ],
      ),
    );
  }

  void _sendCurrentText(BuildContext context, String roomId) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    if (_editingMessageId != null) {
      context.read<MessagesBloc>().add(
        MessagesEditRequested(messageId: _editingMessageId!, content: text),
      );
      setState(() => _editingMessageId = null);
    } else {
      final replyToId = context.read<MessagesBloc>().state.replyingTo?.id;
      context.read<MessagesBloc>().add(
        MessagesSendRequested(
          roomId: roomId,
          content: text,
          replyToId: replyToId,
        ),
      );
    }
    _messageController.clear();
    setState(() => _isComposing = false);
  }

  Future<void> _startRecording() async {
    try {
      await _voiceRecorder.startRecording();
      if (!mounted) return;
      setState(() {
        _isRecording = true;
        _recordingElapsed = Duration.zero;
      });
      _recordingTicker?.cancel();
      _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() => _recordingElapsed += const Duration(seconds: 1));
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _stopAndSendRecording(
    BuildContext context,
    String roomId,
  ) async {
    _recordingTicker?.cancel();
    final duration = _recordingElapsed;
    final path = await _voiceRecorder.stopRecording();
    if (!mounted || !context.mounted) return;
    setState(() => _isRecording = false);

    if (path == null || duration.inSeconds < 1) {
      return;
    }

    final replyToId = context.read<MessagesBloc>().state.replyingTo?.id;
    context.read<MessagesBloc>().add(
      MessagesVoiceSendRequested(
        roomId: roomId,
        filePath: path,
        durationSeconds: duration.inSeconds.toDouble(),
        replyToId: replyToId,
      ),
    );
  }

  Future<void> _cancelRecording() async {
    _recordingTicker?.cancel();
    await _voiceRecorder.cancelRecording();
    if (!mounted) return;
    setState(() => _isRecording = false);
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
      final replyToId = context.read<MessagesBloc>().state.replyingTo?.id;
      context.read<MessagesBloc>().add(
        MessagesImageSendRequested(
          roomId: roomId,
          filePath: file.path,
          replyToId: replyToId,
        ),
      );
    } on PlatformException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selection d\'image indisponible: ${e.message ?? e.code}',
          ),
        ),
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
    if (!_isComposing) {
      setState(() => _isComposing = true);
    }
  }

  Future<void> _showMessageActions(
    BuildContext context,
    ChatMessage message,
    bool mine,
  ) async {
    final canEdit =
        mine &&
        !message.isDeleted &&
        (message.mediaUrl == null || message.mediaUrl!.isEmpty) &&
        message.content.trim().isNotEmpty;
    final canDelete = mine && !message.isDeleted;
    final theme = Theme.of(context);
    final bloc = context.read<MessagesBloc>();

    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 10,
                children: _quickReactions
                    .map(
                      (emoji) => InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          bloc.add(
                            MessagesReactionToggled(
                              messageId: message.id,
                              emoji: emoji,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 26),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(height: 1),
            ),
            if (!message.isDeleted)
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Répondre'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  setState(() {
                    _editingMessageId = null;
                    _messageController.clear();
                    _isComposing = false;
                  });
                  bloc.add(MessagesReplyToRequested(message));
                },
              ),
            if (canEdit)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  bloc.add(const MessagesReplyToRequested(null));
                  setState(() {
                    _editingMessageId = message.id;
                    _messageController.text = message.content;
                    _messageController.selection = TextSelection.collapsed(
                      offset: message.content.length,
                    );
                    _isComposing = message.content.trim().isNotEmpty;
                  });
                },
              ),
            if (canDelete)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Supprimer',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  bloc.add(MessagesDeleteRequested(message.id));
                },
              ),
          ],
        ),
      ),
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

  Conversation? _conversationForRoom(
    List<Conversation> conversations,
    String? roomId,
  ) {
    if (roomId == null || roomId.isEmpty) {
      return null;
    }

    try {
      return conversations.firstWhere(
        (conversation) => conversation.roomId == roomId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Barre plate (pas de degrade) pour la vue d'une conversation ouverte,
  /// distincte de l'en-tete de marque utilise sur la liste des conversations.
  Widget _chatTopBar(
    BuildContext context,
    String title, {
    VoidCallback? onBack,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.mine,
    required this.currentUserId,
    required this.onLongPress,
  });

  final ChatMessage message;
  final bool mine;
  final String? currentUserId;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;
    final bubbleBg = mine ? semantic.bubbleOut : semantic.bubbleIn;
    final bubbleFg = mine
        ? semantic.bubbleOutForeground
        : semantic.bubbleInForeground;
    final hasImage =
        !message.isDeleted &&
        message.mediaUrl != null &&
        message.mediaUrl!.isNotEmpty &&
        !message.isVoice;
    final hasVoice =
        !message.isDeleted && message.isVoice && message.mediaUrl != null;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onLongPress,
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
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.replyTo != null) _quotedBlock(context, bubbleFg),
              if (message.isDeleted)
                Text(
                  'Message supprimé',
                  style: TextStyle(
                    color: bubbleFg.withValues(alpha: 0.7),
                    fontStyle: FontStyle.italic,
                    fontSize: 13,
                  ),
                )
              else if (hasVoice)
                VoiceMessagePlayer(
                  url: message.mediaUrl!,
                  foregroundColor: bubbleFg,
                  durationSeconds: message.audioDurationSeconds,
                )
              else ...[
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
                if (message.content.trim().isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: hasImage ? 6 : 0),
                    child: Text(
                      message.content,
                      style: TextStyle(color: bubbleFg),
                    ),
                  ),
              ],
              if (!message.isDeleted && message.reactions.isNotEmpty)
                _reactionsRow(context, bubbleFg),
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
                    if (message.editedAt != null && !message.isDeleted) ...[
                      Text(
                        'modifié · ',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: bubbleFg.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
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
      ),
    );
  }

  Widget _quotedBlock(BuildContext context, Color bubbleFg) {
    final reply = message.replyTo!;
    final label = reply.content.trim().isNotEmpty
        ? reply.content.trim()
        : (reply.mediaType == 'audio' ? '🎤 Message vocal' : '📷 Photo');

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bubbleFg.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: bubbleFg.withValues(alpha: 0.6), width: 3),
        ),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: bubbleFg.withValues(alpha: 0.85), fontSize: 12),
      ),
    );
  }

  Widget _reactionsRow(BuildContext context, Color bubbleFg) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: message.reactions.entries.map((entry) {
          final mineReacted =
              currentUserId != null && entry.value.contains(currentUserId);
          final theme = Theme.of(context);
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.read<MessagesBloc>().add(
              MessagesReactionToggled(messageId: message.id, emoji: entry.key),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: mineReacted
                    ? theme.colorScheme.primary.withValues(alpha: 0.18)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: mineReacted
                    ? Border.all(color: theme.colorScheme.primary)
                    : null,
              ),
              child: Text(
                '${entry.key} ${entry.value.length}',
                style: const TextStyle(fontSize: 11),
              ),
            ),
          );
        }).toList(),
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
          child: Text(_label(), style: Theme.of(context).textTheme.labelSmall),
        ),
      ),
    );
  }
}
