/// Late-bound bridge for the FSM's `performRealSubmit`. The FSM has to be
/// constructed before the flow controller (which needs the FSM), yet the
/// real submit needs the controller's WebView access — so the FSM gets
/// [run], and the controller installs [action] once it exists.
class SubmitHook {
  Future<void> Function()? action;

  Future<void> run() {
    final a = action;
    if (a == null) {
      throw StateError('No submit action is installed.');
    }
    return a();
  }
}
