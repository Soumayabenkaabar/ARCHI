import '../core/supabase_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/architecte.dart';

class AuthService {
  static SupabaseClient get _sb => Supabase.instance.client;

  static Architecte? _currentUser;

  static Architecte? get currentUser => _currentUser;
  static bool get isLoggedIn => _sb.auth.currentSession != null;
  static String? get token => _sb.auth.currentSession?.accessToken;

  static Map<String, String> get authHeaders => {
    'Content-Type': 'application/json',
    'apikey': SupabaseConfig.supabaseAnonKey,
    if (token != null) 'Authorization': 'Bearer $token',
  };

  // ── Restore session au démarrage ──────────────────────────────────────────
  static Future<bool> restoreSession() async {
    try {
      final session = _sb.auth.currentSession;
      if (session == null) return false;
      await _loadProfile(session.user);
      return _currentUser != null;
    } catch (e) {
      debugPrint('restoreSession error: $e');
      return false;
    }
  }

  // ── Inscription ───────────────────────────────────────────────────────────
  static Future<AuthResult> register({
    required String nom,
    required String prenom,
    required String email,
    required String password,
    String? telephone,
    String? cabinet,
  }) async {
    try {
      final res = await _sb.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'nom': nom.trim(),
          'prenom': prenom.trim(),
          if (telephone != null && telephone.isNotEmpty)
            'telephone': telephone.trim(),
          if (cabinet != null && cabinet.isNotEmpty) 'cabinet': cabinet.trim(),
        },
      );

      if (res.user == null) {
        return AuthResult.failure('Inscription échouée. Réessayez.');
      }

      // Le trigger Supabase insère automatiquement dans architectes.
      // On construit l'objet local directement sans requête supplémentaire.
      _currentUser = Architecte(
        id: res.user!.id,
        nom: nom.trim(),
        prenom: prenom.trim(),
        email: email.trim(),
        telephone: telephone?.trim(),
        cabinet: cabinet?.trim(),
        createdAt: DateTime.now().toIso8601String(),
      );

      await _saveProfileLocally(_currentUser!);
      return AuthResult.success(_currentUser!);
    } on AuthException catch (e) {
      return AuthResult.failure(_translateError(e.message));
    } catch (e) {
      return AuthResult.failure('Erreur inattendue : $e');
    }
  }

  // ── Connexion ─────────────────────────────────────────────────────────────
  static Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _sb.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (res.user == null) {
        return AuthResult.failure(
          'Connexion échouée. Vérifiez vos identifiants.',
        );
      }

      await _loadProfile(res.user!);

      if (_currentUser == null) {
        return AuthResult.failure('Profil introuvable.');
      }

      return AuthResult.success(_currentUser!);
    } on AuthException catch (e) {
      return AuthResult.failure(_translateError(e.message));
    } catch (e) {
      return AuthResult.failure('Erreur inattendue : $e');
    }
  }

  // ── Déconnexion ───────────────────────────────────────────────────────────
  static Future<void> logout() async {
    await _sb.auth.signOut();
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_profile');
  }

  // ── Mise à jour profil ────────────────────────────────────────────────────
  static Future<void> updateCurrentUser(Architecte updated) async {
    _currentUser = updated;
    await _saveProfileLocally(updated);
    try {
      await _sb
          .from('architectes')
          .update({
            'nom': updated.nom,
            'prenom': updated.prenom,
            'telephone': updated.telephone,
            'cabinet': updated.cabinet,
          })
          .eq('id', updated.id);
    } catch (e) {
      debugPrint('updateCurrentUser error: $e');
    }
  }

  // ── Privé : charger le profil depuis la table architectes ─────────────────
  static Future<void> _loadProfile(User user) async {
    try {
      final row = await _sb
          .from('architectes') // ← table publique, pas auth.users
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (row != null) {
        _currentUser = _fromSupabaseRow(row, user);
        await _saveProfileLocally(_currentUser!);
        return;
      }
    } catch (e) {
      debugPrint('_loadProfile error: $e');
    }

    // Fallback : construire depuis user_metadata uniquement
    final meta = user.userMetadata ?? {};
    _currentUser = Architecte(
      id: user.id,
      nom: meta['nom'] as String? ?? '',
      prenom: meta['prenom'] as String? ?? '',
      email: user.email ?? '',
      telephone: meta['telephone'] as String?,
      cabinet: meta['cabinet'] as String?,
      createdAt: user.createdAt,
    );
    await _saveProfileLocally(_currentUser!);
  }

  // ── Privé : convertir une row Supabase → Architecte ──────────────────────
  static Architecte _fromSupabaseRow(Map<String, dynamic> row, User user) {
    return Architecte(
      id: row['id'] as String? ?? user.id,
      nom: row['nom'] as String? ?? '',
      prenom: row['prenom'] as String? ?? '',
      email: row['email'] as String? ?? user.email ?? '',
      telephone: row['telephone'] as String?,
      cabinet: row['cabinet'] as String?,
      createdAt: row['created_at'] as String? ?? user.createdAt,
    );
  }

  // ── Privé : cache local léger ─────────────────────────────────────────────
  static Future<void> _saveProfileLocally(Architecte a) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_nom', a.nom);
      await prefs.setString('cached_prenom', a.prenom);
      await prefs.setString('cached_email', a.email);
    } catch (_) {}
  }

  // ── Privé : traduction erreurs Supabase ───────────────────────────────────
  static String _translateError(String msg) {
    if (msg.contains('Invalid login credentials'))
      return 'Email ou mot de passe incorrect.';
    if (msg.contains('Email not confirmed'))
      return 'Confirmez votre email avant de vous connecter.';
    if (msg.contains('User already registered'))
      return 'Cet email est déjà utilisé.';
    if (msg.contains('Password should be at least'))
      return 'Mot de passe trop court (min. 6 caractères).';
    if (msg.contains('Unable to validate email'))
      return 'Adresse email invalide.';
    if (msg.contains('signup is disabled'))
      return 'Les inscriptions sont désactivées.';
    return msg;
  }
}

// ── Result wrapper ────────────────────────────────────────────────────────────
class AuthResult {
  final bool success;
  final Architecte? architecte;
  final String? error;

  const AuthResult._({required this.success, this.architecte, this.error});

  factory AuthResult.success(Architecte a) =>
      AuthResult._(success: true, architecte: a);
  factory AuthResult.failure(String msg) =>
      AuthResult._(success: false, error: msg);
}
