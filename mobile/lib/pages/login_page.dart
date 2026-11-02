import 'package:flutter/material.dart';

import '../api_client.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _nickname = TextEditingController();
  bool _isRegister = false;
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final password = _password.text;
    if (phone.length < 5 || password.length < 6) {
      _toast("手机号至少5位，密码至少6位");
      return;
    }
    setState(() => _loading = true);
    try {
      if (_isRegister) {
        if (_nickname.text.trim().isEmpty) {
          _toast("请填写昵称");
          return;
        }
        await Api.register(phone, password, _nickname.text.trim());
      } else {
        await Api.login(phone, password);
      }
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      }
    } catch (e) {
      _toast(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),
              const Text("💰", textAlign: TextAlign.center, style: TextStyle(fontSize: 56)),
              const SizedBox(height: 12),
              Text(
                "AI 记账",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                "说一句话，自动记好账",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              const SizedBox(height: 36),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: "手机号"),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(hintText: "密码（至少6位）"),
              ),
              if (_isRegister) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _nickname,
                  decoration: const InputDecoration(hintText: "昵称（账本里显示的名字）"),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isRegister ? "注册" : "登录"),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _isRegister = !_isRegister),
                child: Text(_isRegister ? "已有账号？去登录" : "没有账号？注册一个"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
