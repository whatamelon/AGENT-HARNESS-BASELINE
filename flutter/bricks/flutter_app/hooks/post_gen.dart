import 'package:mason/mason.dart';

/// Prints the manual workspace-registration steps. (We do NOT run
/// `flutter create` here: the generated pubspec uses `resolution: workspace`,
/// which `flutter create` rejects until the app is added to the root
/// `pubspec.yaml` `workspace:` list. The brick ships a minimal `web/` so
/// `flutter build web` works; run `flutter create --platforms=... .` after
/// registration if you want full android/ios scaffolding + web icons.)
void run(HookContext context) {
  final appName = context.vars['app_name'] as String;

  context.logger
    ..info('')
    ..success('Generated app: apps/$appName')
    ..info('Next steps:')
    ..info('  1. Add `  - apps/$appName` to the root pubspec.yaml '
        '`workspace:` list.')
    ..info('  2. From the repo root: `melos bootstrap` '
        '(or `flutter pub get`).')
    ..info('  3. Verify: `cd apps/$appName && flutter analyze && '
        'flutter test`.')
    ..info('  4. (optional) Full platform scaffolding + web icons: '
        '`cd apps/$appName && flutter create --platforms=web,android,ios .`')
    ..info('  5. Wire real backends in lib/wiring.dart '
        '(Supabase / Toss / Firebase).');
}
