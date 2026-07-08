import 'package:flutter/material.dart';

/// Jetons de design qui n'ont pas d'equivalent direct dans le [ColorScheme]
/// Material 3 (badge d'urgence, texte meta, degrade des vignettes photo...).
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.urgentBackground,
    required this.urgentForeground,
    required this.urgentBorder,
    required this.metaText,
    required this.imageTagBackground,
    required this.imageTagForeground,
    required this.cardImageGradient,
    required this.heroGradient,
  });

  final Color urgentBackground;
  final Color urgentForeground;
  final Color? urgentBorder;
  final Color metaText;
  final Color imageTagBackground;
  final Color imageTagForeground;
  final List<Color> cardImageGradient;

  /// Degrade de l'en-tete hero de l'accueil. Vide en mode sombre (fond uni).
  final List<Color> heroGradient;

  static const light = AppSemanticColors(
    urgentBackground: Color(0xFFFFF1DC),
    urgentForeground: Color(0xFFB4680A),
    urgentBorder: null,
    metaText: Color(0xFF8A90A8),
    imageTagBackground: Color(0x8C141932),
    imageTagForeground: Colors.white,
    cardImageGradient: [Color(0xFF33406E), Color(0xFF5A6DB8)],
    heroGradient: [Color(0xFF202B5C), Color(0xFF2C3B7A), Color(0xFF35479A)],
  );

  static const dark = AppSemanticColors(
    urgentBackground: Color(0x24F2B441),
    urgentForeground: Color(0xFFF2B441),
    urgentBorder: Color(0x4DF2B441),
    metaText: Color(0xFF6F7684),
    imageTagBackground: Color(0x80000000),
    imageTagForeground: Color(0xFFF2B441),
    cardImageGradient: [Color(0xFF232A3A), Color(0xFF3D4A68)],
    heroGradient: [],
  );

  @override
  AppSemanticColors copyWith({
    Color? urgentBackground,
    Color? urgentForeground,
    Color? urgentBorder,
    Color? metaText,
    Color? imageTagBackground,
    Color? imageTagForeground,
    List<Color>? cardImageGradient,
    List<Color>? heroGradient,
  }) {
    return AppSemanticColors(
      urgentBackground: urgentBackground ?? this.urgentBackground,
      urgentForeground: urgentForeground ?? this.urgentForeground,
      urgentBorder: urgentBorder ?? this.urgentBorder,
      metaText: metaText ?? this.metaText,
      imageTagBackground: imageTagBackground ?? this.imageTagBackground,
      imageTagForeground: imageTagForeground ?? this.imageTagForeground,
      cardImageGradient: cardImageGradient ?? this.cardImageGradient,
      heroGradient: heroGradient ?? this.heroGradient,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      urgentBackground: Color.lerp(urgentBackground, other.urgentBackground, t)!,
      urgentForeground: Color.lerp(urgentForeground, other.urgentForeground, t)!,
      urgentBorder: Color.lerp(urgentBorder, other.urgentBorder, t),
      metaText: Color.lerp(metaText, other.metaText, t)!,
      imageTagBackground: Color.lerp(imageTagBackground, other.imageTagBackground, t)!,
      imageTagForeground: Color.lerp(imageTagForeground, other.imageTagForeground, t)!,
      cardImageGradient: cardImageGradient,
      heroGradient: heroGradient,
    );
  }
}

extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
