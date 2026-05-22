import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) context.go('/');
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            color: theme.scaffoldBackgroundColor,
            child: Center(
              child: Opacity(
                opacity: _controller.value,
                child: Transform.translate(
                  offset: Offset(0, 24 * (1 - _controller.value)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 86,
                        height: 86,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          border: Border.all(color: theme.colorScheme.outline),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.location_searching,
                          size: 42,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text('DOONINFRA', style: theme.textTheme.displayMedium),
                      const SizedBox(height: 8),
                      Text(
                        'FIELD FORCES',
                        style: theme.textTheme.headlineLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
