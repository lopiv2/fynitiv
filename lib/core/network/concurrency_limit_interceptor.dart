import 'package:dio/dio.dart';

/// Interceptor que limita el número de peticiones HTTP concurrentes.
///
/// El servidor Jellyfin actualiza la actividad del usuario en cada petición
/// autenticada; lanzar muchas a la vez satura su base de datos (SQLite es de
/// escritura única) y produce "database table is locked". Con un límite de
/// concurrencia bajo se evita saturarlo.
class ConcurrencyLimitInterceptor extends QueuedInterceptor {
  ConcurrencyLimitInterceptor({this.maxConcurrent = 3});

  final int maxConcurrent;

  int _active = 0;
  final List<_Pending> _pending = [];

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_active < maxConcurrent) {
      _active++;
      handler.next(options);
    } else {
      _pending.add(_Pending(options, handler));
    }
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _release();
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _release();
    handler.next(err);
  }

  void _release() {
    _active--;
    while (_active < maxConcurrent && _pending.isNotEmpty) {
      final p = _pending.removeAt(0);
      _active++;
      p.handler.next(p.options);
    }
  }
}

class _Pending {
  _Pending(this.options, this.handler);

  final RequestOptions options;
  final RequestInterceptorHandler handler;
}
