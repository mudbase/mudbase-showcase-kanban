import 'package:flutter/material.dart';

import '../core/formatters.dart';

/// Small initials-based avatar chip for a card's assignee or an activity
/// row's actor - mirrors the reference web app's `<Avatar name={...} />`
/// (`web/src/components/ui/avatar.tsx`), which is also initials-based (there
/// is no `users` collection or profile picture anywhere in this data model).
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({required this.name, this.radius = 12, super.key});

  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      child: Text(initials(name), style: TextStyle(fontSize: radius * 0.85)),
    );
  }
}
