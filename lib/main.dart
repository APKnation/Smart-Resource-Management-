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
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env missing — app will show the setup screen.
  }
  if (Env.isConfigured) {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );
  }
  final state = AppState();
  await state.init();
  runApp(EResourceApp(state: state));
}

class EResourceApp extends StatelessWidget {
  const EResourceApp({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    if (!Env.isConfigured) {
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
      routerConfig: buildRouter(state),
    );
  }
}

/// Shown when SUPABASE_URL / SUPABASE_ANON_KEY are not configured.
class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.cloud_off_outlined,
                        size: 40, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 12),
                    Text('Backend not configured',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text(
                      'Create a `.env` file at the project root with:',
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'SUPABASE_URL=https://your-project.supabase.co\nSUPABASE_ANON_KEY=your-anon-key',
                        style: TextStyle(fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Then run the SQL in supabase/schema.sql inside the '
                      'Supabase Dashboard → SQL Editor, and restart the app.',
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
