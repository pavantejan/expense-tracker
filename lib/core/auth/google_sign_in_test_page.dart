import 'package:flutter/material.dart';

import 'google_auth_service.dart';

class GoogleSignInTestPage extends StatefulWidget {
  const GoogleSignInTestPage({super.key});

  @override
  State<GoogleSignInTestPage> createState() =>
      _GoogleSignInTestPageState();
}

class _GoogleSignInTestPageState
    extends State<GoogleSignInTestPage> {
  bool _loading = false;
  String _status = 'Not signed in';

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _status = 'Signing in...';
    });

    try {
      final user =
          await GoogleAuthService.instance.signIn();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = user == null
            ? 'Sign-in cancelled'
            : 'Signed in as ${user.email}';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Sign-in failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    setState(() {
      _loading = true;
      _status = 'Signing out...';
    });

    try {
      await GoogleAuthService.instance.signOut();

      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Signed out';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _status = 'Sign-out failed: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Google Sign-In Test'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _status,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _signIn,
                child: const Text('Sign in with Google'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading ? null : _signOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}