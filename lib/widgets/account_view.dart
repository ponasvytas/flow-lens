import 'package:flutter/material.dart';

import '../controllers/account_controller.dart';
import '../models/app_entitlement.dart';

class AccountView extends StatefulWidget {
  const AccountView({required this.controller, super.key});

  final AccountController controller;

  @override
  State<AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<AccountView> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _creatingAccount = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 600;
    final content = ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: _buildBody(context),
            ),
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Dialog(child: SizedBox(width: 460, child: content));
    }
    return Scaffold(body: SafeArea(child: content));
  }

  Widget _buildHeader(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Row(
      children: [
        const Icon(Icons.account_circle, size: 28),
        const SizedBox(width: 12),
        const Text(
          'Account',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    ),
  );

  Widget _buildBody(BuildContext context) {
    if (widget.controller.isInitializing) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (widget.controller.isSignedIn) return _buildSignedIn(context);
    if (!widget.controller.canAuthenticate) {
      return const Text(
        'Cloud accounts are unavailable on this device. Local features remain available.',
      );
    }
    return _buildSignIn(context);
  }

  Widget _buildSignedIn(BuildContext context) {
    final user = widget.controller.user!;
    final entitlement = widget.controller.entitlement;
    final premium = widget.controller.capabilities.canSyncSettings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          user.displayName ?? user.email ?? 'Signed-in account',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          premium ? 'Premium active' : _entitlementLabel(entitlement),
          style: TextStyle(
            color: premium ? Colors.green.shade700 : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (widget.controller.errorMessage case final message?) ...[
          const SizedBox(height: 16),
          _ErrorText(message),
        ],
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: widget.controller.isBusy
              ? null
              : widget.controller.signOut,
          child: const Text('Sign out'),
        ),
      ],
    );
  }

  Widget _buildSignIn(BuildContext context) => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _creatingAccount ? 'Create an account' : 'Sign in for premium',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        const Text('Local features remain available without signing in.'),
        const SizedBox(height: 20),
        TextFormField(
          controller: _emailController,
          enabled: !widget.controller.isBusy,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty || !email.contains('@')) {
              return 'Enter a valid email address.';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          enabled: !widget.controller.isBusy,
          obscureText: _hidePassword,
          autofillHints: _creatingAccount
              ? const [AutofillHints.newPassword]
              : const [AutofillHints.password],
          decoration: InputDecoration(
            labelText: 'Password',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
              icon: Icon(
                _hidePassword ? Icons.visibility : Icons.visibility_off,
              ),
            ),
          ),
          validator: (value) {
            if ((value?.length ?? 0) < 6) {
              return 'Password must be at least 6 characters.';
            }
            return null;
          },
          onFieldSubmitted: (_) => _submit(),
        ),
        if (widget.controller.errorMessage case final message?) ...[
          const SizedBox(height: 12),
          _ErrorText(message),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: widget.controller.isBusy ? null : _submit,
          child: widget.controller.isBusy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_creatingAccount ? 'Create account' : 'Sign in'),
        ),
        TextButton(
          onPressed: widget.controller.isBusy
              ? null
              : () {
                  widget.controller.clearError();
                  setState(() => _creatingAccount = !_creatingAccount);
                },
          child: Text(
            _creatingAccount
                ? 'Already have an account? Sign in'
                : 'Need an account? Create one',
          ),
        ),
        if (!_creatingAccount)
          TextButton(
            onPressed: widget.controller.isBusy ? null : _resetPassword,
            child: const Text('Forgot password?'),
          ),
      ],
    ),
  );

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final email = _emailController.text;
    final password = _passwordController.text;
    if (_creatingAccount) {
      await widget.controller.createAccount(email: email, password: password);
    } else {
      await widget.controller.signIn(email: email, password: password);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _formKey.currentState?.validate();
      return;
    }
    final sent = await widget.controller.sendPasswordReset(email);
    if (!mounted || !sent) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
  }

  String _entitlementLabel(AppEntitlement entitlement) =>
      entitlement.status == EntitlementStatus.unknown
      ? 'Premium status unavailable — local mode'
      : 'Free account — local mode';
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Text(
    message,
    style: TextStyle(color: Theme.of(context).colorScheme.error),
  );
}
