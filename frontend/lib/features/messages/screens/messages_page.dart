import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/auth_provider.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final ApiService _api = ApiService();
  List<dynamic> _conversations = [];
  Map<String, dynamic>? _selectedConversation;
  List<dynamic> _messages = [];
  final TextEditingController _messageController = TextEditingController();
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _fetchConversations() async {
    try {
      setState(() => _loading = true);
      // TODO: Implement getConversations API endpoint
      final data = <dynamic>[];
      setState(() {
        _conversations = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchMessages(String conversationId) async {
    try {
      // TODO: Implement getMessages API endpoint
      final data = <dynamic>[];
      setState(() => _messages = data);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _selectedConversation == null) return;

    final message = _messageController.text;
    _messageController.clear();

    setState(() => _sending = true);

    try {
      // TODO: Implement sendMessage API endpoint
      await Future.delayed(const Duration(milliseconds: 500));
      await _fetchMessages(_selectedConversation!['id']);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedConversation == null ? 'Messages' : _selectedConversation!['participants'][0]['name'] ?? ''),
        leading: _selectedConversation != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedConversation = null;
                  _messages = [];
                }),
              )
            : null,
      ),
      body: _selectedConversation == null
          ? _buildConversationList()
          : _buildChatThread(),
    );
  }

  Widget _buildConversationList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_conversations.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.message, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No conversations yet'),
            SizedBox(height: 8),
            Text(
              'Start chatting with sellers!',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final otherUser = conversation['participants']?[0];
        final lastMessage = conversation['last_message'];

        return ListTile(
          leading: CircleAvatar(
            backgroundImage: otherUser?['avatar'] != null
                ? NetworkImage(otherUser['avatar'])
                : null,
            child: otherUser?['avatar'] == null
                ? Text(otherUser?['name']?[0] ?? 'U')
                : null,
          ),
          title: Text(otherUser?['name'] ?? 'Unknown'),
          subtitle: Text(
            lastMessage?['content'] ?? 'No messages yet',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            setState(() => _selectedConversation = conversation);
            _fetchMessages(conversation['id']);
          },
        );
      },
    );
  }

  Widget _buildChatThread() {
    final user = context.watch<AuthProvider>().user;
    final otherUser = _selectedConversation!['participants']?[0];

    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(child: Text('No messages yet'))
              : ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[_messages.length - 1 - index];
                    final isMe = message['sender_id'] == user?.id;

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.7,
                        ),
                        decoration: BoxDecoration(
                          color: isMe
                              ? AppColors.electricBlue
                              : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          message['content'] ?? '',
                          style: TextStyle(
                            color: isMe ? Colors.white : null,
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(26),
                offset: const Offset(0, -2),
                blurRadius: 4,
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sending ? null : _sendMessage,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
