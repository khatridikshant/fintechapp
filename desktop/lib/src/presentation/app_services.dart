import '../application/build_trial_balance.dart';

/// What the presentation layer is allowed to reach.
///
/// Held in one place so the wiring is visible in a single file rather than
/// scattered through widgets. A use case that is absent here has no screen, and
/// its navigation entry says so.
///
/// This is the only thing the presentation layer is given. It is how the shell
/// stays free of database and repository knowledge.
class AppServices {
  const AppServices({this.trialBalance});

  /// The Trial Balance report. Null until the application assembles it.
  final TrialBalanceLoader? trialBalance;

  /// A copy with the Trial Balance report attached.
  AppServices withTrialBalance(TrialBalanceLoader loader) => AppServices(
        trialBalance: loader,
      );
}
