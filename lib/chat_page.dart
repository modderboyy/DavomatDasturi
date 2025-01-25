// chat_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // Import foundation for ChangeNotifier  <-- IMPORT ChangeNotifier

// Note: telegram: ^0.0.7 is a very old and basic package.
// It might not directly support displaying Telegram groups by username
// in the way modern Telegram clients do.
// This example will demonstrate basic usage based on the package's capabilities.
// If you need more advanced features or group display, you might need to
// explore more recent Telegram API wrappers or consider using the official
// Telegram Bot API or TDLib directly, which would be significantly more complex.

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _searchController = TextEditingController();
  List<String> _messages =
      []; // Placeholder for messages (if you can fetch any)

  @override
  void initState() {
    super.initState();
    _loadChat(); // Try to load chat data when the page initializes
  }

  Future<void> _loadChat() async {
    // *** IMPORTANT ***
    // The `telegram: ^0.0.7` package is very basic. It might not have features
    // to directly fetch messages from a group by username like '@mustaqillikdavomattizimi'.
    // You would typically need to authenticate a user and potentially use
    // methods to interact with chats/channels based on what the package offers.

    // Placeholder for attempting to interact with Telegram (if possible with this package)
    // This is likely where you would try to use the telegram package to
    // connect and fetch data, if it supports such operations.

    // For this example, we'll just add some placeholder messages.
    setState(() {
      _messages = [
        'Telegram chat functionality is limited with telegram: ^0.0.7.',
        'This package is very old and might not support modern Telegram features.',
        'Consider exploring more recent Telegram API solutions for robust chat features.',
        'For now, this is a placeholder Chat page.',
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Telegram Chat'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.search),
          onPressed: () {
            _showSearchDialog();
          },
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _messages.isEmpty
                  ? const Center(child: Text('Chat yuklanmoqda...'))
                  : ListView.builder(
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(_messages[index]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSearchDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: const Text('Qidiruv'),
          content: CupertinoTextField(
            controller: _searchController,
            placeholder: 'Xabarlarni qidirish...',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Bekor qilish'),
              onPressed: () {
                Navigator.pop(context);
                _searchController.clear();
              },
            ),
            CupertinoDialogAction(
              child: const Text('Qidirish'),
              isDefaultAction: true,
              onPressed: () {
                String searchText = _searchController.text;
                // *** IMPORTANT ***
                // Searching within Telegram messages directly using telegram: ^0.0.7
                // is likely NOT possible. This package is too basic.
                // This search functionality would require a more advanced Telegram API integration.

                // Placeholder for search logic (if you had Telegram message data)
                print('Qidiruv so\'rovi: $searchText');
                Navigator.pop(context);
                _searchController.clear();
                // In a real implementation, you would filter the messages here
                // or perform a Telegram API search if possible.
              },
            ),
          ],
        );
      },
    );
  }
}

class ChatDataProvider extends ChangeNotifier {
  // EXTEND ChangeNotifier HERE
  final SupabaseClient _supabaseClient;

  ChatDataProvider(this._supabaseClient);

  // You can add chat related data and functions here if needed in the future.
  // For this basic example with telegram: ^0.0.7, it might not be directly relevant.
}
