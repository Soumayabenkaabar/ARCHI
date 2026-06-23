import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  bool _loading = false;
  bool _emailSent = false;
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
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailCtrl.text.trim(),
        redirectTo: 'io.supabase.archimanager://reset-callback/',
      );
      if (mounted) setState(() => _emailSent = true);
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = e.message.toLowerCase().contains('invalid')
              ? 'Adresse email invalide.'
              : 'Une erreur est survenue. Réessayez.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _errorMsg = 'Une erreur est survenue. Réessayez.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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

  // ── Layout large ─────────────────────────────────────────────────────────
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
                      'Réinitialisez\nvotre mot de passe.',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Entrez votre email et recevez un lien\npour créer un nouveau mot de passe.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 48),
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
              child: _emailSent ? _successContent() : _formContent(),
            ),
          ),
        ),
      ),
    ],
  );

  // ── Layout mobile ─────────────────────────────────────────────────────────
  Widget _narrowLayout() => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFF0F172A),
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bouton retour
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.arrowLeft, size: 16, color: Color(0xFF94A3B8)),
                      SizedBox(width: 6),
                      Text(
                        'Retour',
                        style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _Logo(dark: true),
                const SizedBox(height: 20),
                const Text(
                  'Mot de passe oublié ?',
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
          Padding(
            padding: const EdgeInsets.all(24),
            child: _emailSent ? _successContent() : _formContent(),
          ),
        ],
      ),
    ),
  );

  // ── Formulaire ─────────────────────────────────────────────────────────────
  Widget _formContent() => FadeTransition(
    opacity: _fadeAnim,
    child: SlideTransition(
      position: _slideAnim,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bouton retour (desktop uniquement, visible dans le panneau droit)
            if (MediaQuery.of(context).size.width > 800) ...[
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.arrowLeft, size: 16, color: kTextSub),
                    const SizedBox(width: 6),
                    Text(
                      'Retour à la connexion',
                      style: TextStyle(fontSize: 13, color: kTextSub),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
            ],

            const Text(
              'Mot de passe oublié ?',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: kTextMain,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Entrez votre email pour recevoir un lien de réinitialisation.',
              style: TextStyle(fontSize: 14, color: kTextSub),
            ),
            const SizedBox(height: 32),

            // Bandeau erreur
            if (_errorMsg != null) ...[
              _ErrorBanner(message: _errorMsg!),
              const SizedBox(height: 20),
            ],

            // Champ email
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adresse e-mail',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: kTextMain,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(fontSize: 14, color: kTextMain),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Email requis';
                    if (!v.contains('@')) return 'Email invalide';
                    return null;
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(LucideIcons.mail, size: 16, color: kTextSub),
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
            ),

            const SizedBox(height: 28),

            // Bouton envoyer
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendReset,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      const Color(0xFF0F172A).withOpacity(0.5),
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
                        'Envoyer le lien',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Écran de succès ────────────────────────────────────────────────────────
  Widget _successContent() => FadeTransition(
    opacity: _fadeAnim,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icône
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: kAccent.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(LucideIcons.mailCheck, size: 26, color: kAccent),
        ),
        const SizedBox(height: 24),

        const Text(
          'Email envoyé !',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: kTextMain,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Un lien de réinitialisation a été envoyé à :',
          style: const TextStyle(fontSize: 14, color: kTextSub),
        ),
        const SizedBox(height: 10),

        // Email pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: kAccent.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kAccent.withOpacity(0.2)),
          ),
          child: Text(
            _emailCtrl.text.trim(),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kAccent,
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Étapes
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: const [
              _StepItem(
                icon: LucideIcons.mail,
                text: 'Ouvrez votre boîte de réception',
              ),
              SizedBox(height: 12),
              _StepItem(
                icon: LucideIcons.mousePointerClick,
                text: 'Cliquez sur le lien de réinitialisation',
              ),
              SizedBox(height: 12),
              _StepItem(
                icon: LucideIcons.lock,
                text: 'Créez votre nouveau mot de passe',
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),
        const Text(
          'Vérifiez également vos spams.',
          style: TextStyle(fontSize: 12, color: kTextSub),
        ),
        const SizedBox(height: 28),

        // Bouton retour connexion
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Retour à la connexion',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
        ),
      ],
    ),
  );

  OutlineInputBorder _border(Color c, {double width = 1.0}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: width),
      );
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────

class _StepItem extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StepItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: kAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 15, color: kAccent),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: kTextSub),
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