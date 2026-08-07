import 'package:audioplayers/audioplayers.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/alarm_sounds.dart';
import '../../models/alarm.dart';
import '../../services/alarm_scheduler.dart';
import '../../services/api_client.dart';

const _weekdayLabels = ['일', '월', '화', '수', '목', '금', '토'];

class AlarmEditScreen extends StatefulWidget {
  final Alarm? alarm;
  const AlarmEditScreen({super.key, this.alarm});

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  late TimeOfDay _time;
  late String _repeatType; // 'daily' | 'weekly' | 'date'
  late Set<int> _repeatDays;
  DateTime? _specificDate;
  late String _sound; // preset id, or 'custom:<path>'
  String? _customSoundPath;
  final _labelController = TextEditingController();
  bool _saving = false;
  final _previewPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    final a = widget.alarm;
    if (a != null) {
      final parts = a.time.split(':');
      _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      _repeatType = a.repeatType;
      _repeatDays = a.repeatDays.toSet();
      _specificDate = a.specificDate != null ? DateTime.tryParse(a.specificDate!) : null;
      _sound = a.sound;
      if (_sound.startsWith('custom:')) _customSoundPath = _sound.substring('custom:'.length);
      _labelController.text = a.label ?? '';
    } else {
      _time = TimeOfDay.now();
      _repeatType = 'daily';
      _repeatDays = {};
      _sound = kAlarmSounds.first.id;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _previewPlayer.dispose();
    super.dispose();
  }

  String get _timeString =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _specificDate ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _specificDate = picked);
  }

  Future<void> _pickCustomSound() async {
    const typeGroup = XTypeGroup(label: '오디오', extensions: ['mp3', 'wav', 'm4a', 'ogg', 'aac']);
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file != null) {
      setState(() {
        _customSoundPath = file.path;
        _sound = 'custom:${file.path}';
      });
    }
  }

  Future<void> _preview(String assetOrPath, {bool isCustom = false}) async {
    await _previewPlayer.stop();
    if (isCustom) {
      await _previewPlayer.play(DeviceFileSource(assetOrPath));
    } else {
      await _previewPlayer.play(AssetSource(assetOrPath.replaceFirst('assets/', '')));
    }
  }

  Future<void> _save() async {
    if (_repeatType == 'weekly' && _repeatDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('요일을 하나 이상 선택해주세요.')));
      return;
    }
    if (_repeatType == 'date' && _specificDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('날짜를 선택해주세요.')));
      return;
    }
    setState(() => _saving = true);
    final body = {
      'label': _labelController.text.trim(),
      'time': _timeString,
      'repeatType': _repeatType,
      'repeatDays': _repeatDays.toList(),
      'specificDate': _specificDate == null
          ? null
          : '${_specificDate!.year.toString().padLeft(4, '0')}-${_specificDate!.month.toString().padLeft(2, '0')}-${_specificDate!.day.toString().padLeft(2, '0')}',
      'sound': _sound,
    };
    try {
      final api = context.read<ApiClient>();
      if (widget.alarm == null) {
        await api.post('/alarms', body);
      } else {
        await api.patch('/alarms/${widget.alarm!.id}', body);
      }
      if (mounted) context.read<AlarmScheduler>().refresh(api);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (widget.alarm == null) return;
    try {
      final api = context.read<ApiClient>();
      await api.delete('/alarms/${widget.alarm!.id}');
      if (mounted) context.read<AlarmScheduler>().refresh(api);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.alarm == null ? '알람 추가' : '알람 수정'),
        actions: [
          if (widget.alarm != null) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: OutlinedButton(
              onPressed: _pickTime,
              child: Text(_timeString, style: const TextStyle(fontSize: 40)),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(labelText: '알람 이름 (선택)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text('반복', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'daily', label: Text('매일')),
              ButtonSegment(value: 'weekly', label: Text('요일별')),
              ButtonSegment(value: 'date', label: Text('날짜 지정')),
            ],
            selected: {_repeatType},
            onSelectionChanged: (s) => setState(() => _repeatType = s.first),
          ),
          const SizedBox(height: 12),
          if (_repeatType == 'weekly')
            Wrap(
              spacing: 6,
              children: List.generate(7, (i) {
                final selected = _repeatDays.contains(i);
                return FilterChip(
                  label: Text(_weekdayLabels[i]),
                  selected: selected,
                  onSelected: (v) => setState(() {
                    if (v) {
                      _repeatDays.add(i);
                    } else {
                      _repeatDays.remove(i);
                    }
                  }),
                );
              }),
            ),
          if (_repeatType == 'date')
            OutlinedButton(
              onPressed: _pickDate,
              child: Text(_specificDate == null
                  ? '날짜 선택'
                  : '${_specificDate!.year}/${_specificDate!.month}/${_specificDate!.day}'),
            ),
          const SizedBox(height: 20),
          Text('알람 소리', style: Theme.of(context).textTheme.titleSmall),
          RadioGroup<String>(
            groupValue: _sound,
            onChanged: (v) {
              if (v == null) return;
              if (v == 'custom:') {
                _pickCustomSound();
                return;
              }
              setState(() => _sound = v);
            },
            child: Column(
              children: [
                ...kAlarmSounds.map((s) => RadioListTile<String>(
                      value: s.id,
                      title: Text(s.label),
                      secondary: IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => _preview(s.asset),
                      ),
                    )),
                RadioListTile<String>(
                  value: _customSoundPath != null ? 'custom:$_customSoundPath' : 'custom:',
                  title: Text(_customSoundPath != null ? '직접 추가한 소리' : '직접 넣기'),
                  subtitle:
                      _customSoundPath != null ? Text(_customSoundPath!, overflow: TextOverflow.ellipsis) : null,
                  secondary: IconButton(icon: const Icon(Icons.folder_open), onPressed: _pickCustomSound),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장'),
          ),
        ],
      ),
    );
  }
}
