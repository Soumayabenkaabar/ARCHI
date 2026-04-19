import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String supabaseUrl = 'https://ngcnfbbeefsbynknvogm.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5nY25mYmJlZWZzYnlua252b2dtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0NjQzMDQsImV4cCI6MjA5MTA0MDMwNH0.IR7YemXmFb27rolXbkzUQUFv2SU7q1fsVh4O2kU4yb0';

  static Future<void> init() async {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  }

  static SupabaseClient get client => Supabase.instance.client;
}
