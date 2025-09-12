import 'package:flutter/foundation.dart';
import '../database/database_helper.dart';
import '../models/user_info.dart';

class UserInfoService {
  static final UserInfoService _instance = UserInfoService._internal();
  factory UserInfoService() => _instance;
  UserInfoService._internal();

  final DatabaseHelper _databaseHelper = DatabaseHelper();
  UserInfo? _currentUserInfo;

  // 현재 사용자 정보 (단일)
  UserInfo? get currentUserInfo => _currentUserInfo;

  // 사용자 정보 존재 여부
  bool get hasUserInfo => _currentUserInfo != null;

  // 앱 시작시 데이터 초기화
  Future<void> initialize() async {
    try {
      await loadUserInfo();
      _log(
          'UserInfoService 초기화 완료 - ${_currentUserInfo != null ? '정보 로드됨' : '정보 없음'}');
    } catch (e) {
      _log('UserInfoService 초기화 중 오류 발생: $e');
      _currentUserInfo = null; // 오류 발생시 null로 초기화
    }
  }

  // 사용자 정보 로드 (단일)
  Future<void> loadUserInfo() async {
    try {
      final userInfoList = await _databaseHelper.getAllUserInfo();

      if (userInfoList.isNotEmpty) {
        // 가장 최근 데이터를 현재 정보로 설정 (이미 updated_at DESC로 정렬됨)
        _currentUserInfo = userInfoList.first;
        _log('사용자 정보 로드 완료: ${_currentUserInfo.toString()}');
      } else {
        _currentUserInfo = null;
        _log('저장된 사용자 정보가 없습니다');
      }
    } catch (e) {
      _log('사용자 정보 로드 중 오류 발생: $e');
      _currentUserInfo = null;
    }
  }

  // 사용자 정보 저장 또는 업데이트 (단일)
  Future<bool> saveUserInfo(UserInfo userInfo) async {
    try {
      // 유효성 검사
      if (!userInfo.isValid()) {
        _log('유효하지 않은 사용자 정보: $userInfo');
        return false;
      }

      bool success = false;

      if (_currentUserInfo != null) {
        // 기존 정보가 있으면 업데이트
        final updatedUserInfo = _currentUserInfo!.copyWith(
          dong: userInfo.dong,
          ho: userInfo.ho,
          serialNumber: userInfo.serialNumber,
        );

        int affectedRows =
            await _databaseHelper.updateUserInfo(updatedUserInfo);
        success = affectedRows > 0;

        if (success) {
          _currentUserInfo =
              updatedUserInfo.copyWith(updatedAt: DateTime.now());
          _log('사용자 정보 업데이트 성공: ID ${_currentUserInfo!.id}');
        }
      } else {
        // 새로운 정보 저장 (기존 정보가 있다면 먼저 삭제)
        await _databaseHelper.deleteAllUserInfo();

        int id = await _databaseHelper.insertUserInfo(userInfo);
        success = id > 0;

        if (success) {
          _currentUserInfo = userInfo.copyWith(
            id: id,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          _log('사용자 정보 저장 성공: ID $id');
        }
      }

      return success;
    } catch (e) {
      _log('사용자 정보 저장 중 오류 발생: $e');
      return false;
    }
  }

  // 현재 사용자 정보 삭제
  Future<bool> deleteUserInfo() async {
    try {
      if (_currentUserInfo == null) {
        _log('삭제할 사용자 정보가 없습니다');
        return false;
      }

      int affectedRows =
          await _databaseHelper.deleteUserInfo(_currentUserInfo!.id!);

      if (affectedRows > 0) {
        _currentUserInfo = null;
        _log('사용자 정보 삭제 성공');
        return true;
      }

      return false;
    } catch (e) {
      _log('사용자 정보 삭제 중 오류 발생: $e');
      return false;
    }
  }

  // 모든 사용자 정보 삭제
  Future<bool> deleteAllUserInfo() async {
    try {
      int affectedRows = await _databaseHelper.deleteAllUserInfo();

      if (affectedRows >= 0) {
        _currentUserInfo = null;
        _log('모든 사용자 정보 삭제 완료');
        return true;
      }

      return false;
    } catch (e) {
      _log('모든 사용자 정보 삭제 중 오류 발생: $e');
      return false;
    }
  }

  // 데이터 새로고침 (데이터베이스에서 다시 로드)
  Future<void> refresh() async {
    await loadUserInfo();
  }

  // 디버그 로깅
  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[UserInfoService] $message');
    }
  }

  // 서비스 종료 (앱 종료시 호출)
  Future<void> dispose() async {
    try {
      await _databaseHelper.closeDatabase();
      _currentUserInfo = null;
      _log('UserInfoService 종료');
    } catch (e) {
      _log('UserInfoService 종료 중 오류 발생: $e');
    }
  }
}
