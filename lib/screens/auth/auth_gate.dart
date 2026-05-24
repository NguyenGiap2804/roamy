import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/place_provider.dart';
import '../../providers/schedule_provider.dart';
import '../main_navigation_screen.dart';
import '../splash_screen.dart';
import 'auth_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  String? _activeUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        _syncUserScopedState(auth);
        if (auth.isInitializing) {
          return const SplashScreen();
        }
        if (auth.isAuthenticated) {
          return const MainNavigationScreen();
        }
        return const AuthScreen();
      },
    );
  }

  void _syncUserScopedState(AuthProvider auth) {
    final nextUserId = auth.user?.id;
    if (_activeUserId == nextUserId) {
      return;
    }

    final previousUserId = _activeUserId;
    _activeUserId = nextUserId;

    if (previousUserId == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PlaceProvider>().clear();
      context.read<CategoryProvider>().clear();
      context.read<ScheduleProvider>().clear();
    });
  }
}
