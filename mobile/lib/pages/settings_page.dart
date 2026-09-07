import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api_client.dart';
import '../models.dart';
import 'login_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final user = AppState.user;
    final ledger = AppState.currentLedger;
    return Scaffold(
      appBar: AppBar(title: const Text("我的")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 用户卡片
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF2E9E6B).withValues(alpha: 0.15),
                    child: Text(
                      (user?.nickname ?? "?").substring(0, 1),
                      style: const TextStyle(fontSize: 20, color: Color(0xFF2E9E6B)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.nickname ?? "",
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                      Text(user?.phone ?? "",
                          style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 账本管理
          _section("账本"),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                RadioGroup<int>(
                  groupValue: AppState.currentLedgerId,
                  onChanged: (value) async {
                    if (value == null) return;
                    await AppState.setCurrentLedger(value);
                    setState(() {});
                  },
                  child: Column(
                    children: [
                      for (final l in AppState.ledgers)
                        RadioListTile<int>(
                          value: l.id,
                          title: Text(l.name),
                          subtitle: Text(
                            l.memberCount > 1
                                ? "${l.memberCount}人共享 · 我是${l.role == "owner" ? "创建者" : "成员"}"
                                : "个人账本",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline, color: Color(0xFF2E9E6B)),
                  title: const Text("新建账本"),
                  subtitle: const Text("家庭/合租等多人场景", style: TextStyle(fontSize: 12)),
                  onTap: _createLedger,
                ),
                ListTile(
                  leading: const Icon(Icons.group_add_outlined, color: Color(0xFF2E9E6B)),
                  title: const Text("邀请码加入"),
                  onTap: _joinLedger,
                ),
                if (ledger != null)
                  ListTile(
                    leading: const Icon(Icons.share_outlined, color: Color(0xFF2E9E6B)),
                    title: Text("本账本邀请码：${ledger.inviteCode}"),
                    subtitle: const Text("点击复制，发给家人即可一起记账", style: TextStyle(fontSize: 12)),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: ledger.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("邀请码已复制")));
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 薪资
          _section("固定薪资"),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.payments_outlined, color: Color(0xFF2E9E6B)),
              title: const Text("每月薪资设置"),
              subtitle: const Text("到发薪日自动记一笔收入", style: TextStyle(fontSize: 12)),
              onTap: _salarySettings,
            ),
          ),
          const SizedBox(height: 16),

          // 其他
          _section("其他"),
          Card(
            margin: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dns_outlined),
                  title: const Text("服务器地址"),
                  subtitle: Text(Api.baseUrl, style: const TextStyle(fontSize: 12)),
                  onTap: _editBaseUrl,
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text("退出登录", style: TextStyle(color: Colors.red)),
                  onTap: _logout,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Text("AI 记账 Demo v0.1.0",
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _section(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
    );
  }

  Future<void> _createLedger() async {
    final name = await _inputDialog("新建账本", "账本名称（如：家庭账本）");
    if (name == null || name.trim().isEmpty) return;
    try {
      await Api.createLedger(name.trim());
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("创建成功，可在上方切换")));
      }
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _joinLedger() async {
    final code = await _inputDialog("邀请码加入", "输入6位邀请码");
    if (code == null || code.trim().isEmpty) return;
    try {
      final l = await Api.joinLedger(code.trim().toUpperCase());
      await AppState.setCurrentLedger(l.id);
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("已加入「${l.name}」")));
      }
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _salarySettings() async {
    SalaryRule? rule;
    try {
      final rules = await Api.salaryRules();
      rule = rules.where((r) => r.ledgerId == AppState.currentLedgerId).firstOrNull;
    } catch (e) {
      _err(e);
      return;
    }
    if (!mounted) return;

    final amount = TextEditingController(
        text: rule == null ? "" : rule.amount.toStringAsFixed(0));
    final payDay = TextEditingController(
        text: rule == null ? "10" : rule.payDay.toString());

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.only(
            left: 16, right: 16, top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("每月固定薪资（${AppState.currentLedger?.name ?? ""}）",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                rule == null ? "设置后，每到发薪日自动记一笔收入" : "上次生成：${rule.lastRun ?? "尚未生成"}",
                style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: "每月薪资金额", prefixText: "¥ "),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: payDay,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: "发薪日（每月几号，1-31）"),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () async {
                  final a = double.tryParse(amount.text.trim());
                  final d = int.tryParse(payDay.text.trim());
                  if (a == null || a <= 0 || d == null || d < 1 || d > 31) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("请输入正确的金额和发薪日")));
                    return;
                  }
                  try {
                    await Api.saveSalaryRule(id: rule?.id, amount: a, payDay: d);
                    if (context.mounted) Navigator.pop(context);
                    setState(() {});
                  } catch (e) {
                    _err(e);
                  }
                },
                child: const Text("保存"),
              ),
              if (rule != null)
                TextButton(
                  onPressed: () async {
                    try {
                      await Api.deleteSalaryRule(rule!.id);
                      if (context.mounted) Navigator.pop(context);
                      setState(() {});
                    } catch (e) {
                      _err(e);
                    }
                  },
                  child: const Text("删除此规则", style: TextStyle(color: Colors.red)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editBaseUrl() async {
    final url = await _inputDialog("服务器地址", "例如 http://192.168.1.100:8000",
        initial: Api.baseUrl);
    if (url == null || url.trim().isEmpty) return;
    await Api.setBaseUrl(url.trim());
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("已保存")));
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("退出登录"),
        content: const Text("确定退出当前账号吗？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("退出")),
        ],
      ),
    );
    if (ok != true) return;
    await AppState.clear();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<String?> _inputDialog(String title, String hint, {String? initial}) {
    final c = TextEditingController(text: initial ?? "");
    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, decoration: InputDecoration(hintText: hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("取消")),
          TextButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text("确定")),
        ],
      ),
    );
  }

  void _err(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
}
