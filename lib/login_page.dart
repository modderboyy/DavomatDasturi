// login_page.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Material importni saqlab qoling SnackBar uchun
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:logger/logger.dart';
import 'package:DavomatYettilik/main.dart'; // Loyiha nomingizga moslang

class LoginPage extends StatefulWidget {
  final void Function(bool) onLoginSuccess; // Callback funksiyasi

  const LoginPage(
      {super.key, required this.onLoginSuccess}); // Konstruktorga qo'shish

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final _logger = Logger();

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();
        final response = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (response.session != null) {
          // Login harakatini loglash
          await supabase.from('login_activities').insert({
            'user_id': response.user!.id,
            'login_time': DateTime.now().toIso8601String(),
            'success': true,
          });
          _logger.i('Foydalanuvchi tizimga kirdi: ${response.user!.id}');
          widget.onLoginSuccess(
              true); // Callback funksiyasini chaqirish, true - login muvaffaqiyatli
        }
      } on AuthException catch (error) {
        _logger.e('Kirish xatosi: ${error.message}');
        if (context.mounted) {
          // Context hali ham mavjudligini tekshirish
          ScaffoldMessenger.of(context).showSnackBar(
            // Material Snackbar dan foydalanamiz
            SnackBar(
              content: Text(error.message),
              backgroundColor: Colors.red,
            ),
          );
        }
        // Login harakatini loglash (muvaffaqiyatsiz)
        final email = _emailController.text.trim();
        try {
          final user = await supabase
              .from(
                  'profiles') // Odatda foydalanuvchi ma'lumotlari boshqa jadvalda saqlanadi
              .select('id')
              .eq('email', email)
              .maybeSingle();
          if (user != null) {
            await supabase.from('login_activities').insert({
              'user_id': user['id'],
              'login_time': DateTime.now().toIso8601String(),
              'success': false,
            });
          }
        } catch (logError) {
          _logger.e('Login logini yozishda xatolik: $logError');
        }
      } catch (error) {
        _logger.e('Kutilmagan xatolik: $error');
        if (context.mounted) {
          // Context hali ham mavjudligini tekshirish
          ScaffoldMessenger.of(context).showSnackBar(
            // Material Snackbar dan foydalanamiz
            const SnackBar(
              content: Text('Kutilmagan xatolik yuz berdi'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          // Widget hali ham ekranda ekanligini tekshirish
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = CupertinoTheme.of(context); // Theme ni olish
    final isDarkMode = theme.brightness == Brightness.dark;
    final textColor =
        isDarkMode ? CupertinoColors.white : CupertinoColors.black;

    return CupertinoPageScaffold(
      // CupertinoPageScaffold o'rniga Scaffold
      navigationBar: CupertinoNavigationBar(
        // CupertinoNavigationBar o'rniga AppBar
        middle: const Text('Kirish'),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoTextFormFieldRow(
                  // CupertinoTextFormFieldRow o'rniga TextFormField
                  prefix: const Icon(CupertinoIcons
                      .mail_solid), // CupertinoIcons o'rniga Icons
                  placeholder: 'Email', // InputDecoration o'rniga placeholder
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style:
                      TextStyle(color: textColor), //  Dynamic text color here
                  placeholderStyle: theme.textTheme.textStyle.copyWith(
                      color: CupertinoColors
                          .placeholderText), // Placeholder text color
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Emailni kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                CupertinoTextFormFieldRow(
                  // CupertinoTextFormFieldRow o'rniga TextFormField
                  obscureText: true,
                  prefix: const Icon(CupertinoIcons
                      .padlock_solid), // CupertinoIcons o'rniga Icons
                  placeholder: 'Parol', // InputDecoration o'rniga placeholder
                  controller: _passwordController,
                  style: TextStyle(color: textColor), // Dynamic text color here
                  placeholderStyle: theme.textTheme.textStyle.copyWith(
                      color: CupertinoColors
                          .placeholderText), // Placeholder text color
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Parolni kiriting';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                CupertinoButton.filled(
                  // CupertinoButton.filled o'rniga ElevatedButton
                  onPressed: _isLoading ? null : _signIn,
                  child: _isLoading
                      ? const CupertinoActivityIndicator() // CupertinoActivityIndicator o'rniga CircularProgressIndicator
                      : const Text('Kirish'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
