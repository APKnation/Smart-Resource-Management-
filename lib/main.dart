import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_state.dart';
import 'core/constants.dart';
import 'core/env.dart';
import 'core/theme.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Never let a startup failure produce a blank page — always fall back to
  // a visible screen with the reason.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error: ${details.exception}');
  };

  bool backendReady = false;
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('.env not loaded: $e');
  }

  if (Env.isConfigured) {
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        publishableKey: Env.supabaseAnonKey,
      );
      backendReady = true;
    } catch (e) {
      debugPrint('Supabase.initialize failed: $e');
    }
  }

  final state = backendReady ? AppState() : null;
  if (state != null) {
    try {
      await state.init();
    } catch (e) {
      debugPrint('AppState.init failed: $e');
    }
  }

  runApp(EResourceApp(state: state, backendReady: backendReady));
}

class EResourceApp extends StatelessWidget {
  const EResourceApp({
    super.key,
    required this.state,
    required this.backendReady,
  });

  final AppState? state;

  /// True only when Supabase was initialized successfully.
  final bool backendReady;

  @override
  Widget build(BuildContext context) {
    if (!backendReady || state == null) {
      return MaterialApp(
        title: App.name,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const SetupRequiredScreen(),
      );
    }
    return MaterialApp.router(
      title: App.name,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: buildRouter(state!),
    );
  }
}

/// Shown when SUPABASE_URL / SUPABASE_ANON_KEY are missing or invalid.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud_off_outlined,
                            size: 36,
                            color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text('Backend not configured',
                              style:
                                  Theme.of(context).textTheme.headlineSmall),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'The app starts, but it needs Supabase credentials to '
                      'work. Create a `.env` file at the project root:',
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SUPABASE_URL=https://your-project.supabase.co\n'
                        'SUPABASE_ANON_KEY=your-anon-key',
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '1. Get both values from Supabase Dashboard → '
                      'Settings → API.\n'
                      '2. Run supabase/schema.sql once in the SQL Editor.\n'
                      '3. Restart the app (a full restart is required — '
                      '`.env` is bundled as an asset, hot reload is not enough).',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
