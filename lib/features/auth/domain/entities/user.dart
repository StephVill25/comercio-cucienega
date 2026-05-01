class User {
  final String uid;
  final String email;
  final String displayName;
  final bool emailVerified;
  final String? photoURL;

  const User({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.emailVerified,
    this.photoURL,
  });
}
