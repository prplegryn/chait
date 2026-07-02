import 'package:flutter_test/flutter_test.dart';

import 'package:chait/app_store.dart';
import 'package:chait/models.dart';
import 'package:chait/ui/chait_app.dart';

void main() {
  testWidgets('starts with the chat shell', (tester) async {
    final store = AppStore();
    store.assistants.addAll(defaultAssistants());
    store.currentAssistantId = store.assistants.first.id;
    store.sessions.add(
      ChatSession(
        id: 'test-session',
        assistantId: store.currentAssistantId,
        title: '新对话',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        messages: [],
      ),
    );
    store.currentSessionId = 'test-session';
    store.isReady = true;

    await tester.pumpWidget(ChaitApp(store: store));
    await tester.pumpAndSettle();

    expect(find.text('写作助手'), findsWidgets);
    expect(find.text('问点什么…'), findsOneWidget);
  });
}
