// main.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:animate_do/animate_do.dart'; // Import animate_do
// import 'package:motion/motion.dart'; // Remove unused import: motion

import 'home_page.dart';
import 'account_page.dart';
import 'history_page.dart';
import 'login_page.dart';
import 'chat_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // *** IMPORTANT: REPLACE THESE WITH YOUR ACTUAL SUPABASE KEYS ***
  const supabaseUrl = 'https://kkhmbqabryruqxfiascm.supabase.co';
  const supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtraG1icWFicnlydXF4Zmlhc2NtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzU5OTQ5OTMsImV4cCI6MjA1MTU3MDk5M30.0YPVTWKG3qMZ7J8twFjKWwVNNqqpz8YX3rkQiAiT2YQ';
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
      // Removed MotionApp wrapper
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

class _MainPageState extends State<MainPage> with TickerProviderStateMixin {
  // TickerProviderStateMixin qo'shish
  int _currentTab = 0;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  int _tapCount = 0;
  DateTime? _lastTapTime;

  // *** START VERSION CHECK IMPLEMENTATION ***
  String currentAppVersion = '1.0.0';
  // *** END VERSION CHECK IMPLEMENTATION ***

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _checkAppUpdate();
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
      // Removed unnecessary null check
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

  // *** START VERSION CHECK IMPLEMENTATION ***
  Future<void> _checkAppUpdate() async {
    try {
      final updates = await supabase
          .from('updates')
          .select()
          .eq('old_version', currentAppVersion)
          .single();

      if (updates != null) {
        final latestVersion = updates['latest_version'] as String?;
        final updateLink = updates['update_link'] as String?;

        if (latestVersion != null && updateLink != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showUpdateDialog(latestVersion, updateLink);
          });
        }
      }
    } catch (error) {
      print('Failed to check for updates: $error');
    }
  }

  Future<void> _showUpdateDialog(
      String latestVersion, String updateLink) async {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Yangi versiya mavjud!'),
        content: Text(
            'Dasturning yangi versiyasi ($latestVersion) chiqdi. Yangilashni xohlaysizmi?'),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('Bekor qilish'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Yangilash'),
            onPressed: () {
              _launchUpdateLink(updateLink);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _launchUpdateLink(String updateLink) async {
    final Uri url = Uri.parse(updateLink);

    if (await canLaunchUrl(url)) {
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        print('URLni ochishda xatolik: $e');
        _showErrorDialog(
            'Yangilanish linkini ochishda xatolik yuz berdi: ${e.toString()}');
      }
    } else {
      print('Yangilanish linkini ochib bo\'lmadi: $updateLink');
      _showErrorDialog(
          'Yangilanish linkini ochib bo\'lmadi. Link noto\'g\'ri bo\'lishi mumkin.');
    }
  }

  Future<void> _showErrorDialog(String message) async {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext context) => CupertinoAlertDialog(
        title: const Text('Xatolik'),
        content: Text(message),
        actions: <CupertinoDialogAction>[
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
  // *** END VERSION CHECK IMPLEMENTATION ***

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CupertinoPageScaffold(
        child: Center(child: CupertinoActivityIndicator()),
      );
    }

    if (!_isLoggedIn) {
      return FadeIn(
        // LoginPage FadeIn animatsiyasi bilan
        child: LoginPage(onLoginSuccess: _setLoggedIn),
      );
    }

    return GestureDetector(
      onTap: _handleTabTap,
      child: ChangeNotifierProvider<ChatDataProvider>(
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
                    return _buildPageWithAnimation(
                        const HomePage()); // Animatsiyalangan sahifalar
                  case 1:
                    return _buildPageWithAnimation(const HistoryPage());
                  case 2:
                    return _buildPageWithAnimation(const ChatPage());
                  case 3:
                    return _buildPageWithAnimation(const AccountPage());
                  default:
                    return _buildPageWithAnimation(
                        const Center(child: Text('Sahifa topilmadi')));
                }
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildPageWithAnimation(Widget page) {
    return CupertinoPageScaffold(
      child: FadeIn(
        // Har bir sahifa uchun FadeIn animatsiyasi
        child: page,
        duration: const Duration(milliseconds: 400), // Animatsiya davomiyligi
        curve: Curves.easeInOut, // Animatsiya egri chizig'i
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
