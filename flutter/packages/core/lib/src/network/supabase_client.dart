/// Supabase client access.
///
/// Initialization itself lives in `app_kit` (`initSupabaseSecure`), the ONLY
/// place allowed to call `Supabase.initialize` — it wires the H-5 secure
/// session + PKCE storage so the refresh token never lands in plaintext
/// `shared_preferences` (§5.1). The insecure zero-arg `initSupabase()` that
/// used to live here was DELETED so the plaintext path cannot be reintroduced
/// silently; a CI guard enforces the single init site.
///
/// Only the public anon/publishable key is ever embedded (§8-A). The
/// `service_role` key and any secret must never reach the client.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the initialized [SupabaseClient].
///
/// Throws if read before Supabase has been initialized (via `app_kit`'s
/// `initSupabaseSecure`). The app layer overrides this provider when running
/// without Supabase (e.g. tests) to avoid the throw.
final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((ref) => Supabase.instance.client);
