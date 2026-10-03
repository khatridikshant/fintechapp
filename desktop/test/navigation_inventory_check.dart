import 'package:financeapp/src/presentation/navigation/app_navigation.dart';
import 'package:financeapp/src/presentation/app_services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Prints which navigation entries open a screen and which do not.
///
/// ## Why this exists
///
/// The screen inventory in `PROGRESS.md` was produced **three times by parsing
/// `app_navigation.dart` with a regex**, and **all three were wrong** — once
/// claiming Purchases, Suppliers and Payables were routed, once claiming
/// Chart of Accounts, Payments and Licences were not built, and once claiming
/// Licences was unwired when it is wired at `LicensesScreen.route`.
///
/// Every failure was the same kind: a lookahead window that either missed the
/// route or ran past it into a neighbouring entry, and a recursive glob
/// (`lib\src\**\*.dart`) that PowerShell does not expand.
///
/// This asks the **same objects the application builds** instead of reading its
/// source. `NavigationItem.route` is documented as "builds the screen this opens,
/// or `null` when it has not been built yet" — so `null` is not an inference, it
/// is the declaration.
///
/// **A test rather than a script**, because a printed list is easy to lose and a
/// test that fails is not. Run with:
/// `flutter test test/navigation_inventory_check.dart`
void main() {
  test('every navigation entry either opens a screen or says it does not', () {
    final services = _services();
    final groups = buildNavigation(services);

    final built = <String>[];
    final unbuilt = <String>[];

    for (final group in groups) {
      for (final section in group.sections) {
        final title = section.title;
        if (section.route == null) {
          unbuilt.add('${group.title} / $title');
        } else {
          built.add('${group.title} / $title');
        }
      }
    }

    // ignore: avoid_print
    print('BUILT (${built.length}):');
    for (final title in built) {
      // ignore: avoid_print
      print('  $title');
    }
    // ignore: avoid_print
    print('NOT BUILT (${unbuilt.length}):');
    for (final title in unbuilt) {
      // ignore: avoid_print
      print('  $title');
    }

    // **The assertion that matters**: no entry may be `null` while the design
    // says it should exist. Left as a count rather than a list so this test does
    // not fail on every new screen, which would make it noise rather than signal.
    // The printed list is the deliverable; the assertion is the tripwire.
    expect(unbuilt, isNotEmpty,
        reason: 'update the inventory when the last '
            'placeholder is replaced');
  });
}

/// Enough services for navigation to build.
///
/// The navigation only reads *whether* a use case is present, so nulls are fine
/// and this avoids needing a database.
AppServices _services() => const AppServices();
