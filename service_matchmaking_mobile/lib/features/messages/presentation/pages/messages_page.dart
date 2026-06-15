import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/conversation.dart';
import '../../domain/repositories/messages_repository.dart';
import '../bloc/messages_bloc.dart';
import '../bloc/messages_event.dart';
import '../bloc/messages_state.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, this.initialRoomId});

  final String? initialRoomId;

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final _messageController = TextEditingController();
  bool _showConversationListOnMobile = true;
  bool _isComposing = false;

  @override
  void initState() {
    super.initState();
    _showConversationListOnMobile = widget.initialRoomId == null;
  }

  @override
  void dispose() {
    _messageController.dispose();
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
                          _header(context, 'Messages', onBack: () => context.pop()),
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
                    _header(context, 'Messages', onBack: () => context.pop()),
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

  Widget _conversationsList(
    BuildContext context,
    List<Conversation> conversations,
    String? activeRoomId,
  ) {
    return ListView.builder(
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conv = conversations[index];
        final selected = conv.roomId == activeRoomId;
        final subtitleParts = <String>[];
        if (conv.requestTitle != null && conv.requestTitle!.trim().isNotEmpty) {
          subtitleParts.add('Poste: ${conv.requestTitle!.trim()}');
        }
        if (conv.lastMessage != null && conv.lastMessage!.trim().isNotEmpty) {
          subtitleParts.add(conv.lastMessage!.trim());
        }
        return ListTile(
          selected: selected,
          leading: CircleAvatar(
            backgroundImage: conv.otherUserAvatarUrl != null
                ? NetworkImage(conv.otherUserAvatarUrl!)
                : null,
            child: conv.otherUserAvatarUrl == null
                ? Text(
                    conv.otherUserName.isEmpty ? 'U' : conv.otherUserName[0].toUpperCase(),
                  )
                : null,
          ),
          title: Text(conv.otherUserName),
          subtitle: subtitleParts.isEmpty
              ? const Text('Aucun message')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: subtitleParts
                      .map(
                        (line) => Text(
                          line,
                          maxLines: line.startsWith('Poste:') ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                      .toList(),
                ),
          trailing: conv.unreadCount > 0
              ? CircleAvatar(
                  radius: 11,
                  child: Text(
                    '${conv.unreadCount}',
                    style: const TextStyle(fontSize: 11),
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
    return Column(
      children: [
        _header(
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
                  backgroundImage: activeConversation.otherUserAvatarUrl != null
                      ? NetworkImage(activeConversation.otherUserAvatarUrl!)
                      : null,
                  child: activeConversation.otherUserAvatarUrl == null
                      ? Text(
                          activeConversation.otherUserName.isEmpty
                              ? 'U'
                              : activeConversation.otherUserName[0].toUpperCase(),
                        )
                      : null,
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
                        activeConversation.requestTitle?.trim().isNotEmpty == true
                            ? 'Poste concerné: ${activeConversation.requestTitle}'
                            : 'Conversation liée à une demande',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (hasActiveConversation)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: state.isSocketConnected
                ? Theme.of(context).colorScheme.tertiaryContainer
                : Theme.of(context).colorScheme.errorContainer,
            child: Row(
              children: [
                Icon(
                  state.isSocketConnected ? Icons.wifi : Icons.wifi_off,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    state.isSocketConnected
                        ? 'Connecte en temps reel'
                        : 'Connexion perdue. Tentative de reconnexion...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (!state.isSocketConnected)
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
            itemCount: state.activeMessages.length,
            itemBuilder: (context, index) {
              final message = state.activeMessages[state.activeMessages.length - 1 - index];
              final mine = currentUserId != null && message.senderId == currentUserId;
              final colors = Theme.of(context).colorScheme;
              return Align(
                alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: mine ? colors.primaryContainer : colors.surfaceContainerHighest,
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
                      Text(message.content),
                      const SizedBox(height: 6),
                      Text(
                        DateFormat('HH:mm').format(message.createdAt),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              if (_isComposing && hasActiveConversation)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      'Vous etes en train d\'ecrire...',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: activeRoomId != null,
                      onChanged: (value) {
                        final composing = value.trim().isNotEmpty;
                        if (composing != _isComposing) {
                          setState(() => _isComposing = composing);
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: 'Votre message...',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
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
                            if (_isComposing) {
                              setState(() => _isComposing = false);
                            }
                          },
                    icon: const Icon(Icons.send),
                    label: const Text('Envoyer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
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

  Widget _header(BuildContext context, String title, {VoidCallback? onBack}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
    );
  }
}
