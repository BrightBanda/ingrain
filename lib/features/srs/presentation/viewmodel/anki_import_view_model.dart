import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ingrain/features/auth/presentation/viewmodel/auth_view_model.dart';
import 'package:ingrain/features/srs/data/anki/anki_importer.dart';
import 'package:ingrain/features/srs/data/anki/apkg_reader.dart';
import 'package:ingrain/features/srs/presentation/viewmodel/review_view_model.dart';
import 'package:path_provider/path_provider.dart';

final ankiImporterProvider = Provider<AnkiImporter>((ref) {
  return AnkiImporter(
    ref.watch(deckRepositoryProvider),
    ref.watch(reviewRepositoryProvider),
    ref.watch(authRepositoryProvider),
  );
});

/// Where the temporary unpacked collection goes. Overridable in tests.
final importTempDirectoryProvider = FutureProvider<String>(
  (ref) async => (await getTemporaryDirectory()).path,
);

sealed class AnkiImportState {
  const AnkiImportState();
}

class AnkiImportReading extends AnkiImportState {
  const AnkiImportReading();
}

/// Read and waiting for the learner to confirm.
class AnkiImportReady extends AnkiImportState {
  final AnkiImportPlan plan;

  const AnkiImportReady(this.plan);
}

class AnkiImportSaving extends AnkiImportState {
  final AnkiImportProgress progress;

  const AnkiImportSaving(this.progress);
}

class AnkiImportDone extends AnkiImportState {
  final AnkiImportResult result;

  const AnkiImportDone(this.result);
}

class AnkiImportFailed extends AnkiImportState {
  final String message;

  const AnkiImportFailed(this.message);
}

final ankiImportViewModelProvider =
    NotifierProvider.autoDispose<AnkiImportViewModel, AnkiImportState>(
      AnkiImportViewModel.new,
    );

class AnkiImportViewModel extends Notifier<AnkiImportState> {
  /// Imports past this size get a warning: the free Firestore tier allows
  /// about 20,000 writes a day, and each card is one.
  static const largeImport = 5000;

  @override
  AnkiImportState build() => const AnkiImportReading();

  Future<void> read(String apkgPath) async {
    state = const AnkiImportReading();
    try {
      final (tempDirectory, settings) = await (
        ref.read(importTempDirectoryProvider.future),
        ref.read(srsSettingsProvider.future),
      ).wait;
      final plan = await ref
          .read(ankiImporterProvider)
          .read(
            apkgPath,
            tempDirectory: tempDirectory,
            learningStepCount: settings.learningSteps.length,
          );
      if (!ref.mounted) return;
      state = plan.cardCount == 0
          ? const AnkiImportFailed('No cards with readable text were found.')
          : AnkiImportReady(plan);
    } on AnkiFormatException catch (error) {
      if (ref.mounted) state = AnkiImportFailed(error.message);
    } catch (error) {
      if (ref.mounted) {
        state = AnkiImportFailed('Could not read this file: $error');
      }
    }
  }

  Future<void> confirm() async {
    final current = state;
    if (current is! AnkiImportReady) return;
    try {
      final result = await ref
          .read(ankiImporterProvider)
          .save(
            current.plan,
            onProgress: (progress) {
              if (ref.mounted) state = AnkiImportSaving(progress);
            },
          );
      ref.invalidate(deckSummariesProvider);
      ref.invalidate(deckDetailProvider);
      ref.invalidate(dueCountProvider);
      if (ref.mounted) state = AnkiImportDone(result);
    } catch (error) {
      // Ids are stable, so importing the same file again finishes the job.
      if (ref.mounted) {
        state = AnkiImportFailed(
          'Import stopped: $error\nImporting the same file again picks up '
          'where it left off.',
        );
      }
    }
  }
}
