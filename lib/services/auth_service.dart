import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // iOS Client ID for native Google Sign-In
  static const String _iosClientId = '749237262584-37viha9oi8391q9tkfciedq96r0v34tt.apps.googleusercontent.com';
  
  // Web Client ID (from Google Cloud Console - must match Supabase config)
  static const String _webClientId = '749237262584-n0q663vaht5c3bps8ims3p566gl8gfoe.apps.googleusercontent.com';

  User? get currentUser => _supabase.auth.currentUser;
  Stream<AuthState> get authStateChange => _supabase.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    // Try to sign out from Google (silently fail if not signed in with Google)
    try {
      final googleSignIn = GoogleSignIn();
      await googleSignIn.signOut();
    } catch (_) {
      // Ignore errors - user may not have signed in with Google
    }
    
    // Sign out from Supabase
    await _supabase.auth.signOut();
  }

  Future<AuthResponse?> signInWithGoogle() async {
    if (kIsWeb) {
      // On web, use OAuth flow
      await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: null,
      );
      return null;
    }
    
    // On mobile, use native Google Sign-In
    // Use iOS Client ID for authentication, Web Client ID for server verification
    final googleSignIn = GoogleSignIn(
      clientId: _iosClientId,
      serverClientId: _webClientId,
    );
    
    // Completely disconnect to clear any cached credentials/tokens
    try {
      await googleSignIn.disconnect();
    } catch (_) {
      // Ignore if not previously signed in
    }
    
    final googleUser = await googleSignIn.signIn();
    
    if (googleUser == null) {
      throw Exception('Google sign in was cancelled');
    }
    
    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    
    debugPrint('Google Sign-In: Got tokens');
    debugPrint('Access token present: ${accessToken != null}');
    debugPrint('ID token present: ${idToken != null}');
    
    if (accessToken == null) {
      throw Exception('No access token received from Google');
    }
    if (idToken == null) {
      throw Exception('No ID token received from Google');
    }
    
    debugPrint('Calling Supabase signInWithIdToken...');
    
    // Sign in to Supabase with the Google ID token
    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
    
    debugPrint('Supabase sign-in successful!');
    return response;
  }

  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }
}
