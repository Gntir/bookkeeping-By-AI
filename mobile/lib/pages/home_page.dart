import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import 'chat_page.dart';
import 'settings_page.dart';
import 'stats_page.dart';
import 'transactions_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  final _homeKey = GlobalKey<_HomeTabState>();

  static const _tabs = [
    NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: "首页"),
    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: "明细"),
    NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: "统计"),
    NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: "我的"),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          _HomeTab(key: _homeKey),
          const TransactionsPage(),
          const StatsPage(),
          const SettingsPage(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatPage()));
          // 记账回来刷新首页汇总与最近账单
          _homeKey.currentState?._load();
        },
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text("记账"),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: _tabs,
      ),
    );
  }
}

/// 首页：本月汇总 + 最近账单
class _HomeTab extends StatefulWidget {
  const _HomeTab({super.key});

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> with AutomaticKeepAliveClientMixin {
  Summary? _summary;
  List<Tx> _recent = [];
  bool _loading = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  String get _month => DateFormat("yyyy-MM").format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await Api.summary(_month);
      final txs = await Api.transactions(month: _month);
      if (!mounted) return;
      setState(() {
        _summary = s;
        _recent = txs.take(5).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ledger = AppState.currentLedger;
    return Scaffold(
      appBar: AppBar(
        title: Text(ledger?.name ?? "AI 记账"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_error != null)
                    Card(
                      color: Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
                      ),
                    ),
                  _summaryCard(),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text("最近账单", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const Spacer(),
                      if (AppState.currentLedger != null && AppState.currentLedger!.memberCount > 1)
                        Text(
                          "${AppState.currentLedger!.memberCount} 人共享",
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_recent.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Text("还没有记录", style: TextStyle(color: Colors.grey[500])),
                            const SizedBox(height: 4),
                            Text("点下方「记账」按钮，说句话试试",
                                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: _recent.map(_txTile).toList(),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _summaryCard() {
    final s = _summary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E9E6B), Color(0xFF1F7A50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("本月结余（${_month.substring(5)}月）",
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            "¥ ${s == null ? "--" : s.balance.toStringAsFixed(2)}",
            style: const TextStyle(
                color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("收入", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("¥ ${s == null ? "--" : s.income.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("支出", style: TextStyle(color: Colors.white70, fontSize: 12)),
                    Text("¥ ${s == null ? "--" : s.expense.toStringAsFixed(2)}",
                        style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _txTile(Tx t) {
    final isExpense = t.type == "expense";
    return ListTile(
      leading: Text(
        _iconFor(t.categoryName),
        style: const TextStyle(fontSize: 24),
      ),
      title: Text(t.categoryName + (t.note.isEmpty ? "" : " · ${t.note}"),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        "${DateFormat("MM-dd").format(t.date)} · ${t.creatorName}",
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Text(
        "${isExpense ? "-" : "+"}${t.amount.toStringAsFixed(2)}",
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isExpense ? const Color(0xFF222222) : const Color(0xFF2E9E6B),
        ),
      ),
    );
  }
}

String _iconFor(String category) {
  const map = {
    "餐饮": "🍜", "交通": "🚌", "购物": "🛍️", "居住": "🏠", "娱乐": "🎮",
    "医疗": "💊", "教育": "📚", "通讯": "📱", "人情": "🎁", "宠物": "🐱",
    "其他支出": "📦", "工资": "💰", "奖金": "🏆", "兼职": "💼",
    "理财收益": "📈", "二手闲置": "♻️", "红包": "🧧", "其他收入": "💵",
  };
  return map[category] ?? "🏷️";
}
