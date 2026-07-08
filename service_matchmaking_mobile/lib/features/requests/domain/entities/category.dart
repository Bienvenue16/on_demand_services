import 'package:equatable/equatable.dart';

class Category extends Equatable {
  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
  });

  final String id;
  final String name;
  final String slug;
  final String? icon;

  /// Nom precede de l'emoji de la categorie (ex: "Electricite" -> "⚡ Electricite").
  String get label {
    final trimmedIcon = icon?.trim();
    if (trimmedIcon == null || trimmedIcon.isEmpty) {
      return name;
    }
    return '$trimmedIcon $name';
  }

  @override
  List<Object?> get props => [id, name, slug, icon];
}
