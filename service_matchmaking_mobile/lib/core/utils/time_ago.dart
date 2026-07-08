/// Formatte une date en temps relatif court (ex: "il y a 50 min"), sans
/// dependre des donnees de locale `intl` (evite les crashs si non initialisees).
String timeAgo(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) {
    return 'a l\'instant';
  }
  if (diff.inMinutes < 60) {
    return 'il y a ${diff.inMinutes} min';
  }
  if (diff.inHours < 24) {
    return 'il y a ${diff.inHours} h';
  }
  if (diff.inDays < 7) {
    return 'il y a ${diff.inDays} j';
  }

  final weeks = (diff.inDays / 7).floor();
  if (diff.inDays < 30) {
    return 'il y a $weeks sem.';
  }

  final months = (diff.inDays / 30).floor();
  if (diff.inDays < 365) {
    return 'il y a $months mois';
  }

  final years = (diff.inDays / 365).floor();
  return 'il y a $years an${years > 1 ? 's' : ''}';
}
