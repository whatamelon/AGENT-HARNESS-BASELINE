/// Core harness primitives shared across all apps.
library;

export 'src/analytics/analytics_event.dart';
export 'src/analytics/analytics_sink.dart';
export 'src/analytics/logger_sink.dart';
export 'src/analytics/noop_sink.dart';
export 'src/analytics/redacting_sink.dart';
export 'src/auth/auth_state.dart';
export 'src/env.dart';
export 'src/flavor.dart';
export 'src/haptics/haptics.dart';
export 'src/haptics/haptics_settings.dart';
export 'src/haptics/noop_haptics.dart';
export 'src/haptics/platform_haptics.dart';
export 'src/haptics/throttling_haptics.dart';
export 'src/logger.dart';
export 'src/network/api_client.dart';
export 'src/network/app_exception.dart';
export 'src/network/log_redaction.dart';
export 'src/network/supabase_client.dart';
export 'src/observability.dart';
export 'src/result.dart';
