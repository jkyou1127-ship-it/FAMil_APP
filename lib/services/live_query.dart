import 'dart:async';

import 'socket_service.dart';

/// REST로 최초 데이터를 가져오고, 지정한 소켓 이벤트가 올 때마다 다시 불러와
/// 스트림에 흘려보낸다. Firestore의 실시간 snapshots()와 비슷한 사용감을 준다.
Stream<T> watchLive<T>({
  required Future<T> Function() fetch,
  String? event,
}) {
  late StreamController<T> controller;
  StreamSubscription<void>? sub;

  Future<void> refresh() async {
    try {
      final data = await fetch();
      if (!controller.isClosed) controller.add(data);
    } catch (e, st) {
      if (!controller.isClosed) controller.addError(e, st);
    }
  }

  controller = StreamController<T>.broadcast(
    onListen: () {
      refresh();
      if (event != null) {
        sub = SocketService.instance.events(event).listen((_) => refresh());
      }
    },
    onCancel: () {
      sub?.cancel();
    },
  );
  return controller.stream;
}
