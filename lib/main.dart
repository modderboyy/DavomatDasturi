// main.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Material needed for some widgets in chat_page (like Provider)
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart'; // Import Provider
import 'home_page.dart';
import 'account_page.dart';
import 'history_page.dart';
import 'login_page.dart';
import 'chat_page.dart'; // Ensure chat_page.dart is imported  <-- IMPORT CHAT PAGE

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // *** IMPORTANT: REPLACE THESE WITH YOUR ACTUAL SUPABASE KEYS ***
  const supabaseUrl =
      'https://kkhmbqabryruqxfiascm.supabase.co'; // Example URL - REPLACE THIS!
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtraG1icWFicnlydXF4Zmlhc2NtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzU5OTQ5OTMsImV4cCI6MjA1MTU3MDk5M30.0YPVTWKG3qMZ7J8twFjKWwVNNqqpz8YX3rkQiAiT2YQ'; // Example Anon Key - REPLACE THIS!
  // *** IMPORTANT: REPLACE THESE WITH YOUR ACTUAL SUPABASE KEYS ***

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'Davomat Tizimi',
      theme: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: CupertinoColors.activeBlue,
        barBackgroundColor: CupertinoColors.white,
        scaffoldBackgroundColor: CupertinoColors.systemGrey6,
        textTheme: CupertinoTextThemeData(
          primaryColor: CupertinoColors.black,
          textStyle: TextStyle(
            fontFamily: '.SF UI Display',
            color: CupertinoColors.black,
          ),
        ),
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentTab = 0;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  int _tapCount = 0;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final session = supabase.auth.currentSession;
    if (session != null) {
      _setLoggedIn(true);
    } else {
      _setLoggedIn(false);
    }
  }

  void _setLoggedIn(bool loggedIn) {
    setState(() {
      _isLoggedIn = loggedIn;
      _isLoading = false;
    });
  }

  void _handleTabTap() {
    DateTime now = DateTime.now();
    if (_lastTapTime != null && now.difference(_lastTapTime!).inSeconds < 2) {
      _tapCount++;
      if (_tapCount >= 15) {
        _logout();
        _tapCount = 0;
      }
    } else {
      _tapCount = 1;
    }
    _lastTapTime = now;
  }

  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });
    try {
      await supabase.auth.signOut();
      _setLoggedIn(false);
    } catch (error) {
      _setLoggedIn(false);
      print('Logout error: $error');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (!_isLoggedIn) {
      return LoginPage(onLoginSuccess: _setLoggedIn);
    }

    return GestureDetector(
      onTap: _handleTabTap,
      child: ChangeNotifierProvider<ChatDataProvider>(
        // SPECIFY TYPE ARGUMENT HERE
        create: (context) => ChatDataProvider(Supabase.instance.client),
        child: CupertinoTabScaffold(
          tabBar: CupertinoTabBar(
            backgroundColor: CupertinoColors.systemBackground
                .resolveFrom(context)
                .withOpacity(0.95),
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.home),
                label: 'Bosh sahifa',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.time),
                label: 'Tarix',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.chat_bubble_2),
                label: 'Chat',
              ),
              BottomNavigationBarItem(
                icon: Icon(CupertinoIcons.person_crop_circle),
                label: 'Profil',
              ),
            ],
          ),
          tabBuilder: (BuildContext context, int index) {
            return CupertinoTabView(
              builder: (context) {
                switch (index) {
                  case 0:
                    return _buildPageWithTransition(const HomePage());
                  case 1:
                    return _buildPageWithTransition(const HistoryPage());
                  case 2:
                    return _buildPageWithTransition(
                        const ChatPage()); // ChatPage() is used here
                  case 3:
                    return _buildPageWithTransition(const AccountPage());
                  default:
                    return _buildPageWithTransition(
                        const Center(child: Text('Sahifa topilmadi')));
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageWithTransition(Widget page) {
    return CupertinoPageScaffold(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        child: page,
      ),
    );
  }
}
