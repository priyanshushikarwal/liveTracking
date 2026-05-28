import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final employeeIdController = TextEditingController(text: 'EMP-2048');
  final passwordController = TextEditingController(text: 'password@123');

  @override
  void dispose() {
    employeeIdController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authViewModelProvider, (previous, next) {
      if (next.session != null) {
        context.go('/dashboard');
      }
    });

    final state = ref.watch(authViewModelProvider);
    final notifier = ref.read(authViewModelProvider.notifier);
    final theme = Theme.of(context);

    if (state.restoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(color: theme.scaffoldBackgroundColor),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 820;
                final hero = Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('FIELD OPS', style: theme.textTheme.labelLarge),
                      const SizedBox(height: 18),
                      Text('DOONINFRA', style: theme.textTheme.displayLarge),
                      Text('FIELD FORCE', style: theme.textTheme.displayLarge),
                      Text('AUTOMATION', style: theme.textTheme.displayLarge),
                      const SizedBox(height: 20),
                      Text(
                        'Secure attendance, geo-verified visits, live tracking and offline sync for enterprise field teams.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                );
                final form = Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employee Login'.toUpperCase(),
                          style: theme.textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: employeeIdController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Employee ID',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!state.loading) {
                              notifier.loginWithEmployeeId(
                                employeeIdController.text.trim(),
                                passwordController.text,
                              );
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: state.loading
                                ? null
                                : () => notifier.loginWithEmployeeId(
                                    employeeIdController.text.trim(),
                                    passwordController.text,
                                  ),
                            child: Text(
                              state.loading ? 'AUTHENTICATING...' : 'LOGIN',
                            ),
                          ),
                        ),
                        if (state.error != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            state.error!.replaceFirst('Exception: ', ''),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
                if (isWide) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(flex: 6, child: hero),
                        Expanded(flex: 5, child: form),
                      ],
                    ),
                  );
                }
                return SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [hero, const SizedBox(height: 8), form],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
