import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';
import '../widgets/tx_edit_sheet.dart';

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> with AutomaticKeepAliveClientMixin {
  DateTime _month = DateTime.now();
  String? _typeFilter; // null=全部
  List<Tx> _items = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  String get _monthStr => DateFormat("yyyy-MM").format(_month);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await Api.transactions(month: _monthStr, type: _typeFilter);
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
    });
    _load();
  }

  Future<void> _add() async {
    final result = await showTxEditSheet(context);
    if (result == null) return;
    try {
      await Api.createTransaction(
        type: result["type"] as String,
        amount: result["amount"] as double,
        categoryName: result["category_name"] as String,
        categoryId: result["category_id"] as int?,
        date: result["date"] as DateTime,
        note: result["note"] as String,
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _edit(Tx t) async {
    final result = await showTxEditSheet(
      context,
      type: t.type,
      amount: t.amount,
      categoryName: t.categoryName,
      date: t.date,
      note: t.note,
    );
    if (result == null) return;
    try {
      await Api.updateTransaction(t.id, {
        "type": result["type"],
        "amount": result["amount"],
        "category_id": result["category_id"],
        "category_name": result["category_name"],
        "date": DateFormat("yyyy-MM-dd").format(result["date"] as DateTime),
        "note": result["note"],
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _delete(Tx t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("删除记录"),
        content: Text("确定删除「${t.categoryName} ¥${t.amount.toStringAsFixed(2)}」吗？"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("取消")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("删除"),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteTransaction(t.id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    // 按日期分组
    final groups = <String, List<Tx>>{};
    for (final t in _items) {
      final key = DateFormat("yyyy-MM-dd").format(t.date);
      groups.putIfAbsent(key, () => []).add(t);
    }
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
            Text(DateFormat("yyyy年M月").format(_month)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            initialValue: _typeFilter,
            onSelected: (v) {
              setState(() => _typeFilter = v == "all" ? null : v);
              _load();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: "all", child: Text("全部")),
              PopupMenuItem(value: "expense", child: Text("只看支出")),
              PopupMenuItem(value: "income", child: Text("只看收入")),
            ],
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(
                _typeFilter == "expense" ? Icons.south_west : (_typeFilter == "income" ? Icons.north_east : Icons.filter_list),
                size: 20,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: "manual_add",
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(child: Text("本月暂无记录", style: TextStyle(color: Colors.grey[500])))
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 80, top: 8),
                  itemCount: keys.length,
                  itemBuilder: (_, i) {
                    final key = keys[i];
                    final list = groups[key]!;
                    var dayExpense = 0.0;
                    var dayIncome = 0.0;
                    for (final t in list) {
                      if (t.type == "expense") {
                        dayExpense += t.amount;
                      } else {
                        dayIncome += t.amount;
                      }
                    }
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Row(
                            children: [
                              Text(key.substring(5).replaceFirst("-", "/"),
                                  style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF666666))),
                              const SizedBox(width: 8),
                              if (dayExpense > 0)
                                Text("支 ¥${dayExpense.toStringAsFixed(0)}",
                                    style: const TextStyle(fontSize: 11, color: Colors.orange)),
                              if (dayIncome > 0) ...[
                                const SizedBox(width: 6),
                                Text("收 ¥${dayIncome.toStringAsFixed(0)}",
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF2E9E6B))),
                              ],
                            ],
                          ),
                        ),
                        Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: list.map((t) => _tile(t)).toList(),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Widget _tile(Tx t) {
    final isExpense = t.type == "expense";
    return ListTile(
      onTap: () => _edit(t),
      onLongPress: () => _delete(t),
      title: Row(
        children: [
          Text(t.categoryName, style: const TextStyle(fontSize: 15)),
          if (t.note.isNotEmpty) ...[
            const SizedBox(width: 6),
            Flexible(
              child: Text(t.note,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
            ),
          ],
          if (t.source == "salary") ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF2E9E6B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text("自动", style: TextStyle(fontSize: 10, color: Color(0xFF2E9E6B))),
            ),
          ],
          if (t.source == "ai") ...[
            const SizedBox(width: 6),
            const Text("AI", style: TextStyle(fontSize: 10, color: Color(0xFF7B61FF))),
          ],
        ],
      ),
      subtitle: Text(t.creatorName, style: const TextStyle(fontSize: 12)),
      trailing: Text(
        "${isExpense ? "-" : "+"}${t.amount.toStringAsFixed(2)}",
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isExpense ? const Color(0xFF222222) : const Color(0xFF2E9E6B),
        ),
      ),
    );
  }
}
