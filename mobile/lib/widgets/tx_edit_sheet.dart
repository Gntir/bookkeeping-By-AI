import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';

/// 记账编辑表单（弹层）：手动记账 / 编辑 AI 草稿 / 修改已有记录 共用
/// 返回 null 表示取消，否则返回表单数据 Map
Future<Map<String, dynamic>?> showTxEditSheet(
  BuildContext context, {
  String type = "expense",
  double? amount,
  String? categoryName,
  DateTime? date,
  String note = "",
}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _TxEditSheet(
      type: type,
      amount: amount,
      categoryName: categoryName,
      date: date,
      note: note,
    ),
  );
}

class _TxEditSheet extends StatefulWidget {
  final String type;
  final double? amount;
  final String? categoryName;
  final DateTime? date;
  final String note;

  const _TxEditSheet({
    required this.type,
    this.amount,
    this.categoryName,
    this.date,
    this.note = "",
  });

  @override
  State<_TxEditSheet> createState() => _TxEditSheetState();
}

class _TxEditSheetState extends State<_TxEditSheet> {
  late String _type;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late DateTime _date;
  String? _categoryName;
  int? _categoryId;
  List<Category> _categories = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.type;
    _amount = TextEditingController(text: widget.amount?.toStringAsFixed(2) ?? "");
    _note = TextEditingController(text: widget.note);
    _date = widget.date ?? DateTime.now();
    _categoryName = widget.categoryName;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await Api.categories(_type);
    if (!mounted) return;
    setState(() => _categories = cats);
    // 当前类型下若没有选中分类或分类不属于该类型，默认选第一个
    if ((_categoryName == null || !cats.any((c) => c.name == _categoryName)) && cats.isNotEmpty) {
      _categoryName = cats.first.name;
      _categoryId = cats.first.id;
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请输入正确金额")));
      return;
    }
    if (_categoryName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("请选择分类")));
      return;
    }
    setState(() => _saving = true);
    Navigator.of(context).pop({
      "type": _type,
      "amount": amount,
      "category_name": _categoryName,
      "category_id": _categoryId,
      "date": _date,
      "note": _note.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text("记一笔", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: "expense", label: Text("支出")),
                  ButtonSegment(value: "income", label: Text("收入")),
                ],
                selected: {_type},
                onSelectionChanged: (s) {
                  setState(() => _type = s.first);
                  _categoryName = null;
                  _categoryId = null;
                  _loadCategories();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(hintText: "0.00", prefixText: "¥ "),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text("分类", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: _categories.isEmpty
                ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final c = _categories[i];
                      final selected = c.name == _categoryName;
                      return ChoiceChip(
                        label: Text("${c.icon} ${c.name}"),
                        selected: selected,
                        onSelected: (_) => setState(() {
                          _categoryName = c.name;
                          _categoryId = c.id;
                        }),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (d != null) setState(() => _date = d);
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(prefixIcon: Icon(Icons.calendar_today, size: 20)),
                    child: Text(DateFormat("yyyy-MM-dd EEEE", "zh_CN").format(_date)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            decoration: const InputDecoration(hintText: "备注（可选）"),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? "保存中…" : "保存"),
          ),
        ],
      ),
    );
  }
}
