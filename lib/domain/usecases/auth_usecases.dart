import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class AuthUseCases {
  final AuthRepository repository;

  AuthUseCases(this.repository);

  Future<UserEntity?> getCurrentUser() {
    return repository.getCurrentUser();
  }

  Future<UserEntity?> login(String email, String password) {
    return repository.login(email, password);
  }

  Future<UserEntity?> register({
    required String email,
    required String password,
    required String name,
    required double height,
    required double weight,
    required int age,
  }) {
    return repository.register(
      email: email,
      password: password,
      name: name,
      height: height,
      weight: weight,
      age: age,
    );
  }

  Future<void> resetPassword(String email) {
    return repository.resetPassword(email);
  }

  Future<void> logout() {
    return repository.logout();
  }
}
