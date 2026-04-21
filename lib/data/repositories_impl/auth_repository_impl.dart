import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserEntity?> getCurrentUser() async {
    try {
      final user = await remoteDataSource.getCurrentUser();
      if (user != null) {
        final userData = await remoteDataSource.getUserData(user.uid);
        if (userData != null) {
          return UserEntity(
            id: user.uid,
            email: userData['email'] ?? '',
            name: userData['name'] ?? '',
            height: (userData['height'] ?? 0.0).toDouble(),
            weight: (userData['weight'] ?? 0.0).toDouble(),
            age: (userData['age'] ?? 25).toInt(),
            role: userData['role'] ?? 'member',
          );
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<UserEntity?> login(String email, String password) async {
    try {
      final credential = await remoteDataSource.login(email, password);
      final user = credential.user;
      
      if (user != null) {
        final userData = await remoteDataSource.getUserData(user.uid);
        if (userData != null) {
           return UserEntity(
            id: user.uid,
            email: userData['email'] ?? '',
            name: userData['name'] ?? '',
            height: (userData['height'] ?? 0.0).toDouble(),
            weight: (userData['weight'] ?? 0.0).toDouble(),
            age: (userData['age'] ?? 25).toInt(),
            role: userData['role'] ?? 'member',
          );
        } else {
           // Default if not exist in firestore
           return UserEntity(id: user.uid, email: user.email ?? '', name: 'Người dùng mới', height: 0, weight: 0, age: 25, role: 'member');
        }
      }
      return null;
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  @override
  Future<UserEntity?> register({
    required String email,
    required String password,
    required String name,
    required double height,
    required double weight,
    required int age,
  }) async {
    try {
      final credential = await remoteDataSource.register(email, password);
      final user = credential.user;
      
      if (user != null) {
        await remoteDataSource.saveUserData(
          uid: user.uid,
          email: email,
          name: name,
          height: height,
          weight: weight,
          age: age,
          role: 'member',
        );
        
        return UserEntity(
          id: user.uid,
          email: email,
          name: name,
          height: height,
          weight: weight,
          age: age,
          role: 'member',
        );
      }
      return null;
    } catch (e) {
      throw Exception('Registration failed: ${e.toString()}');
    }
  }

  @override
  Future<void> resetPassword(String email) async {
    await remoteDataSource.sendPasswordResetEmail(email);
  }

  @override
  Future<void> logout() async {
    await remoteDataSource.logout();
  }
}
