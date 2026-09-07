import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api_client.dart';
import '../models.dart';

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage> with AutomaticKeepAliveClientMixin {
  DateTime _month = DateTime.now();
  bool _loading = true;
  Summary? _summary;
  List<CategoryStat> _expenseByCat = [];
  List<DailyStat> _daily = [];
  List<MemberStat> _members = [];

  static const _palette = [
    Color(0xFF2E9E6B), Color(0xFFF5A623), Color(0xFF4A90D9), Color(0xFFBD5B5B),
    Color(0xFF9B59B6), Color(0xFF16A085), Color(0xFFE67E22), Color(0xFF34495E),
  ];

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
      final results = await Future.wait([
        Api.summary(_monthStr),
        Api.categoryStats(_monthStr, "expense"),
        Api.dailyStats(_monthStr),
        Api.memberStats(_monthStr),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as Summary;
        _expenseByCat = results[1] as List<CategoryStat>;
        _daily = results[2] as List<DailyStat>;
        _members = results[3] as List<MemberStat>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _shift(-1)),
            Text(DateFormat("yyyy年M月").format(_month)),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _shift(1)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _topCard(),
                const SizedBox(height: 16),
                if (_expenseByCat.isNotEmpty) ...[
                  _sectionTitle("支出分类"),
                  _pieCard(),
                  const SizedBox(height: 16),
                ],
                if (_daily.isNotEmpty) ...[
                  _sectionTitle("每日趋势"),
                  _lineCard(),
                  const SizedBox(height: 16),
                ],
                if (_members.length > 1) ...[
                  _sectionTitle("成员对比"),
                  _memberCard(),
                ],
              ],
            ),
    );
  }

  void _shift(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _topCard() {
    final s = _summary;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            _num("收入", s?.income ?? 0, const Color(0xFF2E9E6B)),
            Container(width: 1, height: 40, color: Colors.grey.shade200),
            _num("支出", s?.expense ?? 0, const Color(0xFFF5A623)),
            Container(width: 1, height: 40, color: Colors.grey.shade200),
            _num("结余", s?.balance ?? 0, const Color(0xFF4A90D9)),
          ],
        ),
      ),
    );
  }

  Widget _num(String label, double value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value.toStringAsFixed(2),
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _pieCard() {
    final total = _expenseByCat.fold<double>(0, (sum, e) => sum + e.amount);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              height: 130,
              width: 130,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 34,
                  sections: _expenseByCat.take(8).toList().asMap().entries.map((entry) {
                    final i = entry.key;
                    final e = entry.value;
                    return PieChartSectionData(
                      value: e.amount,
                      color: _palette[i % _palette.length],
                      radius: 16,
                      title: e.amount / total > 0.12 ? "${(e.amount / total * 100).toStringAsFixed(0)}%" : "",
                      titleStyle: const TextStyle(fontSize: 10, color: Colors.white),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                children: _expenseByCat.take(6).toList().asMap().entries.map((entry) {
                  final i = entry.key;
                  final e = entry.value;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: _palette[i % _palette.length],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text("${e.icon} ${e.categoryName}（${e.count}笔）",
                              style: const TextStyle(fontSize: 12)),
                        ),
                        Text("¥${e.amount.toStringAsFixed(0)}",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _lineCard() {
    final days = _daily.length;
    final spots = _daily.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.expense)).toList();
    final maxExpense = _daily.fold<double>(0, (m, d) => d.expense > m ? d.expense : m);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: maxExpense * 1.2,
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: days > 10 ? (days / 4).ceilToDouble() : 1,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= _daily.length) return const SizedBox();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(_daily[idx].date.substring(8), style: const TextStyle(fontSize: 10)),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      barWidth: 2.5,
                      color: const Color(0xFFF5A623),
                      dotData: FlDotData(show: days <= 10),
                      belowBarData: BarAreaData(
                        show: true,
                        color: const Color(0xFFF5A623).withValues(alpha: 0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text("每日支出（元）", style: TextStyle(fontSize: 11, color: Color(0xFF999999))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberCard() {
    final maxVal = _members.fold<double>(0, (m, u) => u.expense > m ? u.expense : m);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: _members.map((u) {
            final pct = maxVal == 0 ? 0.0 : u.expense / maxVal;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: const Color(0xFF2E9E6B).withValues(alpha: 0.15),
                        child: Text(u.nickname.substring(0, 1),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF2E9E6B))),
                      ),
                      const SizedBox(width: 8),
                      Text(u.nickname, style: const TextStyle(fontSize: 13)),
                      const Spacer(),
                      Text("支出 ¥${u.expense.toStringAsFixed(0)} · 收入 ¥${u.income.toStringAsFixed(0)}",
                          style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF2E9E6B),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
