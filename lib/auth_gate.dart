// auth_gate.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'package:DavomatYettilik/main.dart'; // Loyiha nomingizga moslang

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoggedIn = false; // State to manage login status within AuthGate

  // Callback function to update login status from LoginPage
  void _setLoggedIn(bool loggedIn) {
    setState(() {
      _isLoggedIn = loggedIn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final session = snapshot.data!.session;
          if (session != null) {
            // User is logged in according to Supabase, update local state and show HomePage
            if (!_isLoggedIn) {
              // Prevent unnecessary rebuilds if already logged in
              _setLoggedIn(true);
            }
            return const HomePage();
          } else {
            // User is not logged in according to Supabase, show LoginPage with callback
            if (_isLoggedIn) {
              // Prevent unnecessary rebuilds if already logged out
              _setLoggedIn(false);
            }
            return LoginPage(
                onLoginSuccess: _setLoggedIn); // Pass the callback here
          }
        } else {
          // Initial loading state, or error.  You might want to show a loading indicator here.
          return const Center(
              child: CircularProgressIndicator()); // Example loading indicator
        }
      },
    );
  }
}
