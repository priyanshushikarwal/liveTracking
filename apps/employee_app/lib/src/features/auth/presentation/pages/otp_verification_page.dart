import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/providers.dart';

class OtpVerificationPage extends ConsumerStatefulWidget {
  const OtpVerificationPage({super.key});

  @override
  ConsumerState<OtpVerificationPage> createState() =>
      _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  final otpController = TextEditingController(text: '123456');

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authViewModelProvider);
    final notifier = ref.read(authViewModelProvider.notifier);

    ref.listen(authViewModelProvider, (previous, next) {
      if (next.session != null) {
        context.go('/dashboard');
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('OTP VERIFICATION')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Verify the OTP sent to ${state.phoneNumber}',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: otpController,
                  decoration: const InputDecoration(labelText: 'OTP'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: state.loading
                        ? null
                        : () => notifier.verifyOtp(otpController.text.trim()),
                    child: Text(state.loading ? 'VERIFYING...' : 'VERIFY OTP'),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Demo OTP: 123456'),
                if (state.error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    state.error!.replaceFirst('Exception: ', ''),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
