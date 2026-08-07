import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_provider.dart';
import '../../widgets/user_avatar.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: context.read<AuthProvider>().currentUser?.displayName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final api = context.read<ApiClient>();
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, maxWidth: 1024);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    try {
      final res = await api.uploadPhoto('/users/me/photo', bytes, file.name);
      final user = AppUser.fromJson(Map<String, dynamic>.from(res['user'] as Map));
      if (mounted) context.read<AuthProvider>().applyUserUpdate(user);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _saveName() async {
    setState(() => _saving = true);
    try {
      final res = await context.read<ApiClient>().patch('/users/me', {'displayName': _nameController.text.trim()});
      final user = AppUser.fromJson(Map<String, dynamic>.from(res['user'] as Map));
      if (mounted) context.read<AuthProvider>().applyUserUpdate(user);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장되었습니다.')));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('내 프로필')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickPhoto,
              child: Stack(
                children: [
                  UserAvatar(photoUrl: me?.profilePhoto, name: me?.displayName ?? '', radius: 48),
                  const Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(radius: 14, child: Icon(Icons.edit, size: 14)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _saveName,
            child: _saving
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('저장'),
          ),
        ],
      ),
    );
  }
}
