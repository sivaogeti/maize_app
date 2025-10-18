import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {


  String _role = 'Field Incharge';
  bool _busy = false;


  // Make sure these exist in your State class:
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

// Optional: if you use a form
  final _formKey = GlobalKey<FormState>();

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _handleLogin() async {
    // If using a form with validators:
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    final rawUsername = _usernameController.text.trim();   // e.g. "fic1" or "fic1@maizemate.local"
    final password     = _passwordController.text;

    try {
      await context.read<AuthService>()
          .login(username: rawUsername, password: password); // AuthService builds email if needed

      if (!mounted) return;
      // SUCCESS → navigate; DO NOT show any error snackbar here
      context.go('/');   // or context.pushReplacement('/')
    } on FirebaseAuthException {
      if (!mounted) return;
      _showSnack('Invalid username or password');   // only on failure
    } catch (e) {
      if (!mounted) return;
      _showSnack('Login failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo + brand
                      Column(
                        children: [
                          Image.asset(
                            'assets/images/maizemate_logo.png',
                            height: 84,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'MAIZEMATE',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: const Color(0xFF2E7D32),
                          ),
                      ),
                   ],
                ),
                      const SizedBox(height: 24),

                      // Username
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          hintText: 'e.g. fic1',
                          border: OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter username' : null,
                      ),
                      const SizedBox(height: 12),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        autofillHints: const [AutofillHints.password],
                        validator: (v) =>
                        (v == null || v.isEmpty) ? 'Enter password' : null,
                      ),
                      const SizedBox(height: 12),

                      // Role
                      DropdownButtonFormField<String>(
                        value: _role,
                        items: const [
                          DropdownMenuItem(
                              value: 'Field Incharge',
                              child: Text('Field Incharge')),
                          DropdownMenuItem(
                              value: 'Cluster Incharge',
                              child: Text('Cluster Incharge')),
                          DropdownMenuItem(
                              value: 'Technical Incharge',
                              child: Text('Technical Incharge')),
                          DropdownMenuItem(
                              value: 'Manager', child: Text('Manager')),
                          DropdownMenuItem(
                              value: 'Admin', child: Text('Admin')),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) => setState(() => _role = v ?? _role),
                      ),
                      const SizedBox(height: 20),

                      // Sign in button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _busy ? null : _handleLogin,
                          child: _busy
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                              : const Text('Sign in'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        'Demo users: fic1/fic@123, cic1/cic@123, tic1/tic@123, '
                            'support/help@123, manager/mgr@123, admin/admin@123, '
                            'farmer1/farm@123',
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
  }
}
