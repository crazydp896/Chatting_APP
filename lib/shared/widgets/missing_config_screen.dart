import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';

/// Shown when the app is launched without `--dart-define` credentials.
/// Explains exactly how to supply Supabase URL + anon key.
class MissingConfigScreen extends StatelessWidget {
  const MissingConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.settings_suggest_outlined, size: 64, color: scheme.primary),
                const SizedBox(height: 16),
                Text(
                  'Supabase not configured',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Run the app with your project credentials:',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'flutter run -d chrome \\\n'
                    '  --dart-define=SUPABASE_URL=https://YOUR.supabase.co \\\n'
                    '  --dart-define=SUPABASE_ANON_KEY=eyJ...',
                    style: TextStyle(fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Apply supabase/migrations/0001_initial_schema.sql in the '
                  'Supabase SQL editor first.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Text(
                  'App: ${AppConfig.appName}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
