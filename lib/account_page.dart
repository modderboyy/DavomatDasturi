import 'package:flutter/cupertino.dart';
import 'package:DavomatYettilik/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  String? userName;
  String? userRole;
  String? userAvatarUrl;
  String message = '';

  @override
  void initState() {
    super.initState();
    _loadCachedUserData();
    _loadUserData();
  }

  Future<void> _loadCachedUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('userName');
      userRole = prefs.getString('userRole');
      userAvatarUrl = prefs.getString('userAvatarUrl');
    });
  }

  Future<void> _loadUserData() async {
    try {
      final userId = supabase.auth.currentUser!.id;
      print('Foydalanuvchi ID: $userId');

      final response = await supabase
          .from('users')
          .select('name, lavozim, avatar')
          .eq('id', userId)
          .single();

      print('Supabase javobi: $response');

      if (mounted) {
        setState(() {
          userName = response['name'] as String?;
          userRole = response['lavozim'] as String?;
          userAvatarUrl = response['avatar'] as String?;
          print(
              'State yangilandi: userName: $userName, userRole: $userRole, userAvatarUrl: $userAvatarUrl');
        });
        _cacheUserData();
      }
    } catch (error) {
      print("Foydalanuvchi ma'lumotlarini yuklashda xatolik: $error");
      setState(() {
        message = 'Foydalanuvchi ma\'lumotlarini yuklashda xatolik!';
      });
    }
  }

  Future<void> _cacheUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (userName != null) {
      await prefs.setString('userName', userName!);
    }
    if (userRole != null) {
      await prefs.setString('userRole', userRole!);
    }
    if (userAvatarUrl != null) {
      await prefs.setString('userAvatarUrl', userAvatarUrl!);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('AccountPage build() funksiyasi ishga tushdi');
    final theme = CupertinoTheme.of(context);
    final isDarkMode =
        theme.brightness == Brightness.dark; // Qora rejim tekshiruvi

    // Matn rangi uchun o'zgaruvchi, qora rejimda oq, oq rejimda qora
    final textColor =
        isDarkMode ? CupertinoColors.white : CupertinoColors.black;
    final secondaryTextColor = isDarkMode
        ? CupertinoColors.white.withOpacity(0.8)
        : CupertinoColors.black.withOpacity(0.8);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Account'),
        backgroundColor: theme.barBackgroundColor,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              userAvatarUrl != null && userAvatarUrl!.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(
                          30), // Avatarni rounded qilish uchun radiusni kamaytirdik
                      child: Image.network(
                        userAvatarUrl!,
                        width:
                            150, // Avatarni biroz kichraytirdik, chunki rounded qildik
                        height:
                            150, // Avatarni biroz kichraytirdik, chunki rounded qildik
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            CupertinoIcons.person_circle_fill,
                            size:
                                150, // Avatarni biroz kichraytirdik, chunki rounded qildik
                            color: CupertinoColors.systemGrey,
                          );
                        },
                      ),
                    )
                  : const Icon(
                      CupertinoIcons.person_circle_fill,
                      size:
                          150, // Avatarni biroz kichraytirdik, chunki rounded qildik
                      color: CupertinoColors.systemGrey,
                    ),
              const SizedBox(height: 20),
              Text(
                'Ism-familiya:',
                style: TextStyle(
                  fontSize: 20, // Matn hajmini kattalashtirdik
                  color: secondaryTextColor, // O'zgaruvchi rang
                ),
              ),
              Text(
                userName != null
                    ? userName!
                    : 'Foydalanuvchi nomi yuklanmoqda...',
                style: TextStyle(
                  fontSize: 24, // Matn hajmini kattalashtirdik
                  fontWeight: FontWeight.bold,
                  color: textColor, // O'zgaruvchi rang
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Lavozim:',
                style: TextStyle(
                  fontSize: 18, // Matn hajmini kattalashtirdik
                  color: secondaryTextColor, // O'zgaruvchi rang
                ),
              ),
              Text(
                userRole != null ? userRole! : 'Lavozim yuklanmoqda...',
                style: TextStyle(
                  fontSize: 20, // Matn hajmini kattalashtirdik
                  color: textColor, // O'zgaruvchi rang
                ),
              ),
              const SizedBox(height: 20),
              SizedBox.shrink(),
            ],
          ),
        ),
      ),
    );
  }
}
