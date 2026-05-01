import 'package:dartz/dartz.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user.dart' as domain;
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/errors/failures.dart';

class AuthRepositoryImpl implements AuthRepository {
  final firebase_auth.FirebaseAuth _firebaseAuth;
  final FirebaseFirestore _firestore;

  AuthRepositoryImpl({
    firebase_auth.FirebaseAuth? firebaseAuth,
    FirebaseFirestore? firestore,
  }) : _firebaseAuth = firebaseAuth ?? firebase_auth.FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<Either<Failure, domain.User>> login(
    String email,
    String password,
  ) async {
    try {
      // Validar dominio institucional
      if (!_isInstitutionalEmail(email)) {
        return const Left(
          AuthFailure(
            'Solo se permiten correos institucionales @cuci.udg.mx / @alumnos.udg.mx / @academicos.udg.mx',
          ),
        );
      }

      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return const Left(AuthFailure('Error al iniciar sesión'));
      }

      final user = domain.User(
        uid: credential.user!.uid,
        email: credential.user!.email!,
        displayName: credential.user!.displayName ?? 'Usuario',
        emailVerified: credential.user!.emailVerified,
        photoURL: credential.user!.photoURL,
      );

      return Right(user);
    } on firebase_auth.FirebaseAuthException catch (e) {
      print("FIREBASE ERROR CODE: ${e.code}"); ////eliminar luego
      return Left(AuthFailure(_getAuthErrorMessage(e.code)));
    } catch (e) {
      return Left(AuthFailure('Error inesperado: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, domain.User>> register(
    String email,
    String password,
    String displayName,
  ) async {
    try {
      // Validar dominio institucional
      if (!_isInstitutionalEmail(email)) {
        return const Left(
          AuthFailure(
            'Solo se permiten correos institucionales @cuci.udg.mx / @alumnos.udg.mx / @academicos.udg.mx',
          ),
        );
      }

      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user == null) {
        return const Left(AuthFailure('Error al crear cuenta'));
      }

      // Actualizar displayName
      await credential.user!.updateDisplayName(displayName);

      // Crear documento en Firestore (será completado por Cloud Function)
      await _firestore.collection('users').doc(credential.user!.uid).set({
        'email': email,
        'displayName': displayName,
        'emailVerified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _firebaseAuth.signOut();
      await Future.delayed(const Duration(milliseconds: 300));

      return const Left(
        AuthFailure('Cuenta creada correctamente. Ahora inicia sesión'),
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      return Left(AuthFailure(_getAuthErrorMessage(e.code)));
    } catch (e) {
      return Left(AuthFailure('Error inesperado: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      await _firebaseAuth.signOut();
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure('Error al cerrar sesión'));
    }
  }

  @override
  Future<Either<Failure, domain.User?>> getCurrentUser() async {
    try {
      await _firebaseAuth.currentUser?.reload();
      final firebaseUser = _firebaseAuth.currentUser;

      if (firebaseUser == null) {
        return const Right(null);
      }

      final user = domain.User(
        uid: firebaseUser.uid,
        email: firebaseUser.email!,
        displayName: firebaseUser.displayName ?? 'Usuario',
        emailVerified: firebaseUser.emailVerified,
        photoURL: firebaseUser.photoURL,
      );

      return Right(user);
    } catch (e) {
      return Left(AuthFailure('Error al obtener usuario actual'));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        return const Left(AuthFailure('No hay usuario autenticado'));
      }

      await user.sendEmailVerification();
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure('Error al enviar email de verificación'));
    }
  }

  // Helpers privados

  bool _isInstitutionalEmail(String email) {
    return email.endsWith('@cuci.udg.mx') ||
        email.endsWith('@alumnos.udg.mx') ||
        email.endsWith('@academicos.udg.mx');
  }

  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No existe una cuenta con este correo';
      case 'wrong-password':
        return 'Contraseña incorrecta';
      case 'email-already-in-use':
        return 'Ya existe una cuenta con este correo';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'invalid-email':
        return 'Correo electrónico inválido';
      case 'too-many-requests':
        return 'Demasiados intentos. Intenta más tarde';
      default:
        return 'Error de autenticación: $code';
    }
  }
}
