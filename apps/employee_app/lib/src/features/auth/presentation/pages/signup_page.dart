import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_client.dart' as sb;

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final formKey = GlobalKey<FormState>();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool loading = false;
  bool submitted = false;
  String? error;

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('EMPLOYEE SIGN UP')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: submitted
                    ? _RequestSent(
                        title: 'Request Sent',
                        message:
                            'Your account request has been sent. An administrator can approve it from Supabase Table Editor by setting your profile status to ACTIVE.',
                        onBackToLogin: () => context.go('/login'),
                      )
                    : Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Request Employee Access'.toUpperCase(),
                              style: theme.textTheme.headlineLarge,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: nameCtrl,
                              enabled: !loading,
                              validator: _required,
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: phoneCtrl,
                              enabled: !loading,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Phone',
                                prefixIcon: Icon(Icons.phone_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: emailCtrl,
                              enabled: !loading,
                              keyboardType: TextInputType.emailAddress,
                              validator: _email,
                              decoration: const InputDecoration(
                                labelText: 'Work email',
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: passwordCtrl,
                              enabled: !loading,
                              obscureText: true,
                              validator: _password,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 12),
                              Text(
                                error!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: loading ? null : _submit,
                                child: loading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('SEND REQUEST'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                onPressed: loading
                                    ? null
                                    : () => context.go('/login'),
                                child: const Text('Back to login'),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final SupabaseClient supabase = sb.supabase;
      final response = await supabase.auth.signUp(
        email: emailCtrl.text.trim(),
        password: passwordCtrl.text,
        data: {
          'full_name': nameCtrl.text.trim(),
          'phone': phoneCtrl.text.trim(),
          'requested_app': 'employee_app',
        },
      );

      final userId = response.user?.id;
      if (userId != null && response.session != null) {
        await supabase
            .from('profiles')
            .update({
              'full_name': nameCtrl.text.trim(),
              'phone': phoneCtrl.text.trim(),
              'email': emailCtrl.text.trim(),
              'role': 'EMPLOYEE',
              'status': 'PENDING',
              'meta': {'requested_app': 'employee_app'},
            })
            .eq('auth_user_id', userId);
        await supabase.auth.signOut();
      }

      if (!mounted) return;
      setState(() {
        submitted = true;
        loading = false;
      });
    } on AuthException catch (e) {
      setState(() {
        loading = false;
        error = e.message;
      });
    } catch (e) {
      setState(() {
        loading = false;
        error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  String? _required(String? value) {
    if ((value ?? '').trim().isEmpty) {
      return 'Required';
    }
    return null;
  }

  String? _email(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Required';
    }
    if (!text.contains('@')) {
      return 'Enter a valid email';
    }
    return null;
  }

  String? _password(String? value) {
    if ((value ?? '').length < 6) {
      return 'Use at least 6 characters';
    }
    return null;
  }
}

class _RequestSent extends StatelessWidget {
  const _RequestSent({
    required this.title,
    required this.message,
    required this.onBackToLogin,
  });

  final String title;
  final String message;
  final VoidCallback onBackToLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          color: theme.colorScheme.primary,
          size: 56,
        ),
        const SizedBox(height: 16),
        Text(title.toUpperCase(), style: theme.textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onBackToLogin,
            child: const Text('BACK TO LOGIN'),
          ),
        ),
      ],
    );
  }
}
