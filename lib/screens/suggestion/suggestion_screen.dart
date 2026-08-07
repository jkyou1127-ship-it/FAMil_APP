import 'package:flutter/material.dart';

import '../../models/suggestion.dart';
import '../../services/kst_time.dart';
import '../../services/suggestion_repository.dart';

/// 건의사항: 익명으로 등록하며, 모두가 볼 수 있다.
class SuggestionScreen extends StatefulWidget {
  const SuggestionScreen({super.key});

  @override
  State<SuggestionScreen> createState() => _SuggestionScreenState();
}

class _SuggestionScreenState extends State<SuggestionScreen> {
  final _repo = SuggestionRepository();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    await _repo.submit(text);
    _controller.clear();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('익명으로 건의사항이 등록되었습니다.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('건의사항은 익명으로 등록되며 모두에게 공개됩니다.',
                  style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                controller: _controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: '건의하고 싶은 내용을 입력하세요',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('익명으로 등록'),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<List<Suggestion>>(
            stream: _repo.watchAll(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return const Center(
                    child: Text('등록된 건의사항이 없습니다.',
                        style: TextStyle(color: Colors.grey)));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.mail_outline),
                      title: Text(item.text),
                      subtitle: Text(item.createdAt != null
                          ? KstTime.formatDateTime(
                              KstTime.toKst(item.createdAt!))
                          : ''),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
