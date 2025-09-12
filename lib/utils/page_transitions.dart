import 'package:flutter/material.dart';

/// 페이지 전환 애니메이션 유틸리티
class PageTransitions {
  /// Slide 전환 (오른쪽에서 왼쪽으로)
  static Route<T> slideTransition<T extends Object?>(
    Widget child, {
    Duration duration = const Duration(milliseconds: 300),
    Offset beginOffset = const Offset(1.0, 0.0),
    Curve curve = Curves.easeInOut,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween(
          begin: beginOffset,
          end: Offset.zero,
        ).chain(CurveTween(curve: curve));

        final offsetAnimation = animation.drive(tween);

        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }

  /// Fade 전환
  static Route<T> fadeTransition<T extends Object?>(
    Widget child, {
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeInOut,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final fadeAnimation = animation.drive(
          CurveTween(curve: curve),
        );

        return FadeTransition(
          opacity: fadeAnimation,
          child: child,
        );
      },
    );
  }

  /// Scale 전환 (확대/축소)
  static Route<T> scaleTransition<T extends Object?>(
    Widget child, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    double beginScale = 0.8,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final scaleAnimation = animation.drive(
          Tween(begin: beginScale, end: 1.0).chain(
            CurveTween(curve: curve),
          ),
        );

        return ScaleTransition(
          scale: scaleAnimation,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  /// 커스텀 애니메이션 전환
  static Route<T> customTransition<T extends Object?>(
    Widget child, {
    Duration duration = const Duration(milliseconds: 300),
    required Widget Function(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) transitionBuilder,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: duration,
      reverseTransitionDuration: duration,
      transitionsBuilder: transitionBuilder,
    );
  }
}

/// Navigation 헬퍼 확장
extension NavigationHelper on BuildContext {
  /// Slide 전환으로 페이지 이동
  Future<T?> pushSlide<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
    Offset beginOffset = const Offset(1.0, 0.0),
    Curve curve = Curves.easeInOut,
  }) {
    return Navigator.of(this).push<T>(
      PageTransitions.slideTransition<T>(
        page,
        duration: duration,
        beginOffset: beginOffset,
        curve: curve,
      ),
    );
  }

  /// Fade 전환으로 페이지 이동
  Future<T?> pushFade<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 250),
    Curve curve = Curves.easeInOut,
  }) {
    return Navigator.of(this).push<T>(
      PageTransitions.fadeTransition<T>(
        page,
        duration: duration,
        curve: curve,
      ),
    );
  }

  /// Scale 전환으로 페이지 이동
  Future<T?> pushScale<T extends Object?>(
    Widget page, {
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.easeInOut,
    double beginScale = 0.8,
  }) {
    return Navigator.of(this).push<T>(
      PageTransitions.scaleTransition<T>(
        page,
        duration: duration,
        curve: curve,
        beginScale: beginScale,
      ),
    );
  }
}
