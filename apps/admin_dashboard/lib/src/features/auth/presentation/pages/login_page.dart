import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final emailController = TextEditingController(text: 'admin@dooninfra.com');
  final passwordController = TextEditingController(text: 'admin@123');

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(adminAuthViewModelProvider, (previous, next) {
      if (next.session != null) {
        context.go('/dashboard');
      }
    });

    final state = ref.watch(adminAuthViewModelProvider);
    final notifier = ref.read(adminAuthViewModelProvider.notifier);
    final theme = Theme.of(context);

    Widget hero() {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('ADMIN ACCESS', style: theme.textTheme.labelLarge),
            const SizedBox(height: 18),
            Text('REAL-TIME', style: theme.textTheme.displayLarge),
            Text('WORKFORCE', style: theme.textTheme.displayLarge),
            Text('MONITORING', style: theme.textTheme.displayLarge),
            const SizedBox(height: 20),
            Text(
              'Enterprise-grade tracking, attendance oversight and route intelligence for HR and operations leaders.',
              style: theme.textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    Widget form() {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ADMIN LOGIN', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 16),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
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
                            state.error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              TextField(
                controller: emailController,
                enabled: !state.loading,
                decoration: const InputDecoration(
                  labelText: 'Work Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                enabled: !state.loading,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: state.loading
                      ? null
                      : () {
                          notifier.login(
                            emailController.text.trim(),
                            passwordController.text,
                          );
                        },
                  child: state.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('SIGN IN'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: state.loading ? null : () => context.go('/signup'),
                  child: const Text('REQUEST ADMIN ACCESS'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Demo: admin@dooninfra.com / admin@123',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 820) {
                  return ListView(
                    shrinkWrap: true,
                    children: [hero(), const SizedBox(height: 16), form()],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: hero()),
                    const SizedBox(width: 24),
                    Expanded(child: form()),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
