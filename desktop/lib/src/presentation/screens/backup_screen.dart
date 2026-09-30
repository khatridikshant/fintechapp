import 'package:flutter/material.dart';

import '../../domain/shared/book_backup.dart';
import '../../domain/shared/book_backup_service.dart';
import '../../domain/shared/book_year.dart';
import '../theme/app_theme.dart';

/// The Backup screen.
///
/// Shows every fiscal year the business has, whether each one has a backup, and
/// takes a backup of all of them. It is deliberately blunt about the two things
/// it does **not** do, because a business owner who believes their books are safe
/// when they are not is worse off than one who knows.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key, required this.service});

  /// The only thing the screen is given. It never touches a file or a database
  /// itself.
  final BackupActions service;

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  late Future<_BackupView> _view;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _view = _load();
  }

  Future<_BackupView> _load() async {
    final years = await widget.service.knownYears();
    final backups = await widget.service.listBackups();
    return _BackupView(years: years, backups: backups);
  }

  Future<void> _take() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final run = await widget.service.takeBackup();
      if (!mounted) return;
      setState(() {
        _message = _describeRun(run);
        _reload();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'The backup did not succeed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Says what a run covered, and what it did not.
  ///
  /// A run that covered three of four years is reported as such. Reporting it as
  /// a success would be the failure mode this screen exists to prevent.
  static String _describeRun(BackupRun run) {
    if (run.isEmpty) {
      return 'There were no books to back up.';
    }

    final covered = 'Backed up ${run.yearCount} '
        'fiscal year${run.yearCount == 1 ? '' : 's'} and verified '
        '${run.yearCount == 1 ? 'it' : 'them'}.';

    if (run.isComplete) return covered;

    final missed = run.failures
        .map((f) => '${f.fiscalYearLabel} (${f.reason})')
        .join('; ');
    return '$covered ${run.failures.length} could NOT be backed up: $missed';
  }

  Future<void> _verify(BookBackup backup) async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final verification = await widget.service.verify(backup);
      if (!mounted) return;
      setState(() => _message = '${backup.fileName}: ${verification.summary}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: palette.surface,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Backup', style: textTheme.headlineLarge),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: AppSpacing.lg, thickness: 2),
            // Expanded, so the column inside the builder has a bounded height.
            // Without this it shrink-wraps, and its own Expanded cannot expand
            // into an unbounded height.
            Expanded(
              child: FutureBuilder<_BackupView>(
                future: _view,
                builder: (context, snapshot) {
                  final view = snapshot.data;
                  final unprotected =
                      view?.unprotectedYears ?? const <BookYear>[];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      if (unprotected.isNotEmpty)
                        _UnprotectedYearsNotice(years: unprotected),
                      if (view != null && view.years.isNotEmpty)
                        _OffMachineWarning(),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: <Widget>[
                          FilledButton.icon(
                            onPressed: _busy || view == null ? null : _take,
                            icon: const Icon(Icons.save_alt, size: 18),
                            label: const Text('Back up all years now'),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          if (_busy)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                      if (_message != null) ...<Widget>[
                        const SizedBox(height: AppSpacing.md),
                        Text(_message!, style: textTheme.bodyMedium),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Text('Fiscal years', style: textTheme.titleLarge),
                      const SizedBox(height: AppSpacing.sm),
                      Expanded(
                        child: snapshot.connectionState ==
                                ConnectionState.waiting
                            ? const Center(child: CircularProgressIndicator())
                            : snapshot.hasError
                                ? Text('${snapshot.error}',
                                    style: textTheme.bodySmall)
                                : _YearsAndBackups(
                                    view: view!,
                                    busy: _busy,
                                    onVerify: _verify,
                                  ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The years found, each with its most recent backup or a warning that there is
/// none.
class _YearsAndBackups extends StatelessWidget {
  const _YearsAndBackups({
    required this.view,
    required this.busy,
    required this.onVerify,
  });

  final _BackupView view;
  final bool busy;
  final void Function(BookBackup backup) onVerify;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    if (view.years.isEmpty) {
      return Text(
        'No fiscal-year books were found. Nothing to back up yet.',
        style: textTheme.bodyMedium,
      );
    }

    return ListView(
      children: <Widget>[
        for (final year in view.years)
          _YearRow(
            year: year,
            latest: view.latestBackupFor(year.fiscalYearLabel),
            backupCount: view.backupCountFor(year.fiscalYearLabel),
            busy: busy,
            onVerify: onVerify,
            palette: palette,
            textTheme: textTheme,
          ),
      ],
    );
  }
}

class _YearRow extends StatelessWidget {
  const _YearRow({
    required this.year,
    required this.latest,
    required this.backupCount,
    required this.busy,
    required this.onVerify,
    required this.palette,
    required this.textTheme,
  });

  final BookYear year;
  final BookBackup? latest;
  final int backupCount;
  final bool busy;
  final void Function(BookBackup backup) onVerify;
  final AppPalette palette;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final hasBackup = latest != null;

    return ListTile(
      dense: true,
      leading: Icon(
        hasBackup ? Icons.check_circle_outline : Icons.warning_amber_outlined,
        color: hasBackup ? palette.positive : palette.error,
        size: 20,
      ),
      title: Text(year.fiscalYearLabel, style: textTheme.titleSmall),
      subtitle: Text(
        hasBackup
            ? 'Last backed up: ${latest!.takenAt.toLocal()}  •  '
                '$backupCount backup${backupCount == 1 ? '' : 's'}'
                '  •  ${latest!.readableSize}'
            : 'No backup for this year',
        style: textTheme.bodySmall?.copyWith(
          color: hasBackup ? null : palette.error,
        ),
      ),
      trailing: hasBackup
          ? TextButton(
              onPressed: busy ? null : () => onVerify(latest!),
              child: const Text('Verify'),
            )
          : null,
    );
  }
}

/// Names the years with no backup at all.
///
/// This is the warning that was missing. Backing up only the current year left
/// older ones, which are closest to the retention clock, unprotected while the
/// screen still looked reassuring.
class _UnprotectedYearsNotice extends StatelessWidget {
  const _UnprotectedYearsNotice({required this.years});

  final List<BookYear> years;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final names = years.map((y) => y.fiscalYearLabel).join(', ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.error.withValues(alpha: 0.08),
        border: Border.all(color: palette.error),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.error_outline, color: palette.error, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${years.length} fiscal '
                  'year${years.length == 1 ? ' has' : 's have'} no backup',
                  style: textTheme.titleSmall?.copyWith(color: palette.error),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '$names. These years have no copy anywhere. Take a backup now '
                  'so every year is protected, not only the current one.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Says plainly that a local backup does not survive losing the machine.
class _OffMachineWarning extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.warning.withValues(alpha: 0.08),
        border: Border.all(color: palette.warning),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, color: palette.warning, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'A backup on this computer does not survive losing this '
                  'computer',
                  style: textTheme.titleSmall?.copyWith(color: palette.warning),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Backups here protect against a damaged or accidentally '
                  'deleted file. They do not protect against the disk failing, '
                  'theft, or fire. Copy the backup folder onto a USB drive or an '
                  'external disk, and keep it somewhere else.',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// What the screen needs in order to draw itself.
class _BackupView {
  const _BackupView({required this.years, required this.backups});

  final List<BookYear> years;
  final List<BookBackup> backups;

  /// The most recent backup of [fiscalYearLabel], or null when there is none.
  BookBackup? latestBackupFor(String fiscalYearLabel) {
    for (final backup in backups) {
      if (backup.fiscalYearLabel == fiscalYearLabel) return backup;
    }
    return null;
  }

  int backupCountFor(String fiscalYearLabel) =>
      backups.where((b) => b.fiscalYearLabel == fiscalYearLabel).length;

  /// The years with no backup at all. **This is the list that matters.**
  List<BookYear> get unprotectedYears =>
      years.where((y) => latestBackupFor(y.fiscalYearLabel) == null).toList();
}
