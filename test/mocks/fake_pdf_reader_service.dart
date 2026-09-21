import 'package:job_access_assist/services/pdf_reader_service.dart';

/// Canned-content stand-in for `PdfReaderService` (milestone34).
///
/// `noSuchMethod` keeps this compiling if other workstreams add members
/// to the real service; calling an un-faked one throws.
class FakePdfReaderService implements PdfReaderService {
  static const String cannedFormText =
      'APPLICATION FORM\n\n'
      'Position: Senior Flutter Developer\n\n'
      'Please complete all sections. Section 1 - Personal details: full '
      'name, phone number, email address.\n\n'
      'Section 2 - Attachments: attach your current CV in PDF format.\n\n'
      'Section 3 - Declaration: I confirm the information above is '
      'accurate.';

  // MERGE: milestone20 adds this to the real `PdfReaderService` as the
  // single entry point callers use. Once it exists, add `@override` here.
  Future<String> extractTextWithOcrFallback(String pdfPath) async =>
      cannedFormText;

  @override
  Future<String> extractText(String pdfPath) async => cannedFormText;

  @override
  Future<bool> hasTextLayer(String pdfPath) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(
    'FakePdfReaderService: ${invocation.memberName} not faked yet',
  );
}
