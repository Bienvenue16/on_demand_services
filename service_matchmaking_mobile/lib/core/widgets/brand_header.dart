import 'package:flutter/material.dart';

import '../../app/app_semantic_colors.dart';

/// En-tete "hero" de marque : degrade indigo en clair, fond sombre uni avec
/// mot d'accent dore en sombre. Reserve aux ecrans principaux (Demandes,
/// Offres, Messages, Notifications) ; les sous-ecrans utilisent [GradientHeader].
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.title,
    this.accentSuffix = '',
    this.subtitle,
    this.onBack,
    this.trailing,
    this.child,
  });

  final String title;

  /// Portion finale du titre mise en accent dore en mode sombre (doit etre
  /// un suffixe de [title]). Laisser vide pour un titre uniforme.
  final String accentSuffix;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Contenu additionnel sous le sous-titre (ex: barre de recherche, onglets).
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final semantic = context.semanticColors;
    final iconColor = isDark ? theme.colorScheme.onSurface : Colors.white;

    final hasAccent = isDark && accentSuffix.isNotEmpty && title.endsWith(accentSuffix);
    final Widget titleWidget = hasAccent
        ? RichText(
            text: TextSpan(
              style: theme.textTheme.headlineSmall,
              children: [
                TextSpan(
                  text: title.substring(0, title.length - accentSuffix.length),
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                TextSpan(
                  text: accentSuffix,
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              ],
            ),
          )
        : Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: isDark ? theme.colorScheme.onSurface : Colors.white,
            ),
          );

    final subtitleColor =
        isDark ? theme.colorScheme.onSurfaceVariant : Colors.white.withValues(alpha: 0.62);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onBack != null)
                IconButton(
                  onPressed: onBack,
                  icon: Icon(Icons.arrow_back, color: iconColor),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              if (onBack != null) const SizedBox(width: 4),
              Expanded(child: titleWidget),
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: TextStyle(color: subtitleColor, fontSize: 12.5)),
          ],
          if (child != null) ...[
            const SizedBox(height: 14),
            child!,
          ],
        ],
      ),
    );

    if (!isDark && semantic.heroGradient.isNotEmpty) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: semantic.heroGradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: content,
      );
    }

    return content;
  }
}
