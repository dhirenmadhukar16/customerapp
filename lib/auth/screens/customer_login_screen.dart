import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/network/api_client.dart';
import '../../navigation/customer_shell.dart';
import 'customer_profile_setup_screen.dart';

class CustomerLoginScreen extends StatefulWidget {
  const CustomerLoginScreen({super.key});

  @override
  State<CustomerLoginScreen> createState() => _CustomerLoginScreenState();
}

class _CustomerLoginScreenState extends State<CustomerLoginScreen> {
  final identifierController = TextEditingController();
  final otpController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;
  bool otpSent = false;
  bool requiresPassword = false;
  bool acceptedTerms = false;

  void checkIdentifier() async {
    final phone = identifierController.text.replaceAll(RegExp(r'\D'), '');
    if (!acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the Terms & Conditions to continue.')),
      );
      return;
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid 10-digit mobile number')),
      );
      return;
    }
    identifierController.text = phone;
    sendOtp();
  }

  void sendOtp() async {
    if (!acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Please accept the Terms & Conditions to continue.')));
      return;
    }
    final identifier = identifierController.text.replaceAll(RegExp(r'\D'), '');
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(identifier)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a valid 10-digit mobile number')));
      return;
    }
    setState(() => loading = true);
    try {
      await ApiClient.dio.post('/api/v1/auth/customer/send-otp', data: {
        'phone': identifier, // Assuming identifier is phone here
      });
      setState(() {
        otpSent = true;
        loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use OTP 2323 to continue')),
        );
      }
    } catch (e) {
      setState(() => loading = false);
      if (mounted) {
        String msg = 'Failed to send OTP';
        if (e is DioException && e.response != null) {
          final errData = e.response?.data;
          if (errData is Map && errData['message'] != null) {
            msg = errData['message'];
          } else {
            msg = 'Error (${e.response?.statusCode})';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    }
  }

  void performLogin() async {
    final identifier = identifierController.text.trim();
    final password = passwordController.text.trim();

    if (password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your password')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final res = await ApiClient.dio.post('/api/v1/auth/login', data: {
        'identifier': identifier,
        'password': password,
      });

      final data = res.data;
      if (data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        if (data['userId'] != null) {
          await prefs.setString('userId', data['userId']);
        }

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const CustomerShell()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Login failed';
        if (e is DioException && e.response != null) {
          final errData = e.response?.data;
          if (errData is Map && errData['message'] != null) {
            msg = errData['message'];
          } else {
            msg = 'Invalid Credentials (${e.response?.statusCode})';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void verifyOtp() async {
    if (!acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms & Conditions to continue.'),
        ),
      );
      return;
    }

    final phone = identifierController.text.trim();
    final otp = otpController.text.trim();

    if (otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP')),
      );
      return;
    }
    if (otp != '2323') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP. Use 2323.')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final res =
          await ApiClient.dio.post('/api/v1/auth/customer/verify-otp', data: {
        'phone': phone,
        'otp': otp,
      });

      final data = res.data;
      if (data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        if (data['userId'] != null) {
          await prefs.setString('userId', data['userId']);
        }

        if (mounted) {
          if (data['isNewUser'] == true) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (_) => const CustomerProfileSetupScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const CustomerShell()),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        String msg = 'OTP Verification failed';
        if (e is DioException && e.response != null) {
          final errData = e.response?.data;
          if (errData is Map && errData['message'] != null) {
            msg = errData['message'];
          } else {
            msg = 'Invalid OTP (${e.response?.statusCode})';
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Terms & Conditions',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkText,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '1. All garments/linen/fabrics are handled with the greatest care but owing to the conditions of the articles or non-visible defects in its material there is a possibility of discoloring or shrinkage. Such garments are accepted for cleaning at owner\'s risk and the company will not accept any responsibility for it.\n\n'
                    '2. Stain removal is a part of the process, but complete removal of stains cannot be guaranteed and will be processed at customer risk.\n\n'
                    '3. Despite special care of delicate work, e.g. sequin(s), pearl(s), sari, button(s), etc., there are chances of some damage which will be at owner\'s risk/responsibility. In case of loss/damage, the firm liability is limited up to 6 times of the processing charges or the actual/original/realistic cost, whichever is lower. The customer should bring any discrepancies to the notice within 24 hours of receiving the garments to our executives.\n\n'
                    '4. In case of claim/compensation, the customer should present the actual bill or mobile app bill or any acceptable proof of purchase of that specific item.\n\n'
                    '5. Any loss or damage due to force majeure conditions, WhiteFox is not liable to any compensation.\n\n'
                    '6. We assume that we receive garments checked by you for your personal belongings, cash etc. Taking any responsibility for these items would not be possible.\n\n'
                    '7. Normal delivery is within the standard service window of 4 working days annd few clothes attract additional day.\n\n'
                    '8. Whitefox will not take any responsibility for garments left beyond 30 days.Goods not claimed within 30 days of delivery will be handled appropriately by Whitefox and be sold to recover the billed charges.Whitefox will not return the garments without complete payment once garments are being sent to the plant for processing unless returned by the plant for technical reasons.\n\n'
                    '9. No employee/agent/representative of WhiteFox is authorized to waive or alter any of the above terms and conditions.\n\n'
                    '10. Payment can be made by cash or card All disputes are subjected to the jursdiction of courts located in Noida.\n\n'
                    '10. By continuing, the customer agrees to all above terms and conditions.',
                    style: TextStyle(
                      height: 1.5,
                      fontSize: 14,
                      color: AppTheme.darkText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => acceptedTerms = true);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('I Agree'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Background image: bright airy laundry room ──
          Image.asset(
            'assets/images/login_background.png',
            fit: BoxFit.cover,
          ),
          // Very light white overlay to keep everything readable
          Container(color: Colors.white.withValues(alpha: 0.35)),

          // ── Content ──
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26),
              child: Column(
                children: [
                  const SizedBox(height: 28),

                  // ── WhiteFox Fox Logo ──
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(painter: _FoxLogoPainter()),
                  ),
                  const SizedBox(height: 14),

                  // ── "WhiteFox" title ──
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'White',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1A1A1A),
                            letterSpacing: -0.5,
                          ),
                        ),
                        TextSpan(
                          text: 'Fox',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // ── "— Laundry Services —" ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                          width: 28, height: 1.5, color: AppTheme.mutedText),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'Laundry Services',
                          style: TextStyle(
                            color: AppTheme.mutedText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      Container(
                          width: 28, height: 1.5, color: AppTheme.mutedText),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // ── Tagline ──
                  const Text(
                    'Fresh. Clean. Delivered.',
                    style: TextStyle(
                      color: AppTheme.mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Identifier Field ──
                  _fieldCard(
                    label: 'Mobile Number',
                    child: TextField(
                      controller: identifierController,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                      enabled: !otpSent && !requiresPassword,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Enter 10-digit mobile number',
                        counterText: '',
                        hintStyle: TextStyle(
                            color: Colors.grey.shade400, fontSize: 15),
                        prefixIcon: Icon(Icons.phone_android,
                            color: Colors.grey.shade400, size: 20),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        isDense: true,
                        suffixIcon: (otpSent || requiresPassword)
                            ? IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => setState(() {
                                  otpSent = false;
                                  requiresPassword = false;
                                  passwordController.clear();
                                  otpController.clear();
                                }),
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── OTP Field ──
                  if (otpSent)
                    _fieldCard(
                      label: 'OTP',
                      child: TextField(
                        controller: otpController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: '••••',
                          hintStyle: TextStyle(
                              color: Colors.grey.shade400, fontSize: 15),
                          prefixIcon: Icon(Icons.lock_outline,
                              color: Colors.grey.shade400, size: 20),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          isDense: true,
                        ),
                      ),
                    ),

                  // ── Password Field ──
                  if (requiresPassword) ...[
                    _fieldCard(
                      label: 'Password',
                      child: TextField(
                        controller: passwordController,
                        obscureText: true,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF1A1A1A),
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          hintStyle: TextStyle(
                              color: Colors.grey.shade400, fontSize: 15),
                          prefixIcon: Icon(Icons.lock_outline,
                              color: Colors.grey.shade400, size: 20),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 14),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            requiresPassword = false;
                            sendOtp();
                          });
                        },
                        child: const Text(
                          'LOGIN WITH OTP',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (otpSent) const SizedBox(height: 14),

                  // ── Action button ──
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: loading || !acceptedTerms
                          ? null
                          : (requiresPassword
                              ? performLogin
                              : (otpSent ? verifyOtp : checkIdentifier)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  requiresPassword
                                      ? 'LOGIN'
                                      : (otpSent
                                          ? 'VERIFY & LOGIN'
                                          : 'CONTINUE'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(Icons.arrow_forward, size: 20),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Terms & Conditions checkbox ──
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: acceptedTerms,
                          activeColor: AppTheme.primary,
                          onChanged: (value) {
                            setState(() => acceptedTerms = value ?? false);
                          },
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: _showTermsDialog,
                            child: const Text(
                              'I agree to the Terms & Conditions',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.darkText,
                              ),
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _showTermsDialog,
                          child: const Text(
                            'View',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  const SizedBox(height: 24),

                  // ── Help card ──
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.headset_mic_outlined,
                              color: AppTheme.primary, size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Need Help? Call +91-9876543210',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppTheme.darkText,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Customer Support • 9 AM - 8 PM',
                              style: TextStyle(
                                  color: AppTheme.mutedText, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldCard({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.only(left: 16, right: 12, top: 10, bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// Fox + washing machine logo drawn with CustomPainter
class _FoxLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final greenDark = const Color(0xFF0F6B3A);
    final greenMid = const Color(0xFF1A8C4E);
    final greenLight = const Color(0xFF86EFAC);

    final w = size.width;
    final h = size.height;

    // ── Outer water/wave circle (teardrop-like base) ──
    final basePaint = Paint()..color = greenMid;
    final basePath = Path();
    basePath.addOval(Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.62), width: w * 0.8, height: h * 0.6));
    canvas.drawPath(basePath, basePaint);

    // Wave arc at the bottom
    final wavePaint = Paint()..color = greenDark;
    final wavePath = Path();
    wavePath.moveTo(w * 0.1, h * 0.68);
    wavePath.quadraticBezierTo(w * 0.35, h * 0.58, w * 0.5, h * 0.72);
    wavePath.quadraticBezierTo(w * 0.65, h * 0.86, w * 0.9, h * 0.72);
    wavePath.lineTo(w * 0.9, h * 0.92);
    wavePath.lineTo(w * 0.1, h * 0.92);
    wavePath.close();
    canvas.drawPath(wavePath, wavePaint);

    // ── Washing machine icon (small, bottom portion) ──
    final machinePaint = Paint()..color = Colors.white.withValues(alpha: 0.25);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.3, h * 0.62, w * 0.4, h * 0.28),
          const Radius.circular(4)),
      machinePaint,
    );
    // drum circle
    final drumPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(w * 0.5, h * 0.76), h * 0.09, drumPaint);

    // ── Fox head body ──
    final foxBodyPaint = Paint()..color = greenDark;
    canvas.drawCircle(Offset(w * 0.5, h * 0.36), w * 0.26, foxBodyPaint);

    // ── Fox ears ──
    final leftEar = Path()
      ..moveTo(w * 0.28, h * 0.16)
      ..lineTo(w * 0.16, h * 0.03)
      ..lineTo(w * 0.38, h * 0.18)
      ..close();
    canvas.drawPath(leftEar, foxBodyPaint);

    final rightEar = Path()
      ..moveTo(w * 0.72, h * 0.16)
      ..lineTo(w * 0.84, h * 0.03)
      ..lineTo(w * 0.62, h * 0.18)
      ..close();
    canvas.drawPath(rightEar, foxBodyPaint);

    // Inner ear colour
    final innerEarPaint = Paint()..color = greenMid;
    final leftInner = Path()
      ..moveTo(w * 0.29, h * 0.17)
      ..lineTo(w * 0.20, h * 0.07)
      ..lineTo(w * 0.37, h * 0.19)
      ..close();
    canvas.drawPath(leftInner, innerEarPaint);

    final rightInner = Path()
      ..moveTo(w * 0.71, h * 0.17)
      ..lineTo(w * 0.80, h * 0.07)
      ..lineTo(w * 0.63, h * 0.19)
      ..close();
    canvas.drawPath(rightInner, innerEarPaint);

    // ── Fox eyes ──
    final eyePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(w * 0.41, h * 0.34), w * 0.055, eyePaint);
    canvas.drawCircle(Offset(w * 0.59, h * 0.34), w * 0.055, eyePaint);

    // Pupils
    final pupilPaint = Paint()..color = greenDark;
    canvas.drawCircle(Offset(w * 0.41, h * 0.34), w * 0.03, pupilPaint);
    canvas.drawCircle(Offset(w * 0.59, h * 0.34), w * 0.03, pupilPaint);

    // ── Nose ──
    final nosePaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(w * 0.5, h * 0.43), w * 0.04, nosePaint);

    // ── Soap bubbles ──
    final bubblePaint = Paint()
      ..color = greenLight.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w * 0.80, h * 0.22), w * 0.055, bubblePaint);
    canvas.drawCircle(Offset(w * 0.88, h * 0.34), w * 0.035, bubblePaint);
    canvas.drawCircle(Offset(w * 0.76, h * 0.30), w * 0.025, bubblePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
