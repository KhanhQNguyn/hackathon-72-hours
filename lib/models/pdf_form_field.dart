/// One AcroForm field extracted from a real fillable-form PDF
/// (`PdfReaderService.extractFormFields`, milestone19). `type` is one of
/// `'text'`, `'checkbox'`, `'combobox'`, `'listbox'`, `'radio'`,
/// `'signature'`, or `'unknown'` for any Syncfusion field subtype not
/// otherwise handled.
class PdfFormField {
  final String name;
  final String type;
  final String? value;

  const PdfFormField({required this.name, required this.type, this.value});
}
