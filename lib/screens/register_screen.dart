import 'package:archi_manager/service/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../constants/colors.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nomCtrl = TextEditingController();
  final _prenomCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _cabinetCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
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
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    for (final c in [
      _nomCtrl,
      _prenomCtrl,
      _emailCtrl,
      _passwordCtrl,
      _confirmCtrl,
      _telCtrl,
      _cabinetCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    final result = await AuthService.register(
      nom: _nomCtrl.text,
      prenom: _prenomCtrl.text,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      telephone: _telCtrl.text.isEmpty ? null : _telCtrl.text,
      cabinet: _cabinetCtrl.text.isEmpty ? null : _cabinetCtrl.text,
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
        flex: 4,
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
                      'Créez votre\nespace de travail.',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chaque architecte a son propre espace isolé.\nVos projets, équipes et clients en sécurité.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 48),
                    ..._featureItems,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      Expanded(
        flex: 5,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _buildForm(),
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
                SizedBox(height: 20),
                Text(
                  'Créez votre espace de travail.',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(24), child: _buildForm()),
        ],
      ),
    ),
  );

  List<Widget> get _featureItems => [
    const _FeatureItem(
      icon: LucideIcons.shieldCheck,
      text: 'Données isolées par architecte',
    ),
    const SizedBox(height: 16),
    const _FeatureItem(
      icon: LucideIcons.users,
      text: 'Gérez votre équipe et clients',
    ),
    const SizedBox(height: 16),
    const _FeatureItem(
      icon: LucideIcons.barChart2,
      text: 'Suivi financier en temps réel',
    ),
  ];

  Widget _buildForm() => FadeTransition(
    opacity: _fadeAnim,
    child: SlideTransition(
      position: _slideAnim,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Créer un compte',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: kTextMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Remplissez les informations pour démarrer',
              style: TextStyle(fontSize: 14, color: kTextSub),
            ),
            const SizedBox(height: 28),

            if (_errorMsg != null) ...[
              _ErrorBanner(message: _errorMsg!),
              const SizedBox(height: 20),
            ],

            const _SectionLabel(label: 'Identité'),
            const SizedBox(height: 12),
            _TwoColumnRow(
              left: _AuthField(
                label: 'Prénom *',
                controller: _prenomCtrl,
                prefixIcon: LucideIcons.user,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
              right: _AuthField(
                label: 'Nom *',
                controller: _nomCtrl,
                prefixIcon: LucideIcons.user,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Requis' : null,
              ),
            ),
            const SizedBox(height: 16),
            _AuthField(
              label: 'Adresse e-mail *',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              prefixIcon: LucideIcons.mail,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email requis';
                if (!v.contains('@')) return 'Email invalide';
                return null;
              },
            ),
            const SizedBox(height: 24),

            const _SectionLabel(label: 'Cabinet (optionnel)'),
            const SizedBox(height: 12),
            _TwoColumnRow(
              left: _AuthField(
                label: 'Nom du cabinet',
                controller: _cabinetCtrl,
                prefixIcon: LucideIcons.building2,
              ),
              right: _AuthField(
                label: 'Téléphone',
                controller: _telCtrl,
                keyboardType: TextInputType.phone,
                prefixIcon: LucideIcons.phone,
              ),
            ),
            const SizedBox(height: 24),

            const _SectionLabel(label: 'Mot de passe'),
            const SizedBox(height: 12),
            _AuthField(
              label: 'Mot de passe *',
              controller: _passwordCtrl,
              obscureText: _obscurePass,
              prefixIcon: LucideIcons.lock,
              suffixIcon: _obscurePass ? LucideIcons.eyeOff : LucideIcons.eye,
              onSuffixTap: () => setState(() => _obscurePass = !_obscurePass),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Requis';
                if (v.length < 6) return 'Minimum 6 caractères';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _AuthField(
              label: 'Confirmer le mot de passe *',
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              prefixIcon: LucideIcons.lock,
              suffixIcon: _obscureConfirm
                  ? LucideIcons.eyeOff
                  : LucideIcons.eye,
              onSuffixTap: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              validator: (v) {
                if (v != _passwordCtrl.text)
                  return 'Les mots de passe ne correspondent pas';
                return null;
              },
            ),

            ValueListenableBuilder(
              valueListenable: _passwordCtrl,
              builder: (_, __, ___) =>
                  _PasswordStrength(password: _passwordCtrl.text),
            ),

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
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
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Créer mon compte',
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
                  'Déjà un compte ?',
                  style: TextStyle(color: kTextSub, fontSize: 14),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Se connecter',
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

// ── Widgets partagés ──────────────────────────────────────────────────────────

class _PasswordStrength extends StatelessWidget {
  final String password;
  const _PasswordStrength({required this.password});

  int get _strength {
    if (password.isEmpty) return 0;
    int s = 0;
    if (password.length >= 6) s++;
    if (password.contains(RegExp(r'[A-Z]'))) s++;
    if (password.contains(RegExp(r'[0-9]'))) s++;
    if (password.contains(RegExp(r'[!@#\$%^&*]'))) s++;
    return s;
  }

  Color _color(int s) {
    if (s <= 1) return const Color(0xFFEF4444);
    if (s == 2) return const Color(0xFFF59E0B);
    if (s == 3) return const Color(0xFF10B981);
    return kAccent;
  }

  String _label(int s) {
    if (s <= 1) return 'Faible';
    if (s == 2) return 'Moyen';
    if (s == 3) return 'Fort';
    return 'Très fort';
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final s = _strength;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: Container(
                  height: 3,
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: i < s ? _color(s) : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Force : ${_label(s)}',
            style: TextStyle(
              fontSize: 11,
              color: _color(s),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({super.key, required this.label});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: kTextSub,
      letterSpacing: 0.8,
    ),
  );
}

class _TwoColumnRow extends StatelessWidget {
  final Widget left, right;
  const _TwoColumnRow({required this.left, required this.right});
  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 500;
    return isNarrow
        ? Column(children: [left, const SizedBox(height: 12), right])
        : Row(
            children: [
              Expanded(child: left),
              const SizedBox(width: 12),
              Expanded(child: right),
            ],
          );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureItem({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
      const SizedBox(width: 12),
      Text(
        text,
        style: const TextStyle(fontSize: 13, color: Color(0xFFCBD5E1)),
      ),
    ],
  );
}

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

  OutlineInputBorder _border(Color c, {double width = 1.0}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: width),
      );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
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
          prefixIcon: Icon(prefixIcon, size: 15, color: kTextSub),
          suffixIcon: suffixIcon != null
              ? GestureDetector(
                  onTap: onSuffixTap,
                  child: Icon(suffixIcon, size: 15, color: kTextSub),
                )
              : null,
          filled: true,
          fillColor: kCardBg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 13,
          ),
          border: _border(const Color(0xFFE5E7EB)),
          enabledBorder: _border(const Color(0xFFE5E7EB)),
          focusedBorder: _border(kAccent, width: 1.5),
          errorBorder: _border(const Color(0xFFEF4444)),
          focusedErrorBorder: _border(const Color(0xFFEF4444), width: 1.5),
          errorStyle: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)),
        ),
      ),
    ],
  );
}

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