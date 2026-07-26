/// Role strings must match the backend exactly — it stores them as free text
/// with no enum validation, so always use these constants, never literals.
class UserRole {
  UserRole._();

  static const String estateManager = 'estate_manager';
  static const String factoryManager = 'factory_manager';

  static String label(String role) {
    switch (role) {
      case factoryManager:
        return 'Factory Manager';
      case estateManager:
        return 'Estate Manager';
      default:
        return role;
    }
  }
}
