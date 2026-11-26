import 'dart:async';

import 'school_operation_status.dart';
import 'package:flutter/material.dart';
import 'academic.dart';
import 'foundation_service_page.dart';
import 'foundation/progress.dart';
import 'blog_surface.dart';

class LocalAcademicLogin extends StatefulWidget {
  const LocalAcademicLogin(
    this.store, {
    required this.onLegacy,
    this.onClose,
    this.mark,
    super.key,
  });
  final AcademicStore store;
  final VoidCallback onLegacy;
  final VoidCallback? onClose;
  final WikiPageMark? mark;
  @override
  State<LocalAcademicLogin> createState() => _LocalLoginState();
}

class _LocalLoginState extends State<LocalAcademicLogin> {
  final account = TextEditingController(), password = TextEditingController();
  bool busy = false, obscure = true;
  bool passwordRejected = false;
  FoundationProgress? waiting;
  String message = '';
  Future<void> login({bool restore = false}) async {
    if (busy) return;
    if (!restore && (account.text.trim().isEmpty || password.text.isEmpty)) {
      setState(() => message = '请填写学号和统一认证密码。');
      return;
    }
    setState(() {
      busy = true;
      message = '';
      passwordRejected = false;
      waiting = FoundationProgress(
        message: restore ? '正在恢复会话' : '正在登录统一认证',
        startedAt: DateTime.now(),
        resource: restore ? 'inspect' : 'login',
        activeCount: 1,
      );
    });
    try {
      if (restore) {
        await widget.store.api('inspect', 'local');
        if (widget.store.schedule == null ||
            widget.store.gradeCourses == null) {
          unawaited(widget.store.loadAcademicOverview());
        }
      } else {
        await widget.store.loginLocal(account.text.trim(), password.text);
      }
      password.clear();
      if (!mounted) return;
      busy = false;
      final messenger = ScaffoldMessenger.of(context);
      if (widget.onClose != null) {
        widget.onClose!();
      } else {
        Navigator.pop(context);
      }
      messenger.showSnackBar(const SnackBar(content: Text('统一认证登录成功')));
    } catch (error) {
      if (!mounted) return;
      final code = error is AcademicApiException ? error.code : null;
      final rejected =
          code == 'credentials_rejected' || code == 'password_expired';
      if (rejected) password.clear();
      setState(() {
        passwordRejected = rejected;
        message = switch (code) {
          'credentials_rejected' => '账号或密码错误，请修改后重新登录',
          'password_expired' => '统一认证密码已过期，请修改后重新登录',
          _ =>
            error is FormatException ? error.message.toString() : '登录未完成，请重试',
        };
      });
    } finally {
      if (mounted)
        setState(() {
          busy = false;
          waiting = null;
        });
    }
  }

  @override
  void dispose() {
    if (busy) widget.store.cancelLocal();
    account.dispose();
    password.clear();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: WikiPageTitle('学校统一认证', mark: widget.mark),
      leading: widget.onClose == null
          ? null
          : BackButton(onPressed: widget.onClose),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SchoolOperationStatus(
          widget.store.foundation,
          fallback: waiting,
          cancelLabel: '取消登录',
          onCancel: busy ? widget.store.cancelLocal : null,
        ),
        BlogPanel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: account,
                enabled: !busy,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.username],
                decoration: const InputDecoration(labelText: '学号'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                enabled: !busy,
                obscureText: obscure,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) {
                  if (passwordRejected) setState(() => message = '');
                },
                onSubmitted: (_) => login(),
                decoration: InputDecoration(
                  labelText: '统一认证密码',
                  errorText: passwordRejected && message.isNotEmpty
                      ? message
                      : null,
                  errorMaxLines: 2,
                  suffixIcon: IconButton(
                    tooltip: obscure ? '显示密码' : '隐藏密码',
                    onPressed: () => setState(() => obscure = !obscure),
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: busy ? null : () => login(),
                  icon: const Icon(Icons.login),
                  label: const Text('登录并保存'),
                ),
              ),
              if (widget.store.token == 'local' && !passwordRejected)
                TextButton(
                  onPressed: busy ? null : () => login(restore: true),
                  child: const Text('恢复已保存的登录'),
                ),
              if (message.isNotEmpty && !passwordRejected)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(message),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: busy ? null : widget.onLegacy,
          icon: const Icon(Icons.public),
          label: const Text('学校网页 / 微信登录'),
        ),
      ],
    ),
  );
}

class FoundationResourcePage extends StatelessWidget {
  const FoundationResourcePage(
    this.store,
    this.resource,
    this.title, {
    this.mark,
    super.key,
  });
  final AcademicStore store;
  final String resource, title;
  final WikiPageMark? mark;
  @override
  Widget build(BuildContext context) => FoundationServicePage(
    store: store,
    resource: resource,
    title: title,
    mark: mark,
  );
}
