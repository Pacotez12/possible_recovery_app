import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/local_db.dart';
import 'login_screen.dart';
import 'scan_screen.dart';
import 'sync_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOut,
      ),
    );

    _animController.repeat(reverse: true);
    _initialize();
  }

  Future<void> _initialize() async {
    final localDb = context.read<LocalDb>();
    final start = DateTime.now();

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final count = await localDb.getProductsCount();

    // Ensure splash displays at least 800ms for smooth visual continuity
    final elapsed = DateTime.now().difference(start);
    if (elapsed.inMilliseconds < 800) {
      await Future.delayed(
        Duration(milliseconds: 800 - elapsed.inMilliseconds),
      );
    }

    if (!mounted) return;

    if (token != null && token.isNotEmpty) {
      if (count == 0) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const SyncScreen(initialSyncPrompt: true),
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const ScanScreen()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Image.asset(
            'lib/assets/images/RECOVERY_DARK_TIGHT.png',
            width: screenWidth * 0.55,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
