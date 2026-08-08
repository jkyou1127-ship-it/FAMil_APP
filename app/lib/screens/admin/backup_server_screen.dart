import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/backup_snapshot.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../services/local_server_controller.dart';

/// PC 서버가 꺼졌을 때 이 기기를 같은 Wi-Fi 안에서만 쓰는 임시 백업 서버로
/// 켤 수 있게 해주는 화면. 관리자가 그 자리에 없을 수도 있으니 로그인한
/// 가족 구성원 누구나 쓸 수 있다. 자동으로 전환되지 않고, 사용자가 상황을
/// 직접 확인하고 버튼을 눌러야 동작한다.
class BackupServerScreen extends StatefulWidget {
  const BackupServerScreen({super.key});

  @override
  State<BackupServerScreen> createState() => _BackupServerScreenState();
}

class _BackupServerScreenState extends State<BackupServerScreen> {
  bool _busy = false;
  String? _localAddress;

  @override
  void initState() {
    super.initState();
    context.read<LocalServerController>().loadSavedSnapshotMeta();
  }

  Future<String?> _resolveLocalAddress(int port) async {
    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('169.254')) {
            return 'http://${addr.address}:$port';
          }
        }
      }
    } catch (_) {
      // 주소를 못 가져와도 서버 자체는 계속 동작한다 — 자동 감지로 여전히 찾을 수 있다.
    }
    return null;
  }

  Future<void> _downloadSnapshot() async {
    setState(() => _busy = true);
    try {
      final api = context.read<ApiClient>();
      await context.read<LocalServerController>().downloadSnapshot(api);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('스냅샷을 저장했습니다.')));
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('스냅샷 저장 실패: ${e.message}')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('스냅샷 저장 실패: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _startBackupServer() async {
    final controller = context.read<LocalServerController>();
    if (!controller.hasSnapshot) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('스냅샷이 없습니다'),
          content: const Text('아직 저장된 스냅샷이 없어 빈 상태로 시작됩니다 (기존 계정으로 로그인할 수 없습니다). 그래도 시작할까요?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
            FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('시작')),
          ],
        ),
      );
      if (proceed != true) return;
    }
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    setState(() => _busy = true);
    try {
      await controller.start(primaryBaseUrl: auth.api.baseUrl, primaryToken: auth.token);
      if (controller.error != null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('시작 실패: ${controller.error}')));
      } else {
        final address = await _resolveLocalAddress(controller.port ?? 4000);
        if (mounted) setState(() => _localAddress = address);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _mergeAndStop() async {
    final controller = context.read<LocalServerController>();
    setState(() => _busy = true);
    try {
      final result = await controller.mergeBackToPrimary();
      await controller.stop();
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('복귀 완료'),
            content: Text(_mergeSummary(result)),
            actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('확인'))],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('주 서버로 병합하지 못했습니다: $e\n(백업 서버는 계속 실행 중입니다)')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stopWithoutMerge() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('병합 없이 중지'),
        content: const Text('백업 서버로 동작하는 동안 생긴 새 데이터를 주 서버로 보내지 않고 중지합니다. 계속할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('중지')),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final controller = context.read<LocalServerController>();
    setState(() => _busy = true);
    try {
      await controller.stop();
      if (mounted) setState(() => _localAddress = null);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _mergeSummary(MergeResult result) {
    final parts = result.imported.entries.where((e) => e.value > 0).map((e) => '${_labelFor(e.key)} ${e.value}건').toList();
    final summary = parts.isEmpty ? '새로 병합된 데이터가 없습니다.' : '${parts.join(', ')}이(가) 주 서버로 반영되었습니다.';
    return result.skipped > 0 ? '$summary\n(건너뛴 항목 ${result.skipped}건)' : summary;
  }

  String _labelFor(String key) => switch (key) {
        'messages' => '메시지',
        'chatRoomMessages' => '단톡방 메시지',
        'todos' => '할 일',
        'schedules' => '일정',
        'suggestions' => '건의사항',
        _ => key,
      };

  String _snapshotStatusText(SnapshotMeta? meta) {
    if (meta == null) return '저장된 스냅샷이 없습니다.';
    final ago = DateTime.now().difference(meta.takenAt);
    final agoText = ago.inMinutes < 1
        ? '방금 전'
        : ago.inMinutes < 60
        ? '${ago.inMinutes}분 전'
        : ago.inHours < 24
        ? '${ago.inHours}시간 전'
        : '${ago.inDays}일 전';
    return '마지막 스냅샷: $agoText';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LocalServerController>();
    final running = controller.status == LocalServerStatus.running;

    return Scaffold(
      appBar: AppBar(title: const Text('백업 서버 (임시)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PC 서버가 꺼졌을 때 쓰는 임시 기능', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    '이 기기(폰)를 같은 Wi-Fi 안에서만 접속 가능한 임시 서버로 켤 수 있습니다. '
                    '인터넷 전체에 노출되지 않으며, 자동으로 전환되지 않고 아래 버튼을 직접 눌러야 동작합니다.\n\n'
                    '사용 순서: ① PC 서버가 켜져 있을 때 "지금 스냅샷 저장"으로 최신 데이터를 미리 받아둡니다. '
                    '② PC가 꺼지면 "백업 서버로 시작"을 누릅니다. 가족들은 로그인 화면의 "같은 Wi-Fi에서 자동 감지"로 '
                    '이 기기를 찾아 기존 계정으로 다시 로그인하면 됩니다. '
                    '③ PC가 다시 켜지면 "주 서버로 복귀"를 눌러 그동안 쌓인 메시지/할 일/일정/건의사항을 PC로 보낸 뒤 중지합니다.\n\n'
                    '주의: 백업 중에 새로 만든 계정이나 방/단톡방은 복귀 시 함께 옮겨지지 않습니다.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        running ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                        color: running ? Colors.green : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        running ? '백업 서버 실행 중' : '중지됨',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  if (running && _localAddress != null) ...[
                    const SizedBox(height: 8),
                    Text('이 기기 주소: $_localAddress'),
                  ],
                  const SizedBox(height: 8),
                  Text(_snapshotStatusText(controller.snapshotMeta)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (!running) ...[
            FilledButton.icon(
              onPressed: _busy ? null : _downloadSnapshot,
              icon: const Icon(Icons.download_outlined),
              label: const Text('지금 스냅샷 저장'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _startBackupServer,
              icon: const Icon(Icons.play_arrow_outlined),
              label: const Text('백업 서버로 시작'),
            ),
          ] else ...[
            FilledButton.icon(
              onPressed: _busy ? null : _mergeAndStop,
              icon: const Icon(Icons.sync_outlined),
              label: const Text('주 서버로 복귀 (병합 후 중지)'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _stopWithoutMerge,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('병합 없이 중지'),
            ),
          ],
          if (_busy) const Padding(padding: EdgeInsets.only(top: 16), child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }
}
