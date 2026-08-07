import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/alarm.dart';
import '../../services/alarm_repository.dart';
import '../../services/kst_time.dart';
import '../../services/sound_library.dart';

const _weekdayLabels = {1: '월', 2: '화', 3: '수', 4: '목', 5: '금', 6: '토', 7: '일'};

/// 알람 추가/수정 화면.
class AlarmEditScreen extends StatefulWidget {
  const AlarmEditScreen({super.key, required this.uid, this.existing});

  final String uid;
  final Alarm? existing;

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  final _repo = AlarmRepository();
  late TimeOfDay _time;
  late TextEditingController _labelController;
  late AlarmRepeat _repeat;
  late Set<int> _weekdays;
  late String _soundId;
  String? _customSoundPath;
  DateTime _onceDate = KstTime.now();

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _time = TimeOfDay(hour: a?.hour ?? 7, minute: a?.minute ?? 0);
    _labelController = TextEditingController(text: a?.label ?? '알람');
    _repeat = a?.repeat ?? AlarmRepeat.daily;
    _weekdays = {...(a?.weekdays ?? {})};
    _soundId = a?.soundId ?? SoundLibrary.alarmSounds.first.id;
    _customSoundPath = a?.customSoundPath;
    if (a?.onceDate != null) {
      final parts = a!.onceDate!.split('/');
      if (parts.length == 3) {
        _onceDate = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomSound() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.path != null) {
      setState(() => _customSoundPath = result.files.single.path);
    }
  }

  Future<void> _save() async {
    if (_repeat == AlarmRepeat.weekly && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('요일을 하나 이상 선택하세요.')),
      );
      return;
    }
    final alarm = Alarm(
      id: widget.existing?.id ?? '',
      uid: widget.uid,
      label: _labelController.text.trim().isEmpty
          ? '알람'
          : _labelController.text.trim(),
      hour: _time.hour,
      minute: _time.minute,
      repeat: _repeat,
      weekdays: _repeat == AlarmRepeat.weekly ? _weekdays : {},
      onceDate:
          _repeat == AlarmRepeat.once ? KstTime.formatDate(_onceDate) : null,
      soundId: _soundId,
      customSoundPath: _customSoundPath,
      enabled: widget.existing?.enabled ?? true,
    );
    if (widget.existing == null) {
      await _repo.addAlarm(alarm);
    } else {
      await _repo.updateAlarm(alarm);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? '알람 추가' : '알람 수정'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.check)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: TextButton(
              onPressed: () async {
                final picked =
                    await showTimePicker(context: context, initialTime: _time);
                if (picked != null) setState(() => _time = picked);
              },
              child: Text(
                '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                style: Theme.of(context).textTheme.displayMedium,
              ),
            ),
          ),
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
                labelText: '알람 이름', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          Text('반복', style: Theme.of(context).textTheme.titleMedium),
          RadioListTile<AlarmRepeat>(
            title: const Text('매일 울리기'),
            value: AlarmRepeat.daily,
            groupValue: _repeat,
            onChanged: (v) => setState(() => _repeat = v!),
          ),
          RadioListTile<AlarmRepeat>(
            title: const Text('요일별로 울리기'),
            value: AlarmRepeat.weekly,
            groupValue: _repeat,
            onChanged: (v) => setState(() => _repeat = v!),
          ),
          if (_repeat == AlarmRepeat.weekly)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: _weekdayLabels.entries.map((e) {
                  final selected = _weekdays.contains(e.key);
                  return FilterChip(
                    label: Text(e.value),
                    selected: selected,
                    onSelected: (v) => setState(() {
                      if (v) {
                        _weekdays.add(e.key);
                      } else {
                        _weekdays.remove(e.key);
                      }
                    }),
                  );
                }).toList(),
              ),
            ),
          RadioListTile<AlarmRepeat>(
            title: const Text('날을 정해서 울리기'),
            value: AlarmRepeat.once,
            groupValue: _repeat,
            onChanged: (v) => setState(() => _repeat = v!),
          ),
          if (_repeat == AlarmRepeat.once)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListTile(
                title: Text('날짜: ${KstTime.formatDate(_onceDate)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _onceDate,
                    firstDate: DateTime(_onceDate.year - 1),
                    lastDate: DateTime(_onceDate.year + 2),
                  );
                  if (selected != null) {
                    setState(() => _onceDate = selected);
                  }
                },
              ),
            ),
          const SizedBox(height: 16),
          Text('알람음', style: Theme.of(context).textTheme.titleMedium),
          ...SoundLibrary.alarmSounds.map((s) => RadioListTile<String>(
                title: Text(s.label),
                value: s.id,
                groupValue: _customSoundPath == null ? _soundId : null,
                onChanged: (v) => setState(() {
                  _soundId = v!;
                  _customSoundPath = null;
                }),
              )),
          ListTile(
            title: Text(_customSoundPath == null
                ? '직접 파일 선택...'
                : '선택한 파일: ${_customSoundPath!.split('/').last}'),
            leading: Radio<bool>(
              value: true,
              groupValue: _customSoundPath != null,
              onChanged: (_) => _pickCustomSound(),
            ),
            onTap: _pickCustomSound,
          ),
        ],
      ),
    );
  }
}
