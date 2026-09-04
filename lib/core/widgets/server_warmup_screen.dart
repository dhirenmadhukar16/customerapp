import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../network/api_client.dart';

/// Shows a "Waking up server..." screen on cold starts (Render free tier).
/// Pings /actuator/health and navigates to [nextScreen] once server responds.
class ServerWarmupScreen extends StatefulWidget {
  final Widget nextScreen;
  const ServerWarmupScreen({super.key, required this.nextScreen});

  @override
  State<ServerWarmupScreen> createState() => _ServerWarmupScreenState();
}

class _ServerWarmupScreenState extends State<ServerWarmupScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  String _statusMessage = 'Connecting to server...';
  bool _isWakingUp = false;
  int _elapsedSeconds = 0;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _startElapsedTimer();
    _pingServer();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _startElapsedTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted || _navigated) return false;
      setState(() {
        _elapsedSeconds++;
        if (_isWakingUp) {
          _statusMessage = 'Waking up server... (${_elapsedSeconds}s)';
        }
      });
      return true;
    });
  }

  Future<void> _pingServer() async {
    while (!_navigated) {
      try {
        final response = await ApiClient.dio.get(
          '/actuator/health',
          options: Options(
            receiveTimeout: const Duration(seconds: 55),
            sendTimeout: const Duration(seconds: 10),
          ),
        );
        if ((response.statusCode ?? 0) >= 200 &&
            (response.statusCode ?? 0) < 300) {
          _goNext();
          return;
        }
      } on DioException catch (e) {
        if (e.response != null) {
          final code = e.response!.statusCode ?? 500;
          if (code != 502 && code != 503 && code != 504) {
            _goNext();
            return;
          }
          if (code == 503 && e.response!.data.toString().contains("DOWN")) {
            // Spring Boot is awake, but health is DOWN (e.g. database error). Proceed anyway.
            _goNext();
            return;
          }
        }
      } catch (_) {
        // Server still sleeping, retry
      }

      if (!mounted || _navigated) return;
      setState(() {
        _isWakingUp = true;
        _statusMessage = 'Waking up server... (${_elapsedSeconds}s)';
      });

      await Future.delayed(const Duration(seconds: 3));
    }
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => widget.nextScreen,
        transitionDuration: const Duration(milliseconds: 500),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pulsing logo
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                ),
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF2563EB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.45),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_laundry_service_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ),
              const SizedBox(height: 36),
              const Text(
                'WhiteFox',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Premium Laundry Management',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 64),

              // Status pill
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(
                    color: _isWakingUp
                        ? const Color(0xFF7C3AED).withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.1),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF7C3AED),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Extended hint after 10 seconds
              if (_elapsedSeconds >= 10) ...[
                const SizedBox(height: 24),
                AnimatedOpacity(
                  opacity: _elapsedSeconds >= 10 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: Text(
                    'The server was sleeping and is now waking up.\nThis can take up to 60 seconds — please wait.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
