import 'package:archi_manager/service/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _errorMsg;
  late AnimationController _anim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final result = await AuthService.login(
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (result.success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      setState(() => _errorMsg = result.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;
    return Scaffold(
      backgroundColor: kBg,
      body: isWide ? _wideLayout() : _narrowLayout(),
    );
  }

  Widget _wideLayout() => Row(
    children: [
      Expanded(
        flex: 5,
        child: Container(
          color: const Color(0xFF0F172A),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _GridPainter())),
              Padding(
                padding: const EdgeInsets.all(48),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _Logo(dark: true),
                    const Spacer(),
                    const Text(
                      'Gérez vos projets\nd\'architecture.',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Équipes, clients, finances et documents —\ntout dans un seul espace.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF94A3B8),
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 48),
                    const _StatRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      Expanded(
        flex: 4,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _FormContent(
                fadeAnim: _fadeAnim,
                slideAnim: _slideAnim,
                formKey: _formKey,
                emailCtrl: _emailCtrl,
                passwordCtrl: _passwordCtrl,
                obscure: _obscure,
                loading: _loading,
                errorMsg: _errorMsg,
                onToggleObscure: () => setState(() => _obscure = !_obscure),
                onSubmit: _submit,
                onRegister: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _narrowLayout() => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Logo(dark: true),
                SizedBox(height: 24),
                Text(
                  'Gérez vos projets\nd\'architecture.',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: _FormContent(
              fadeAnim: _fadeAnim,
              slideAnim: _slideAnim,
              formKey: _formKey,
              emailCtrl: _emailCtrl,
              passwordCtrl: _passwordCtrl,
              obscure: _obscure,
              loading: _loading,
              errorMsg: _errorMsg,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              onSubmit: _submit,
              onRegister: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── Form content ───────────────────────────────────────────────────────────────
class _FormContent extends StatelessWidget {
  final Animation<double> fadeAnim;
  final Animation<Offset> slideAnim;
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl, passwordCtrl;
  final bool obscure, loading;
  final String? errorMsg;
  final VoidCallback onToggleObscure, onSubmit, onRegister;

  const _FormContent({
    required this.fadeAnim,
    required this.slideAnim,
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.loading,
    required this.errorMsg,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: fadeAnim,
    child: SlideTransition(
      position: slideAnim,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connexion',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: kTextMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Accédez à votre espace architecte',
              style: TextStyle(fontSize: 14, color: kTextSub),
            ),
            const SizedBox(height: 32),

            if (errorMsg != null) ...[
              _ErrorBanner(message: errorMsg!),
              const SizedBox(height: 20),
            ],

            _AuthField(
              label: 'Adresse e-mail',
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: LucideIcons.mail,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email requis';
                if (!v.contains('@')) return 'Email invalide';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _AuthField(
              label: 'Mot de passe',
              controller: passwordCtrl,
              obscureText: obscure,
              prefixIcon: LucideIcons.lock,
              suffixIcon: obscure ? LucideIcons.eyeOff : LucideIcons.eye,
              onSuffixTap: onToggleObscure,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Mot de passe requis';
                if (v.length < 6) return 'Minimum 6 caractères';
                return null;
              },
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: loading ? null : onSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(
                    0xFF0F172A,
                  ).withOpacity(0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Se connecter',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Pas encore de compte ?',
                  style: TextStyle(color: kTextSub, fontSize: 14),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onRegister,
                  child: const Text(
                    'S\'inscrire',
                    style: TextStyle(
                      color: kAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: kAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ── Auth text field ────────────────────────────────────────────────────────────
class _AuthField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? Function(String?)? validator;

  const _AuthField({
    required this.label,
    required this.controller,
    this.keyboardType,
    this.obscureText = false,
    required this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: kTextMain,
        ),
      ),
      const SizedBox(height: 6),
      TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(fontSize: 14, color: kTextMain),
        decoration: InputDecoration(
          prefixIcon: Icon(prefixIcon, size: 16, color: kTextSub),
          suffixIcon: suffixIcon != null
              ? GestureDetector(
                  onTap: onSuffixTap,
                  child: Icon(suffixIcon, size: 16, color: kTextSub),
                )
              : null,
          filled: true,
          fillColor: kCardBg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: _border(const Color(0xFFE5E7EB)),
          enabledBorder: _border(const Color(0xFFE5E7EB)),
          focusedBorder: _border(kAccent, width: 1.5),
          errorBorder: _border(const Color(0xFFEF4444)),
          focusedErrorBorder: _border(const Color(0xFFEF4444), width: 1.5),
          errorStyle: const TextStyle(fontSize: 12, color: Color(0xFFEF4444)),
        ),
      ),
    ],
  );

  OutlineInputBorder _border(Color c, {double width = 1.0}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: width),
      );
}

// ── Error banner ───────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: const Color(0xFFFEF2F2),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFFECACA)),
    ),
    child: Row(
      children: [
        const Icon(LucideIcons.alertCircle, size: 16, color: Color(0xFFEF4444)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(fontSize: 13, color: Color(0xFFB91C1C)),
          ),
        ),
      ],
    ),
  );
}

// ── Logo ───────────────────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  final bool dark;
  const _Logo({super.key, this.dark = false});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: dark ? Colors.white : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          LucideIcons.building2,
          size: 18,
          color: dark ? const Color(0xFF0F172A) : Colors.white,
        ),
      ),
      const SizedBox(width: 10),
      Text(
        'ArchiManager',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: dark ? Colors.white : kTextMain,
        ),
      ),
    ],
  );
}

// ── Stats row ─────────────────────────────────────────────────────────────────
class _StatRow extends StatelessWidget {
  const _StatRow();
  @override
  Widget build(BuildContext context) => const Row(
    children: [
      _StatItem(value: '500+', label: 'Projets gérés'),
      SizedBox(width: 32),
      _StatItem(value: '200+', label: 'Architectes'),
      SizedBox(width: 32),
      _StatItem(value: '98%', label: 'Satisfaction'),
    ],
  );
}

class _StatItem extends StatelessWidget {
  final String value, label;
  const _StatItem({super.key, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      Text(
        label,
        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
      ),
    ],
  );
}

// ── Grid painter ───────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
