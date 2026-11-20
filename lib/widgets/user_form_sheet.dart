import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_state.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'common.dart';

const _roles = ['ADMIN', 'MANAGER', 'TECHNICIAN', 'DRIVER'];

/// Opens the add / edit user form. Returns true when a user was saved.
/// Pass [user] to edit an existing account; [isSelf] stops an admin from locking themselves out.
Future<bool> showUserForm(BuildContext context, {UserInfo? user, bool isSelf = false}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _UserForm(user: user, isSelf: isSelf),
  );
  return saved == true;
}

class _UserForm extends StatefulWidget {
  final UserInfo? user;
  final bool isSelf;
  const _UserForm({required this.user, required this.isSelf});

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.user?.name ?? '');
  late final TextEditingController _email = TextEditingController(text: widget.user?.email ?? '');
  final TextEditingController _password = TextEditingController();
  late String _role = widget.user?.role ?? 'DRIVER';
  late bool _active = widget.user?.active ?? true;
  bool _hidePassword = true;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.user != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = context.read<AppState>().api;
      final password = _password.text;
      if (_editing) {
        await api.updateUser(
          widget.user!.id,
          name: _name.text.trim(),
          email: _email.text.trim(),
          role: _role,
          active: _active,
          password: password.isEmpty ? null : password,
        );
      } else {
        await api.createUser(
          name: _name.text.trim(),
          email: _email.text.trim(),
          role: _role,
          active: _active,
          password: password,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save the user. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_editing ? 'Edit user' : 'Add a user', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                _editing ? 'Change the role, status or password.' : 'The person can log in with this email and password.',
                style: TextStyle(color: p.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_outline_rounded)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                enabled: !_editing, // the server does not change an email after the account exists
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline_rounded)),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.isEmpty) return 'Enter an email';
                  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'This email does not look right';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: _hidePassword,
                decoration: InputDecoration(
                  labelText: _editing ? 'New password (optional)' : 'Password',
                  helperText: _editing ? 'Leave empty to keep the current password' : 'At least 6 characters',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _hidePassword = !_hidePassword),
                  ),
                ),
                validator: (v) {
                  final t = v ?? '';
                  if (!_editing && t.length < 6) return 'At least 6 characters';
                  if (_editing && t.isNotEmpty && t.length < 6) return 'At least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _role,
                decoration: const InputDecoration(labelText: 'Role', prefixIcon: Icon(Icons.badge_outlined)),
                items: [for (final r in _roles) DropdownMenuItem(value: r, child: Text(pretty(r)))],
                onChanged: widget.isSelf ? null : (v) => setState(() => _role = v ?? _role),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Account is active'),
                subtitle: Text(_active ? 'This person can log in' : 'Login is blocked', style: TextStyle(color: p.textSecondary, fontSize: 12.5)),
                value: _active,
                onChanged: widget.isSelf ? null : (v) => setState(() => _active = v),
              ),
              if (widget.isSelf)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('This is your own account, so its role and status are locked.',
                      style: TextStyle(color: p.textSecondary, fontSize: 12.5)),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : Text(_editing ? 'Save changes' : 'Create user'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
