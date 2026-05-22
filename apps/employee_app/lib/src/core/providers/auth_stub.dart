import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/presentation/viewmodels/auth_view_model.dart';

// Stub - Auth removed from project
final authViewModelProvider = StateNotifierProvider<AuthViewModel, AuthState>((
  ref,
) {
  return AuthViewModel(ref);
});

final authRepositoryProvider = Provider((ref) {
  return null;
});
