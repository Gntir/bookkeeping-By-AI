import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api_client.dart';
import '../models.dart';
import '../widgets/tx_edit_sheet.dart';

class ChatMessage {
  final bool fromUser;
  final String text;
  final List<DraftItem> drafts;
  final Set<int> savedIndexes; // 已入账的草稿下标
  final bool ephemeral; // 欢迎语/错误提示：不进入 AI 上下文

  ChatMessage({
    required this.fromUser,
    required this.text,
    this.drafts = const [],
    this.ephemeral = false,
    Set<int>? savedIndexes,
  }) : savedIndexes = savedIndexes ?? {};
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;

  // 语音输入状态
  AudioRecorder? _recorder;
  bool _recording = false;
  bool _transcribing = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;
  bool _slideCancel = false; // 录音中手指上滑 → 松手取消
  bool _recordStarting = false; // 长按后启动中（权限/录音器初始化）
  bool _pendingRelease = false; // 启动期间手指已松开

  static const _hints = [
    "今天午饭花了35",
    "昨天打车回家 28.5",
    "这个月发了工资 12000",
    "闲鱼卖了旧手机800，买菜50",
  ];

  @override
  void initState() {
    super.initState();
    _addWelcome();
  }

  void _addWelcome() {
    _messages.add(ChatMessage(
      fromUser: false,
      ephemeral: true,
      text: "你好呀！我是 AI 记账助手，跟我说说今天花了什么钱吧～\n比如：${_hints.first}",
    ));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    _recordTimer?.cancel();
    _recorder?.dispose();
    super.dispose();
  }

  /// 语音输入（微信式长按说话）：长按麦克风开始录音，松手识别，上滑取消
  Future<void> _startRecording() async {
    if (_transcribing || _recording || _recordStarting) return;
    _recordStarting = true;
    final rec = AudioRecorder();
    try {
      if (!await rec.hasPermission()) {
        rec.dispose();
        _toast("需要麦克风权限，请在系统设置中允许");
        return;
      }
      final dir = await getTemporaryDirectory();
      await rec.start(
        const RecordConfig(
          encoder: AudioEncoder.wav, // 后端模型只认 wav/mp3
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: "${dir.path}/voice_input.wav",
      );
      // 手指在权限弹窗/启动期间已松开：直接停止，当作太短
      if (_pendingRelease) {
        _pendingRelease = false;
        await rec.stop();
        await rec.dispose();
        _toast("说话时间太短啦");
        return;
      }
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
      setState(() {
        _recorder = rec;
        _recording = true;
        _recordSeconds = 0;
        _slideCancel = false;
      });
    } catch (e) {
      rec.dispose();
      _toast("无法开始录音：$e");
    } finally {
      _recordStarting = false;
    }
  }

  /// 松手：正常结束并上传识别；cancel=true（上滑/手势中断）则丢弃
  Future<void> _finishRecording({bool cancel = false}) async {
    // 启动期间松手：记下标记，等启动完成立即停止
    if (_recordStarting) {
      _pendingRelease = true;
      return;
    }
    if (!_recording) return;

    final rec = _recorder!;
    final seconds = _recordSeconds;
    _recordTimer?.cancel();
    final path = await rec.stop();
    await rec.dispose();
    setState(() {
      _recorder = null;
      _recording = false;
      _slideCancel = false;
    });

    if (cancel) {
      _toast("已取消");
      return;
    }
    if (seconds < 1) {
      _toast("说话时间太短啦");
      return;
    }
    if (path == null) {
      _toast("录音失败，再试一次");
      return;
    }

    setState(() => _transcribing = true);
    try {
      final text = await Api.uploadVoice(path);
      if (text.trim().isEmpty) {
        _toast("没听清，再试一次？");
      } else {
        _input.text = text.trim();
        // 光标移到末尾并聚焦，方便用户检查/修改后发送
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
        if (mounted) FocusScope.of(context).requestFocus(_focus);
      }
    } catch (e) {
      _toast("识别失败：$e");
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  void _toast(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  /// 从消息列表构建 AI 上下文（跳过欢迎语/错误对，只取最近 12 条控制 token）
  List<Map<String, dynamic>> _buildHistory() {
    final hist = <Map<String, dynamic>>[];
    for (var i = 0; i < _messages.length; i++) {
      final m = _messages[i];
      if (m.ephemeral) continue;
      if (m.fromUser) {
        // 紧跟错误气泡的用户消息（发送失败那次）不进上下文
        final next = i + 1 < _messages.length ? _messages[i + 1] : null;
        if (next != null && next.ephemeral) continue;
        hist.add({"role": "user", "content": m.text});
      } else {
        var content = m.text;
        if (m.drafts.isNotEmpty) {
          final parts = m.drafts
              .map((d) =>
                  "${d.type == "expense" ? "支出" : "收入"}${d.amount.toStringAsFixed(d.amount == d.amount.truncateToDouble() ? 0 : 2)}元 ${d.categoryName}"
                  "${d.note.isEmpty ? "" : "(${d.note})"} ${DateFormat("yyyy-MM-dd").format(d.date)}")
              .join("；");
          // 历史摘要格式很关键：必须明确"调用了函数"，否则模型会学着
          // 用纯文字报账而不调用 save_transaction（曾导致只回文字不出卡片）
          content = content.isEmpty
              ? "（已调用 save_transaction：$parts）"
              : "$content\n（已调用 save_transaction：$parts）";
        }
        if (content.isNotEmpty) hist.add({"role": "assistant", "content": content});
      }
    }
    return hist.length > 12 ? hist.sublist(hist.length - 12) : hist;
  }

  Future<void> _send([String? override]) async {
    final text = (override ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    _input.clear();
    final history = _buildHistory();
    setState(() {
      _messages.add(ChatMessage(fromUser: true, text: text));
      _sending = true;
    });
    _scrollToEnd();

    try {
      final resp = await Api.aiParse(text, history: history);
      final drafts = ((resp["drafts"] ?? []) as List)
          .map((e) => DraftItem.fromJson(e))
          .toList();
      setState(() {
        _messages.add(ChatMessage(fromUser: false, text: resp["reply"] ?? "", drafts: drafts));
      });
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(fromUser: false, ephemeral: true, text: "出错了：$e"));
      });
    } finally {
      setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  Future<void> _deleteMessage(int index) async {
    final msg = _messages[index];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("删除这条消息？"),
        content: Text(msg.text.isEmpty ? "（账单卡片）" : msg.text),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("删除"),
          ),
        ],
      ),
    );
    if (ok == true && index < _messages.length) {
      setState(() => _messages.removeAt(index));
    }
  }

  Future<void> _clearChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("清空对话？"),
        content: const Text("聊天记录将全部删除（已入账的账单不受影响），AI 也会忘掉之前的上下文。"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("取消")),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("清空"),
          ),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _messages.clear();
        _addWelcome();
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _confirmDraft(ChatMessage msg, int index) async {
    final draft = msg.drafts[index];
    try {
      await Api.createTransaction(
        type: draft.type,
        amount: draft.amount,
        categoryName: draft.categoryName,
        date: draft.date,
        note: draft.note,
        source: "ai",
      );
      setState(() => msg.savedIndexes.add(index));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("入账失败：$e")));
      }
    }
  }

  Future<void> _editDraft(ChatMessage msg, int index) async {
    final draft = msg.drafts[index];
    final result = await showTxEditSheet(
      context,
      type: draft.type,
      amount: draft.amount,
      categoryName: draft.categoryName,
      date: draft.date,
      note: draft.note,
    );
    if (result == null) return;
    setState(() {
      draft.type = result["type"] as String;
      draft.amount = result["amount"] as double;
      draft.categoryName = result["category_name"] as String;
      draft.date = result["date"] as DateTime;
      draft.note = result["note"] as String;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AI 记账"),
        actions: [
          IconButton(
            tooltip: "清空对话",
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clearChat,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) {
                  return const Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  );
                }
                return GestureDetector(
                  onLongPress: () => _deleteMessage(i),
                  child: _bubble(_messages[i]),
                );
              },
            ),
          ),
          if (_messages.length <= 2) _hintChips(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      onSubmitted: (_) => _send(),
                      enabled: !_recording, // 录音时锁定键盘输入
                      textInputAction: TextInputAction.send,
                      decoration: InputDecoration(
                        hintText: _recording
                            ? (_slideCancel
                                ? "▲ 松开手指，取消这次录音"
                                : "● 录音中 $_recordSeconds 秒，松手识别（上滑取消）")
                            : (_transcribing ? "识别中…" : "说说你花了什么钱…"),
                        hintStyle: _recording && _slideCancel
                            ? const TextStyle(color: Colors.red)
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 麦克风（微信式）：长按说话、松手识别、上滑取消；点按给提示
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onLongPressStart: (_) => _startRecording(),
                    onLongPressMoveUpdate: (d) {
                      // 手指上滑离开按钮约 70px → 进入取消模式，滑回来恢复
                      final c = d.localPosition.dy < -70;
                      if (c != _slideCancel && mounted) {
                        setState(() => _slideCancel = c);
                      }
                    },
                    onLongPressEnd: (_) => _finishRecording(cancel: _slideCancel),
                    onLongPressCancel: () => _finishRecording(cancel: true),
                    onTap: () => _toast("长按麦克风说话，松手识别，上滑取消"),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: _recording
                          ? (_slideCancel ? Colors.red.shade800 : Colors.red)
                          : Colors.grey.shade200,
                      child: _transcribing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _recording ? Icons.stop : Icons.mic_none,
                              color: _recording ? Colors.white : Colors.grey.shade700,
                              size: 22,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: (_sending || _recording || _transcribing) ? null : () => _send(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hintChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _hints.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(_hints[i], style: const TextStyle(fontSize: 12)),
          onPressed: () => _send(_hints[i]),
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage msg) {
    return Align(
      alignment: msg.fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.82,
        ),
        decoration: BoxDecoration(
          color: msg.fromUser ? const Color(0xFF2E9E6B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: msg.fromUser
            ? Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 15))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (msg.text.isNotEmpty)
                    Text(msg.text, style: const TextStyle(fontSize: 15, height: 1.4)),
                  for (final i in Iterable.generate(msg.drafts.length))
                    _draftCard(msg, i),
                ],
              ),
      ),
    );
  }

  Widget _draftCard(ChatMessage msg, int index) {
    final d = msg.drafts[index];
    final saved = msg.savedIndexes.contains(index);
    final isExpense = d.type == "expense";
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: saved ? const Color(0xFF2E9E6B) : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isExpense ? Colors.orange.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isExpense ? "支出" : "收入",
                  style: TextStyle(
                    fontSize: 11,
                    color: isExpense ? Colors.orange.shade800 : Colors.green.shade800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                "¥ ${d.amount.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isExpense ? const Color(0xFF222222) : const Color(0xFF2E9E6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${d.categoryName} · ${DateFormat("MM月dd日").format(d.date)}${d.note.isEmpty ? "" : " · ${d.note}"}",
            style: const TextStyle(fontSize: 13, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (!saved) ...[
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _editDraft(msg, index),
                  child: const Text("修改", style: TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 34),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => _confirmDraft(msg, index),
                  child: const Text("确认入账", style: TextStyle(fontSize: 13)),
                ),
              ] else
                const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF2E9E6B), size: 18),
                    SizedBox(width: 4),
                    Text("已入账", style: TextStyle(color: Color(0xFF2E9E6B), fontSize: 13)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}
