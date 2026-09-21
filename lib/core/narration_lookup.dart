import '../orchestration/application_flow_state.dart';
import 'language.dart';

/// Maps an FSM state to the on-screen status text (milestone26).
///
/// PLACEHOLDER WORDING — the final EN + VI narration script is
/// milestone 42's job; this file is only the plumbing. Deliberately an
/// `is`-chain with a fallback rather than an exhaustive `switch`, so
/// states added later don't break compilation.
String narrationFor(ApplicationFlowState state) {
  if (state is IdleState) return 'Press the button and say a command.';
  if (state is ListeningState) return 'Listening for your command...';
  if (state is ParsingIntentState) return 'Understanding your request...';
  if (state is LoadingTargetState) return 'Loading the page...';
  if (state is ReadingContentState) return 'Reading the content...';
  if (state is AwaitingUserActionState) {
    return 'Waiting for you to confirm the listing.';
  }
  if (state is FillingFormState) {
    return 'Filling in the form: ${state.currentFieldId}';
  }
  if (state is FinalReviewState) return 'Review your application.';
  if (state is EditingFieldState) return 'Editing: ${state.fieldId}';
  if (state is AwaitingSubmitConfirmationState) {
    return 'Say confirm to submit your application.';
  }
  if (state is DoneState) return 'Application submitted.';
  if (state is CaptchaPendingState) {
    return 'A CAPTCHA needs you. Solve it, then say continue.';
  }
  if (state is RetryingState) return 'That did not work, retrying...';
  if (state is ErrorState) return 'Something went wrong: ${state.message}';
  return 'Working...';
}

/// Spoken when STT confidence is below threshold (milestone29). Wording is
/// fixed by the milestone spec; kept here beside the other user-facing
/// strings so milestone 42 finds them in one place.
String repromptMessage(String languageCode) {
  return languageCode == AppLanguage.vi
      ? 'Xin lỗi, tôi chưa nghe rõ, bạn nói lại được không?'
      : "Sorry, I didn't catch that, could you repeat?";
}

/// Spoken when the recognizer can't be used at all.
String speechUnavailableMessage(String languageCode) {
  return languageCode == AppLanguage.vi
      ? 'Không thể sử dụng nhận dạng giọng nói. Hãy kiểm tra quyền micro.'
      : 'Speech recognition is unavailable. Please check the microphone permission.';
}
