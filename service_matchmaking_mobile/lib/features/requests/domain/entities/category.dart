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

  @override
  List<Object?> get props => [id, name, slug, icon];
}
