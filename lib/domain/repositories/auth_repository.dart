import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity?> getCurrentUser();
  Future<UserEntity?> login(String email, String password);
  Future<UserEntity?> register({
    required String email,
    required String password,
    required String name,
    required double height,
    required double weight,
    required int age,
  });
  Future<void> resetPassword(String email);
  Future<void> logout();
}
