import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/suggestion.dart';
import '../../services/api_client.dart';

/// 건의사항: 익명으로 등록되며 모두가 확인할 수 있다.
class SuggestionScreen extends StatefulWidget {
  const SuggestionScreen({super.key});

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  List<Suggestion> _suggestions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await context.read<ApiClient>().get('/suggestions');
      final list = (res['suggestions'] as List<dynamic>)
          .map((e) => Suggestion.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) {
        setState(() {
          _suggestions = list;
          _loading = false;
        });
      }
    } on ApiException catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add() async {
    final api = context.read<ApiClient>();
    final controller = TextEditingController();
    final content = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('건의사항 (익명)'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: '건의하고 싶은 내용을 적어주세요.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('등록')),
        ],
      ),
    );
    if (content == null || content.trim().isEmpty) return;
    try {
      await api.post('/suggestions', {'content': content.trim()});
      _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('건의사항')),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _suggestions.isEmpty
                  ? ListView(children: const [Padding(padding: EdgeInsets.all(32), child: Text('등록된 건의사항이 없습니다.'))])
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _suggestions.length,
                      itemBuilder: (context, i) {
                        final s = _suggestions[i];
                        return Card(
                          child: ListTile(
                            title: Text(s.content),
                            subtitle: Text(DateFormat('yyyy/M/d HH:mm').format(DateTime.parse(s.createdAt).toLocal())),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
