import 'package:flutter/foundation.dart';
import '../models/user_info.dart';
import '../database/database_helper.dart';
import '../services/preferences_service.dart';
import '../services/home_widget_service.dart';

/// 사용자 정보 상태 관리 Provider
class UserInfoProvider extends ChangeNotifier {
  final DatabaseHelper _databaseHelper;
  final PreferencesService _preferencesService;

  // 상태 변수들
  UserInfo? _currentUser;
  List<UserInfo> _allUsers = [];
  bool _isLoading = false;
  String? _error;

  // 생성자
  UserInfoProvider({
    DatabaseHelper? databaseHelper,
    PreferencesService? preferencesService,
  })  : _databaseHelper = databaseHelper ?? DatabaseHelper(),
        _preferencesService = preferencesService ?? PreferencesService();

  // Getters
  UserInfo? get currentUser => _currentUser;
  List<UserInfo> get allUsers => List.unmodifiable(_allUsers);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasUsers => _allUsers.isNotEmpty;
  bool get hasCurrentUser => _currentUser != null;

  /// 초기화 - 저장된 사용자 정보 로드
  Future<void> initialize() async {
    _setLoading(true);

    try {
      // 모든 사용자 정보 로드
      await _loadAllUsers();

      // 마지막 사용한 사용자 정보 로드
      await _loadLastUsedUser();

      _clearError();

      if (kDebugMode) {
        debugPrint(
            '[UserInfoProvider] 초기화 완료 - 사용자: ${_allUsers.length}명, 현재: ${_currentUser?.toString()}');
      }
    } catch (e) {
      _setError('사용자 정보 초기화 실패: $e');

      if (kDebugMode) {
        debugPrint('[UserInfoProvider] 초기화 오류: $e');
      }
    } finally {
      _setLoading(false);
    }
  }

  /// 모든 사용자 정보 로드
  Future<void> _loadAllUsers() async {
    final users = await _databaseHelper.getAllUserInfo();
    _allUsers = users;
    notifyListeners();
  }

  /// 마지막 사용한 사용자 정보 로드
  Future<void> _loadLastUsedUser() async {
    if (_allUsers.isEmpty) return;

    try {
      // SharedPreferences에서 마지막 사용자 ID 조회
      final lastUserId = _preferencesService.getInt('last_user_id');

      if (lastUserId != null) {
        final lastUser = _allUsers.firstWhere(
          (user) => user.id == lastUserId,
          orElse: () => _allUsers.first,
        );
        _setCurrentUser(lastUser);
      } else {
        // 저장된 정보가 없으면 첫 번째 사용자 사용
        _setCurrentUser(_allUsers.first);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UserInfoProvider] 마지막 사용자 로드 실패: $e');
      }
      // 오류 시 첫 번째 사용자 사용
      if (_allUsers.isNotEmpty) {
        _setCurrentUser(_allUsers.first);
      }
    }
  }

  /// 새 사용자 추가
  Future<bool> addUser({
    required String dong,
    required String ho,
    required String serialNumber,
  }) async {
    _setLoading(true);

    try {
      final newUserInfo = UserInfo(
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final id = await _databaseHelper.insertUserInfo(newUserInfo);

      if (id > 0) {
        final newUser = newUserInfo.copyWith(id: id);
        _allUsers.add(newUser);
        _setCurrentUser(newUser);
        await _saveLastUsedUser(newUser);

        _clearError();

        if (kDebugMode) {
          debugPrint('[UserInfoProvider] 새 사용자 추가 완료: $newUser');
        }

        return true;
      }

      return false;
    } catch (e) {
      _setError('사용자 추가 실패: $e');

      if (kDebugMode) {
        debugPrint('[UserInfoProvider] 사용자 추가 오류: $e');
      }

      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 사용자 정보 업데이트
  Future<bool> updateUser({
    required int id,
    required String dong,
    required String ho,
    required String serialNumber,
  }) async {
    _setLoading(true);

    try {
      final updatedUserInfo = UserInfo(
        id: id,
        dong: dong,
        ho: ho,
        serialNumber: serialNumber,
        createdAt: _allUsers.firstWhere((user) => user.id == id).createdAt,
        updatedAt: DateTime.now(),
      );

      final affectedRows =
          await _databaseHelper.updateUserInfo(updatedUserInfo);
      final success = affectedRows > 0;

      if (success) {
        // 로컬 리스트 업데이트
        final index = _allUsers.indexWhere((user) => user.id == id);
        if (index != -1) {
          _allUsers[index] = UserInfo(
            id: id,
            dong: dong,
            ho: ho,
            serialNumber: serialNumber,
            createdAt: _allUsers[index].createdAt,
            updatedAt: DateTime.now(),
          );

          // 현재 사용자가 업데이트된 경우
          if (_currentUser?.id == id) {
            _setCurrentUser(_allUsers[index]);
            // 업데이트된 사용자 정보를 SharedPreferences에 저장
            await _saveLastUsedUser(_allUsers[index]);
          }

          notifyListeners();
        }

        _clearError();

        if (kDebugMode) {
          debugPrint('[UserInfoProvider] 사용자 정보 업데이트 완료: $id');
        }

        return true;
      }

      return false;
    } catch (e) {
      _setError('사용자 정보 업데이트 실패: $e');

      if (kDebugMode) {
        debugPrint('[UserInfoProvider] 사용자 업데이트 오류: $e');
      }

      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 사용자 삭제
  Future<bool> deleteUser(int id) async {
    _setLoading(true);

    try {
      final affectedRows = await _databaseHelper.deleteUserInfo(id);
      final success = affectedRows > 0;

      if (success) {
        _allUsers.removeWhere((user) => user.id == id);

        // 삭제된 사용자가 현재 사용자인 경우
        if (_currentUser?.id == id) {
          if (_allUsers.isNotEmpty) {
            _setCurrentUser(_allUsers.first);
            await _saveLastUsedUser(_allUsers.first);
          } else {
            _setCurrentUser(null);
          }
        }

        notifyListeners();
        _clearError();

        if (kDebugMode) {
          debugPrint('[UserInfoProvider] 사용자 삭제 완료: $id');
        }

        return true;
      }

      return false;
    } catch (e) {
      _setError('사용자 삭제 실패: $e');

      if (kDebugMode) {
        debugPrint('[UserInfoProvider] 사용자 삭제 오류: $e');
      }

      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// 현재 사용자 변경
  Future<void> setCurrentUser(UserInfo user) async {
    _setCurrentUser(user);
    await _saveLastUsedUser(user);

    if (kDebugMode) {
      debugPrint('[UserInfoProvider] 현재 사용자 변경: $user');
    }
  }

  /// 마지막 사용자 정보 저장
  Future<void> _saveLastUsedUser(UserInfo user) async {
    try {
      await _preferencesService.setInt('last_user_id', user.id!);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[UserInfoProvider] 마지막 사용자 저장 실패: $e');
      }
    }
  }

  /// 현재 사용자 설정
  void _setCurrentUser(UserInfo? user) {
    if (_currentUser != user) {
      _currentUser = user;
      
      // 사용자 정보가 변경되면 위젯이 접근할 수 있도록 저장
      if (user != null) {
        HomeWidgetService.saveUserInfo(user.dong, user.ho, user.serialNumber);
      }
      
      notifyListeners();
    }
  }

  /// 로딩 상태 설정
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  /// 오류 상태 설정
  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  /// 오류 상태 초기화
  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  /// 상태 초기화
  void clearState() {
    _currentUser = null;
    _allUsers.clear();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// ID로 사용자 찾기
  UserInfo? findUserById(int id) {
    try {
      return _allUsers.firstWhere((user) => user.id == id);
    } catch (e) {
      return null;
    }
  }

  /// 동호수로 사용자 찾기
  List<UserInfo> findUsersByApartment(String dong, String ho) {
    return _allUsers
        .where((user) => user.dong == dong && user.ho == ho)
        .toList();
  }
}
