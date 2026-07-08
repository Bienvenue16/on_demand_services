import 'package:flutter/material.dart';

/// En-tete degrade commun a tous les ecrans principaux (accueil, detail,
/// mes demandes, messages, notifications) pour une identite visuelle coherente.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}
