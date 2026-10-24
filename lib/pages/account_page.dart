import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../account/account_service.dart';
import '../account/reading_library.dart';
import '../config/archive_style.dart';

enum _AuthMode { login, register, confirm, reset, recovery, password }

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _code = TextEditingController();
  _AuthMode _mode = _AuthMode.login;
  bool _busy = false;
  bool _visible = false;
  String? _message;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _code.dispose();
    super.dispose();
  }

  void _change(_AuthMode mode) => setState(() {
    _mode = mode;
    _message = null;
    _password.clear();
    _confirm.clear();
    _code.clear();
  });

  Future<void> _merge() async {
    await accountService.ensureCurrentUser();
    if (!mounted || !readingLibrary.needsGuestMerge) return;
    final choice = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('合并本机阅读记录'),
        content: const Text('可将游客的已读记录合并到账户。阅读设置使用哪一份？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('暂不合并'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 1),
            child: const Text('使用云端设置'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 2),
            child: const Text('使用本机设置'),
          ),
        ],
      ),
    );
    if (choice == 1 || choice == 2) {
      await readingLibrary.mergeGuest(useLocalSettings: choice == 2);
      await accountService.sync();
    }
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final needsEmail = _mode != _AuthMode.password;
    if (needsEmail && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _message = '请输入有效的邮箱地址');
      return;
    }
    if ([
          _AuthMode.login,
          _AuthMode.register,
          _AuthMode.password,
        ].contains(_mode) &&
        _password.text.isEmpty) {
      setState(() => _message = '请输入密码');
      return;
    }
    if ([_AuthMode.register, _AuthMode.password].contains(_mode) &&
        (_password.text.length < 8 || _password.text != _confirm.text)) {
      setState(() => _message = '密码至少 8 位，两次输入需要一致');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await accountService.init();
      final auth = accountService.client.auth;
      switch (_mode) {
        case _AuthMode.login:
          await auth.signInWithPassword(email: email, password: _password.text);
          await _merge();
          if (mounted) Navigator.of(context).pop();
        case _AuthMode.register:
          final result = await auth.signUp(
            email: email,
            password: _password.text,
          );
          _password.clear();
          _confirm.clear();
          if (result.session != null) {
            await _merge();
            if (mounted) Navigator.of(context).pop();
          } else if (mounted) {
            setState(() {
              _mode = _AuthMode.confirm;
              _message = '验证邮件已发送，请输入邮件中的验证码';
            });
          }
        case _AuthMode.confirm:
          await auth.verifyOTP(
            email: email,
            token: _code.text.trim(),
            type: OtpType.signup,
          );
          await _merge();
          if (mounted) Navigator.of(context).pop();
        case _AuthMode.reset:
          await auth.resetPasswordForEmail(email);
          if (mounted) {
            setState(() {
              _mode = _AuthMode.recovery;
              _message = '请输入重置邮件中的验证码';
            });
          }
        case _AuthMode.recovery:
          await auth.verifyOTP(
            email: email,
            token: _code.text.trim(),
            type: OtpType.recovery,
          );
          if (mounted) _change(_AuthMode.password);
        case _AuthMode.password:
          await auth.updateUser(UserAttributes(password: _password.text));
          _password.clear();
          _confirm.clear();
          await _merge();
          if (mounted) Navigator.of(context).pop();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(
          () => _message = switch (e.code) {
            'invalid_credentials' => '邮箱或密码不正确',
            'email_not_confirmed' => '请先验证邮箱',
            'over_email_send_rate_limit' => '邮件发送过于频繁，请稍后重试',
            'otp_expired' => '验证码无效或已过期，请重新发送',
            'weak_password' => '密码强度不足，请使用更长的密码',
            _ => '账户操作失败：${e.message}',
          },
        );
      }
    } catch (_) {
      if (mounted) setState(() => _message = '暂时无法连接账户服务，请检查网络后重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_mode) {
      _AuthMode.login => '登录',
      _AuthMode.register => '创建账户',
      _AuthMode.confirm => '验证邮箱',
      _AuthMode.reset => '忘记密码',
      _AuthMode.recovery => '验证重置请求',
      _AuthMode.password => '设置新密码',
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AutofillGroup(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(28),
              children: [
                const Text(
                  'ARKSTORY / ACCOUNT',
                  style: TextStyle(
                    fontFamily: 'Archive Condensed',
                    letterSpacing: 3,
                    color: ArchiveStyle.muted,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('同步阅读设置与进度', style: TextStyle(fontSize: 24)),
                const SizedBox(height: 24),
                if (!accountService.configured)
                  const Text('此构建尚未配置账户服务。你仍然可以使用游客模式，阅读记录会保存在本机。'),
                if (_mode != _AuthMode.password)
                  TextField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: '邮箱'),
                  ),
                if ([
                  _AuthMode.login,
                  _AuthMode.register,
                  _AuthMode.password,
                ].contains(_mode)) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: !_visible,
                    autofillHints: [
                      _mode == _AuthMode.login
                          ? AutofillHints.password
                          : AutofillHints.newPassword,
                    ],
                    decoration: InputDecoration(
                      labelText: '密码',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _visible = !_visible),
                        tooltip: _visible ? '隐藏密码' : '显示密码',
                        icon: Icon(
                          _visible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                if ([
                  _AuthMode.register,
                  _AuthMode.password,
                ].contains(_mode)) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirm,
                    enabled: !_busy,
                    obscureText: !_visible,
                    decoration: const InputDecoration(labelText: '确认密码'),
                  ),
                ],
                if ([
                  _AuthMode.confirm,
                  _AuthMode.recovery,
                ].contains(_mode)) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _code,
                    enabled: !_busy,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    decoration: const InputDecoration(labelText: '邮件验证码'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              if (_mode == _AuthMode.confirm) {
                                await accountService.client.auth.resend(
                                  type: OtpType.signup,
                                  email: _email.text.trim(),
                                );
                              } else {
                                await accountService.client.auth
                                    .resetPasswordForEmail(_email.text.trim());
                              }
                              if (mounted) {
                                setState(() => _message = '验证码已重新发送');
                              }
                            } catch (_) {
                              if (mounted) {
                                setState(() => _message = '发送失败，请稍后重试');
                              }
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: const Text('重新发送验证码'),
                  ),
                ],
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(_message!),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy || !accountService.configured
                      ? null
                      : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(title),
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => _change(
                              _mode == _AuthMode.login
                                  ? _AuthMode.register
                                  : _AuthMode.login,
                            ),
                      child: Text(
                        _mode == _AuthMode.login ? '创建账户' : '已有账户，返回登录',
                      ),
                    ),
                    if (_mode == _AuthMode.login)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _change(_AuthMode.reset),
                        child: const Text('忘记密码'),
                      ),
                  ],
                ),
                TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  child: const Text('暂不登录，继续阅读'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AccountPanel extends StatelessWidget {
  const AccountPanel({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([accountService, readingLibrary]),
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.person_outline),
          title: Text(accountService.user?.email ?? '游客模式'),
          subtitle: Text(
            accountService.user == null
                ? '登录后跨设备同步设置和阅读记录'
                : accountService.syncing
                ? '正在同步…'
                : readingLibrary.hasPending
                ? '有记录等待同步'
                : accountService.lastSynced == null
                ? '等待同步'
                : '已同步 ${accountService.lastSynced!.toLocal().toString().substring(11, 16)}',
          ),
          trailing: accountService.user == null
              ? TextButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).push(archiveRoute(context, (_) => const AccountPage())),
                  child: const Text('登录 / 注册'),
                )
              : Wrap(
                  children: [
                    IconButton(
                      tooltip: '同步',
                      onPressed: accountService.syncing
                          ? null
                          : () => accountService.sync(),
                      icon: const Icon(Icons.sync),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          await accountService.signOut();
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('退出失败，请重试')),
                            );
                          }
                        }
                      },
                      child: const Text('退出登录'),
                    ),
                  ],
                ),
        ),
        if (accountService.error != null)
          Text(
            accountService.error!,
            style: const TextStyle(color: Colors.orangeAccent),
          ),
        if (readingLibrary.saveError != null)
          Text(
            readingLibrary.saveError!,
            style: const TextStyle(color: Colors.orangeAccent),
          ),
        const Divider(height: 32),
      ],
    ),
  );
}
