import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/settings/domain/app_settings.dart';
import 'package:ingrain/features/settings/presentation/viewmodel/settings_view_model.dart';
import 'package:ingrain/shared/widgets/double_back_to_exit.dart';

/// Doubles as the sign-in screen and the display-name step.
///
/// The router sends anyone who is not `isOnboarded` here, so all three states have
/// to be reachable from this one view: signed out, signed in but unnamed, and the
/// brief moment before the redirect fires.
class OnboardingView extends ConsumerStatefulWidget {
  const OnboardingView({super.key});

  @override
  ConsumerState<OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends ConsumerState<OnboardingView> {
  final _nameFormKey = GlobalKey<FormState>();
  final _signInFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _goalController = TextEditingController(text: '30');
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isCreateMode = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with whatever the provider already knows: the Google display name,
    // or the email local part. Saves a field the user would otherwise retype.
    _prefillName();
  }

  Future<void> _prefillName() async {
    final suggested = await ref
        .read(authViewModelProvider.notifier)
        .suggestedDisplayName();
    if (!mounted || suggested == null) return;
    _nameController.text = suggested;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _goalController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<T?> _run<T>(Future<T> Function() action) async {
    if (_busy) return null;
    setState(() => _busy = true);
    try {
      return await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitName() async {
    if (!_nameFormKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final goal = int.parse(_goalController.text);

    await _run(() async {
      final authVm = ref.read(authViewModelProvider.notifier);
      final settingsVm = ref.read(settingsViewModelProvider.notifier);
      final current = ref.read(settingsViewModelProvider).settings;
      final nextSettings = (current ?? const AppSettings()).copyWith(
        dailyGoalMinutes: goal,
      );

      // Mark the session as onboarded immediately so the router can leave the
      // onboarding screen even if the Firestore writes are slow or temporarily
      // blocked. The settings save still runs in the background afterwards.
      unawaited(authVm.completeOnboarding(displayName: name));
      unawaited(settingsVm.update(nextSettings));
    });
  }

  Future<void> _submitCredentials() async {
    if (!_signInFormKey.currentState!.validate()) return;
    final authVm = ref.read(authViewModelProvider.notifier);
    await _run(
      () => _isCreateMode
          ? authVm.createAccount(
              _emailController.text,
              _passwordController.text,
            )
          : authVm.signInWithEmail(
              _emailController.text,
              _passwordController.text,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authViewModelProvider);
    final theme = Theme.of(context);

    if (authState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DoubleBackToExit(
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Welcome to ingrain'),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: authState.isSignedIn
                ? _buildNameStep(theme)
                : _buildSignInStep(theme, authState.error),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInStep(ThemeData theme, String? error) {
    final authVm = ref.read(authViewModelProvider.notifier);
    return Form(
      key: _signInFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _badge(theme),
          const SizedBox(height: 24),
          Text('Sign in', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Your vocabulary, review history and immersion sessions follow your '
            'account across devices.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(authVm.signInWithGoogle),
            icon: const Icon(Icons.login),
            label: const Text('Continue with Google'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or', style: theme.textTheme.bodySmall),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.alternate_email),
            ),
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Enter an email address'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              prefixIcon: Icon(Icons.lock_outline),
            ),
            obscureText: true,
            validator: (v) {
              if (_isCreateMode && (v == null || v.length < 6)) {
                return 'Use at least 6 characters';
              }
              return (v == null || v.isEmpty) ? 'Enter a password' : null;
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error,
              style: TextStyle(color: theme.colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _submitCredentials,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_isCreateMode ? 'Create account' : 'Sign in'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() => _isCreateMode = !_isCreateMode),
            child: Text(
              _isCreateMode
                  ? 'Already have an account? Sign in'
                  : 'New here? Create an account',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNameStep(ThemeData theme) {
    return Form(
      key: _nameFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _badge(theme),
          const SizedBox(height: 24),
          Text('Almost there', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Pick a display name and a daily immersion goal to get started.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Display name',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _goalController,
            decoration: const InputDecoration(
              labelText: 'Daily goal (minutes)',
              prefixIcon: Icon(Icons.timer_outlined),
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a goal';
              final n = int.tryParse(v);
              if (n == null || n <= 0) return 'Enter a positive number';
              return null;
            },
          ),
          const SizedBox(height: 24),
          _busy
              ? const CircularProgressIndicator()
              : FilledButton(
                  onPressed: _submitName,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Start using ingrain'),
                ),
        ],
      ),
    );
  }

  Widget _badge(ThemeData theme) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Icon(Icons.spa, size: 48, color: Colors.white),
    );
  }
}
