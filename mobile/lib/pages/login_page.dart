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

  Future<void> _editServer() async {
    final controller = TextEditingController(text: Api.baseUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("服务器地址"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "例如 http://192.168.1.100:8000",
            labelText: "地址（http://开头，结尾不带/）",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("取消")),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text("保存"),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;
    try {
      await Api.setBaseUrl(url);
      if (mounted) _toast("已保存：$url");
    } catch (_) {
      if (mounted) _toast("地址格式有误");
    }
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
              TextButton.icon(
                onPressed: _editServer,
                icon: const Icon(Icons.dns_outlined, size: 16),
                label: Text(
                  Api.baseUrl,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
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
