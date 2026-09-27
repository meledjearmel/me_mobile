import 'package:flutter/material.dart';

import '../../../shared/widgets/feedback.dart';

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Boîte de réception')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          ComingSoon(
            icon: Icons.mark_email_unread_outlined,
            title: 'Messages, collaborations et avis',
            description: 'Lecture, statuts et modération : prévu à l\'étape 3.',
          ),
        ],
      ),
    );
  }
}
