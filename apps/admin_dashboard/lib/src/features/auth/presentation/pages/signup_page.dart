import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_client.dart' as sb;

class AdminSignUpPage extends ConsumerStatefulWidget {
  const AdminSignUpPage({super.key});

  @override
  ConsumerState<AdminSignUpPage> createState() => _AdminSignUpPageState();
}

class _AdminSignUpPageState extends ConsumerState<AdminSignUpPage> {
  final formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool submitted = false;
  String? error;

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hero = Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('ACCESS REQUEST', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 18),
                      Text('REQUEST', style: theme.textTheme.displayLarge),
                      Text('OPERATIONS', style: theme.textTheme.displayLarge),
                      Text('ACCESS', style: theme.textTheme.displayLarge),
                      const SizedBox(height: 20),
                      Text(
                        'Submit an access request. A super admin can approve it from Supabase Table Editor by setting your profile role and status.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                );
                final form = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: submitted ? _RequestSent() : _signUpForm(),
                  ),
                );

                if (constraints.maxWidth < 820) {
                  return ListView(
                    shrinkWrap: true,
                    children: [hero, const SizedBox(height: 16), form],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: hero),
                    const SizedBox(width: 24),
                    Expanded(child: form),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _signUpForm() {
    final theme = Theme.of(context);
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ADMIN SIGN UP', style: theme.textTheme.headlineLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: nameController,
            enabled: !loading,
            validator: _required,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              prefixIcon: Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            enabled: !loading,
            keyboardType: TextInputType.emailAddress,
            validator: _email,
            decoration: const InputDecoration(
              labelText: 'Work Email',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: phoneController,
            enabled: !loading,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            enabled: !loading,
            obscureText: true,
            validator: _password,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.10),
                border: Border.all(color: theme.colorScheme.error),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: theme.colorScheme.error,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      error!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: loading ? null : _submit,
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('SEND REQUEST'),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: loading ? null : () => context.go('/login'),
              child: const Text('BACK TO ADMIN LOGIN'),
            ),
          ),
        ],
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
        email: emailController.text.trim(),
        password: passwordController.text,
        data: {
          'full_name': nameController.text.trim(),
          'phone': phoneController.text.trim(),
          'requested_app': 'admin_dashboard',
        },
      );

      final userId = response.user?.id;
      if (userId != null && response.session != null) {
        await supabase
            .from('profiles')
            .update({
              'full_name': nameController.text.trim(),
              'phone': phoneController.text.trim(),
              'email': emailController.text.trim(),
              'role': 'EMPLOYEE',
              'status': 'PENDING',
              'meta': {'requested_app': 'admin_dashboard'},
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
        Text('REQUEST SENT', style: theme.textTheme.headlineLarge),
        const SizedBox(height: 12),
        Text(
          'Your request has been sent. In Supabase Table Editor, set this profile status to ACTIVE and role to ADMIN, MANAGER, or SUPER_ADMIN to allow dashboard access.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            child: const Text('BACK TO LOGIN'),
          ),
        ),
      ],
    );
  }
}
