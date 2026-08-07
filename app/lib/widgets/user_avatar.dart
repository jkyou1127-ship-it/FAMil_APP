import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_client.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  final bool? online;
  final double radius;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.name,
    this.online,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    final baseUrl = context.watch<ApiClient>().baseUrl;
    final initial = name.isNotEmpty ? name.substring(0, 1) : '?';

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundImage: photoUrl != null ? NetworkImage('$baseUrl$photoUrl') : null,
      child: photoUrl == null ? Text(initial) : null,
    );

    if (online == null) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -1,
          bottom: -1,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: online! ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
              border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
