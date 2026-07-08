import 'package:flutter/material.dart';

/// Jetons de design qui n'ont pas d'equivalent direct dans le [ColorScheme]
/// Material 3 (badges de statut, texte meta, bulles de chat, degrades...).
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
    required this.success,
    required this.successSoft,
    required this.warn,
    required this.warnSoft,
    required this.danger,
    required this.dangerSoft,
    required this.bubbleOut,
    required this.bubbleOutForeground,
    required this.bubbleIn,
    required this.bubbleInForeground,
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

  /// Statuts semantiques (succes/attente/refus) : jamais la couleur de marque,
  /// pour que le sens reste lisible dans les deux themes.
  final Color success;
  final Color successSoft;
  final Color warn;
  final Color warnSoft;
  final Color danger;
  final Color dangerSoft;

  /// Bulles de messagerie.
  final Color bubbleOut;
  final Color bubbleOutForeground;
  final Color bubbleIn;
  final Color bubbleInForeground;

  static const light = AppSemanticColors(
    urgentBackground: Color(0xFFFFF1DC),
    urgentForeground: Color(0xFFB4680A),
    urgentBorder: null,
    metaText: Color(0xFF8A90A8),
    imageTagBackground: Color(0x8C141932),
    imageTagForeground: Colors.white,
    cardImageGradient: [Color(0xFF33406E), Color(0xFF5A6DB8)],
    heroGradient: [Color(0xFF202B5C), Color(0xFF2C3B7A), Color(0xFF35479A)],
    success: Color(0xFF1E7A50),
    successSoft: Color(0xFFE1F4EA),
    warn: Color(0xFFB4680A),
    warnSoft: Color(0xFFFFF1DC),
    danger: Color(0xFFB0393A),
    dangerSoft: Color(0xFFFBE7E7),
    bubbleOut: Color(0xFF202B5C),
    bubbleOutForeground: Colors.white,
    bubbleIn: Color(0xFFEEF1FA),
    bubbleInForeground: Color(0xFF1B2140),
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
    success: Color(0xFF3DBB84),
    successSoft: Color(0x223DBB84),
    warn: Color(0xFFF2B441),
    warnSoft: Color(0x24F2B441),
    danger: Color(0xFFE5695F),
    dangerSoft: Color(0x22E5695F),
    bubbleOut: Color(0xFFF2B441),
    bubbleOutForeground: Color(0xFF201804),
    bubbleIn: Color(0xFF242A36),
    bubbleInForeground: Color(0xFFE7E9EE),
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
    Color? success,
    Color? successSoft,
    Color? warn,
    Color? warnSoft,
    Color? danger,
    Color? dangerSoft,
    Color? bubbleOut,
    Color? bubbleOutForeground,
    Color? bubbleIn,
    Color? bubbleInForeground,
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
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      warn: warn ?? this.warn,
      warnSoft: warnSoft ?? this.warnSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      bubbleOut: bubbleOut ?? this.bubbleOut,
      bubbleOutForeground: bubbleOutForeground ?? this.bubbleOutForeground,
      bubbleIn: bubbleIn ?? this.bubbleIn,
      bubbleInForeground: bubbleInForeground ?? this.bubbleInForeground,
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
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      warnSoft: Color.lerp(warnSoft, other.warnSoft, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerSoft: Color.lerp(dangerSoft, other.dangerSoft, t)!,
      bubbleOut: Color.lerp(bubbleOut, other.bubbleOut, t)!,
      bubbleOutForeground: Color.lerp(bubbleOutForeground, other.bubbleOutForeground, t)!,
      bubbleIn: Color.lerp(bubbleIn, other.bubbleIn, t)!,
      bubbleInForeground: Color.lerp(bubbleInForeground, other.bubbleInForeground, t)!,
    );
  }
}

extension AppSemanticColorsX on BuildContext {
  AppSemanticColors get semanticColors =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;
}
