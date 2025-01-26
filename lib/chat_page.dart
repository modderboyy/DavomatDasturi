import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh_flutter3/pull_to_refresh_flutter3.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import the notifications plugin

class ChatDataProvider extends ChangeNotifier {
  final SupabaseClient _client;
  List<ChatMessage> _messages = [];
  List<ChatMessage> get messages => _messages;

  bool _loading = false;
  bool get loading => _loading;
  late final RealtimeChannel _messagesChannel;

  final RefreshController refreshController =
      RefreshController(initialRefresh: false);

  final FlutterLocalNotificationsPlugin
      flutterLocalNotificationsPlugin = // Initialize plugin
      FlutterLocalNotificationsPlugin();

  ChatDataProvider(this._client) {
    _initializeNotifications(); // Initialize notifications
    _loadCachedMessages();
    fetchMessages();
    _setupMessageSubscription();
  }

  Future<void> _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings(
            'app_icon'); // replace 'app_icon' with your app's icon name
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
            android: initializationSettingsAndroid,
            iOS: initializationSettingsIOS);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Request permission for iOS and Android >= Android 13
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  Future<void> _showNotification(ChatMessage message) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'chat_channel_id', // id
      'Chat Messages', // name
      channelDescription: 'Channel for new chat messages', // description
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(
        android: androidNotificationDetails, iOS: DarwinNotificationDetails());
    await flutterLocalNotificationsPlugin.show(
        message
            .hashCode, // Unique ID for each notification, using message hashcode
        message.userName,
        message.text,
        notificationDetails,
        payload:
            'item x'); // You can add payload if you need to handle notification tap
  }

  void _setLoading(bool loading) {
    _loading = loading;
    notifyListeners();
  }

  Future<void> fetchMessages() async {
    _setLoading(true);
    try {
      final response = await _client.from('messages').select('''
      *,
      users (
        name,
        avatar
      )
      ''').order('created_at', ascending: false);

      if (response.isNotEmpty) {
        final fetchedMessages = response.map((e) {
          final user = e['users'] as Map<String, dynamic>?;
          final userName = user?['name'] as String? ?? '';
          final userAvatar = user?['avatar'] as String? ?? '';

          return ChatMessage.fromMap(e
            ..addAll({
              'user_name': userName,
              'user_avatar': userAvatar,
            }));
        }).toList();
        _messages = fetchedMessages;
        _cacheMessages(fetchedMessages);
        notifyListeners();
      } else {
        await _loadCachedMessages();
        notifyListeners();
      }
    } catch (error) {
      print('Error fetching messages: $error');
      await _loadCachedMessages();
      notifyListeners();
    } finally {
      _setLoading(false);
      refreshController.refreshCompleted();
    }
  }

  Future<void> _cacheMessages(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedMessages = jsonEncode(messages.map((e) => e.toMap()).toList());
    await prefs.setString('chat_messages', encodedMessages);
  }

  Future<void> _loadCachedMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedMessages = prefs.getString('chat_messages');
    if (cachedMessages != null) {
      final List<dynamic> decodedMessages = jsonDecode(cachedMessages);
      _messages = decodedMessages.map((e) => ChatMessage.fromMap(e)).toList();
      notifyListeners();
    }
  }

  void _setupMessageSubscription() {
    _messagesChannel = _client.realtime.channel('messages');
    _messagesChannel
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newMessage = ChatMessage.fromMap(payload.newRecord!);
            final userId = _client.auth.currentUser?.id;
            if (newMessage.userId != userId) {
              _messages.insert(0, newMessage);
              _cacheMessages(_messages);
              notifyListeners();
              _showNotification(
                  newMessage); // Show notification for new message from others
            }
          },
        )
        .subscribe();
  }

  Future<void> sendMessage(String text, String? audioUrl) async {
    final userId = _client.auth.currentUser!.id;
    final user = await _client
        .from('users')
        .select('name, avatar')
        .eq('id', userId)
        .single();

    final userName = user['name'] as String? ?? '';
    final userAvatar = user['avatar'] as String? ?? '';

    final message = {
      'user_id': userId,
      'text': text,
      'created_at': DateTime.now().toIso8601String(),
      'audio_url': audioUrl,
    };

    try {
      final response =
          await _client.from('messages').insert(message).select().single();
      final newMessage = ChatMessage.fromMap(response
        ..addAll({
          'user_name': userName,
          'user_avatar': userAvatar,
        }));
      _messages.insert(0, newMessage);
      _cacheMessages(_messages);
      notifyListeners();
    } catch (error) {
      print('Error sending message: $error');
    }
  }

  Future<void> updateMessage(ChatMessage message, String newText) async {
    try {
      await _client
          .from('messages')
          .update({'text': newText}).eq('id', message.id);

      final index = _messages.indexOf(message);
      if (index != -1) {
        _messages[index] = message.copyWith(text: newText);
        _cacheMessages(_messages);
        notifyListeners();
      }
    } catch (error) {
      print('Error updating message: $error');
    }
  }

  Future<void> deleteMessage(ChatMessage message) async {
    try {
      await _client.from('messages').delete().eq('id', message.id);
      _messages.remove(message);
      _cacheMessages(_messages);
      notifyListeners();
    } catch (error) {
      print('Error deleting message: $error');
    }
  }

  @override
  void dispose() {
    _client.removeChannel(_messagesChannel);
    refreshController.dispose();
    super.dispose();
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Guruh Chat'),
      ),
      child:
          Consumer<ChatDataProvider>(builder: (context, chatProvider, child) {
        if (chatProvider.loading) {
          return const Center(
            child: CupertinoActivityIndicator(),
          );
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        return SafeArea(
          child: Material(
            child: Localizations(
              locale: const Locale('uz', 'UZ'),
              delegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              child: Container(
                color: CupertinoColors.systemGrey6,
                child: SmartRefresher(
                  controller: chatProvider.refreshController,
                  onRefresh: chatProvider.fetchMessages,
                  header: const MaterialClassicHeader(),
                  enablePullDown: true,
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: chatProvider.messages.length,
                          reverse: true,
                          itemBuilder: (context, index) {
                            final message = chatProvider.messages[index];
                            final isCurrentUser =
                                chatProvider._client.auth.currentUser?.id ==
                                    message.userId;
                            return _buildMessage(
                                message, chatProvider, isCurrentUser);
                          },
                        ),
                      ),
                      _buildInputArea(chatProvider),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMessage(
      ChatMessage message, ChatDataProvider chatProvider, bool isCurrentUser) {
    final formattedTime =
        DateFormat('HH:mm').format(message.createdAt.toLocal());
    return Align(
      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 8,
          bottom: 8,
          left: isCurrentUser ? 50 : 10,
          right: isCurrentUser ? 10 : 50,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrentUser
              ? CupertinoColors.activeBlue.withOpacity(0.8)
              : CupertinoColors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isCurrentUser ? const Radius.circular(12) : Radius.zero,
            bottomRight:
                isCurrentUser ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isCurrentUser)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    if (message.userAvatar.isNotEmpty)
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: NetworkImage(message.userAvatar),
                      ),
                    const SizedBox(width: 5),
                    Text(
                      message.userName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.text,
              style: const TextStyle(fontSize: 16),
            ),
            if (message.audioUrl != null)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.volume_up,
                      size: 18,
                    ),
                    Text(
                      'Audio',
                      style: TextStyle(
                          fontSize: 14, color: CupertinoColors.inactiveGray),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    formattedTime,
                    style: const TextStyle(
                      fontSize: 10,
                      color: CupertinoColors.systemGrey,
                    ),
                  ),
                  if (isCurrentUser) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _editMessage(context, message, chatProvider),
                      child: const Icon(
                        CupertinoIcons.pencil,
                        size: 16,
                        color: CupertinoColors.systemGrey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () =>
                          _deleteMessage(context, message, chatProvider),
                      child: const Icon(
                        CupertinoIcons.delete,
                        size: 16,
                        color: CupertinoColors.systemRed,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMessage(BuildContext context, ChatMessage message,
      ChatDataProvider chatProvider) async {
    final TextEditingController editController =
        TextEditingController(text: message.text);
    await showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Xabarni tahrirlash'),
          content: CupertinoTextField(controller: editController),
          actions: [
            CupertinoDialogAction(
              child: const Text('Bekor qilish'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              child: const Text('Saqlash'),
              onPressed: () async {
                final newText = editController.text.trim();
                if (newText.isNotEmpty && newText != message.text) {
                  await chatProvider.updateMessage(message, newText);
                }
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteMessage(BuildContext context, ChatMessage message,
      ChatDataProvider chatProvider) async {
    await showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Xabarni o‘chirish'),
          content: const Text(
              'Haqiqatan ham ushbu xabarni o‘chirishni xohlaysizmi?'),
          actions: [
            CupertinoDialogAction(
              child: const Text('Bekor qilish'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            CupertinoDialogAction(
              child: const Text(
                'O‘chirish',
                style: TextStyle(color: CupertinoColors.systemRed),
              ),
              onPressed: () async {
                await chatProvider.deleteMessage(message);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildInputArea(ChatDataProvider chatProvider) {
    return CupertinoTextField(
      controller: _messageController,
      placeholder: 'Xabar yozing...',
      onSubmitted: (text) async {
        if (text.isNotEmpty) {
          await chatProvider.sendMessage(text, null);
          _messageController.clear();
        }
      },
      suffix: CupertinoButton(
        padding: EdgeInsets.zero,
        child: const Icon(CupertinoIcons.arrow_right_circle_fill),
        onPressed: () async {
          final text = _messageController.text.trim();
          if (text.isNotEmpty) {
            await chatProvider.sendMessage(text, null);
            _messageController.clear();
          }
        },
      ),
    );
  }
}

class ChatMessage {
  final String id;
  final String userId;
  final String text;
  final DateTime createdAt;
  final String userName;
  final String userAvatar;
  final String? audioUrl;

  ChatMessage({
    required this.id,
    required this.userId,
    required this.text,
    required this.createdAt,
    required this.userName,
    required this.userAvatar,
    this.audioUrl,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'],
      userId: map['user_id'],
      text: map['text'] ?? '',
      createdAt: DateTime.parse(map['created_at']),
      userName: map['user_name'] ?? '',
      userAvatar: map['user_avatar'] ?? '',
      audioUrl: map['audio_url'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'text': text,
      'created_at': createdAt.toIso8601String(),
      'user_name': userName,
      'user_avatar': userAvatar,
      'audio_url': audioUrl,
    };
  }

  ChatMessage copyWith(
      {String? text, String? userName, String? userAvatar, String? audioUrl}) {
    return ChatMessage(
      id: id,
      userId: userId,
      text: text ?? this.text,
      createdAt: createdAt,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      audioUrl: audioUrl ?? this.audioUrl,
    );
  }
}
