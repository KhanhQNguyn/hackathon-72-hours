import 'package:flutter_test/flutter_test.dart';

import 'package:job_access_assist/mocks/fake_pdf_reader_service.dart';
import 'package:job_access_assist/mocks/fake_webview_controller_service.dart';

void main() {
  test('milestone34 — fakes return canned content', () async {
    final web = FakeWebViewControllerService();
    final snapshot = await web.readDom();
    expect(snapshot.labeledFields, hasLength(4));
    expect(snapshot.searchCandidates, hasLength(1));
    expect(snapshot.submitCandidates, hasLength(1));
    expect((await web.fillField('n-name', 'A')).success, isTrue);

    final pdf = FakePdfReaderService();
    expect(await pdf.extractTextWithOcrFallback('x.pdf'), isNotEmpty);
  });
}
