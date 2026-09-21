/// Filled-in form field values, keyed by field id — read aloud at
/// `FinalReview`, before the submit-confirmation checkpoint. See
/// spec.md §5, §6 "Confirmation Manager".
class ApplicationSummary {
  final Map<String, String> fieldValues;

  const ApplicationSummary(this.fieldValues);
}
