import 'package:drp_mobile/data/local/app_database.dart';
import 'package:drp_mobile/data/local/daos/app_metadata_dao.dart';
import 'package:drp_mobile/data/local/daos/victim_dao.dart';
import 'package:drp_mobile/data/local/tables/app_metadata.dart';
import 'package:drp_mobile/domain/entities/sync_status.dart';
import 'package:drp_mobile/domain/entities/triage_category.dart';
import 'package:drp_mobile/domain/entities/victim.dart';
import 'package:drp_mobile/domain/entities/victim_demographics.dart';
import 'package:drp_mobile/domain/entities/victim_draft.dart';
import 'package:drp_mobile/domain/entities/victim_query.dart';
import 'package:drp_mobile/domain/entities/victim_status.dart';
import 'package:drp_mobile/features/victims/data/victim_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_database.dart';

/// The offline-first guarantee, exercised against the real schema.
///
/// Nothing in this file constructs an HTTP client or a backend stub, because
/// nothing in the registration path is allowed to need one.
void main() {
  late AppDatabase database;
  late VictimRepository repository;

  setUp(() {
    database = openTestDatabase();
    repository = VictimRepository(
      victims: VictimDao(database),
      metadata: AppMetadataDao(database),
    );
  });

  tearDown(() => database.close());

  VictimDraft draft({
    TriageCategory triage = TriageCategory.urgent,
    String? name = 'R. Desai',
    int? age = 34,
    Gender gender = Gender.female,
    String? injury = 'Fractured femur',
    String? condition = 'Conscious, bleeding controlled',
    String? assistance = 'Stretcher',
    VictimStatus status = VictimStatus.registered,
  }) =>
      VictimDraft(
        triageCategory: triage,
        name: name,
        age: age,
        gender: gender,
        injuryType: injury,
        medicalCondition: condition,
        assistanceRequired: assistance,
        status: status,
      );

  Future<Victim> register({
    TriageCategory triage = TriageCategory.urgent,
    String? name = 'R. Desai',
    int? age = 34,
    String? injury = 'Fractured femur',
    VictimStatus status = VictimStatus.registered,
    String createdBy = 'offline-abc123',
  }) =>
      repository.register(
        draft: draft(triage: triage, name: name, age: age, injury: injury, status: status),
        createdBy: createdBy,
      );

  group('schema', () {
    test('is at version 4 and still carries the victims table', () async {
      await database.select(database.appMetadata).get();

      expect(database.schemaVersion, 5);
      expect(
        database.tableNames,
        containsAll(<String>['app_metadata', 'local_sessions', 'victims']),
      );
    });
  });

  group('registration', () {
    test('writes a complete record without any backend', () async {
      final victim = await register();

      final stored = await repository.readVictim(victim.id);

      expect(stored, isNotNull);
      expect(stored!.name, 'R. Desai');
      expect(stored.triageCategory, TriageCategory.urgent);
      expect(stored.status, VictimStatus.registered);
      expect(stored.injuryType, 'Fractured femur');
      expect(stored.createdBy, 'offline-abc123');
    });

    test('mints a UUID and a speakable field id', () async {
      final victim = await register();

      expect(
        victim.id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(victim.temporaryId, matches(RegExp(r'^V-[0-9A-F]{4}-\d{3}$')));
    });

    test('gives every victim on the device a distinct field id', () async {
      final first = await register(name: 'One');
      final second = await register(name: 'Two');
      final third = await register(name: 'Three');

      final ids = {first.temporaryId, second.temporaryId, third.temporaryId};

      expect(ids, hasLength(3));
      expect(third.temporaryId, endsWith('003'));
    });

    test('derives the age band from the age, and both are stored', () async {
      final infant = await repository.register(
        draft: draft(age: 1),
        createdBy: 'offline-abc123',
      );
      final child = await repository.register(
        draft: draft(age: 9),
        createdBy: 'offline-abc123',
      );
      final elderly = await repository.register(
        draft: draft(age: 71),
        createdBy: 'offline-abc123',
      );
      final unknown = await repository.register(
        draft: draft(age: null),
        createdBy: 'offline-abc123',
      );

      expect(infant.ageGroup, AgeGroup.infant);
      expect(child.ageGroup, AgeGroup.child);
      expect(elderly.ageGroup, AgeGroup.elderly);
      expect(unknown.ageGroup, AgeGroup.unknown);
      expect(unknown.age, isNull);
    });

    test('accepts an unidentified person', () async {
      final victim = await repository.register(
        draft: draft(name: '   '),
        createdBy: 'offline-abc123',
      );

      expect(victim.name, isNull);
      expect(victim.displayName, 'Unidentified');
    });

    test('marks the record as pending synchronisation', () async {
      final victim = await register();

      expect(victim.syncStatus, SyncStatus.pending);
    });

    test('records the priority implied by the triage category', () async {
      for (final category in TriageCategory.values) {
        final victim = await repository.register(
          draft: draft(triage: category),
          createdBy: 'offline-abc123',
        );
        expect(victim.priority, category.priority);
      }
    });
  });

  group('persistence across a restart', () {
    test('records survive a new DAO over the same database', () async {
      final victim = await register(name: 'Persisted Person');

      // A fresh repository stands in for the app being killed and reopened:
      // nothing is cached in memory, everything is read back from SQLite.
      final reopened = VictimRepository(
        victims: VictimDao(database),
        metadata: AppMetadataDao(database),
      );

      final restored = await reopened.readVictim(victim.id);

      expect(restored, isNotNull);
      expect(restored!.name, 'Persisted Person');
      expect(restored.temporaryId, victim.temporaryId);
    });

    test('a triage change survives too', () async {
      final victim = await register(triage: TriageCategory.moderate);

      await repository.reassess(
        victim: victim,
        category: TriageCategory.critical,
      );

      final reopened = VictimRepository(
        victims: VictimDao(database),
        metadata: AppMetadataDao(database),
      );
      final restored = await reopened.readVictim(victim.id);

      expect(restored!.triageCategory, TriageCategory.critical);
      expect(restored.priority, TriageCategory.critical.priority);
    });

    test('the field id sequence continues after a restart', () async {
      await register();
      await register();

      final reopened = VictimRepository(
        victims: VictimDao(database),
        metadata: AppMetadataDao(database),
      );
      final third = await reopened.register(
        draft: draft(),
        createdBy: 'offline-abc123',
      );

      expect(third.temporaryId, endsWith('003'));
      expect(
        await AppMetadataDao(database).read(AppMetadataKeys.victimSequence),
        '3',
      );
    });
  });

  group('reassessment and status', () {
    test('reassessing changes the category and bumps updatedAt', () async {
      final victim = await repository.register(
        draft: draft(triage: TriageCategory.stable),
        createdBy: 'offline-abc123',
        now: DateTime.utc(2026, 8, 29, 9),
      );

      final reassessed = await repository.reassess(
        victim: victim,
        category: TriageCategory.critical,
        now: DateTime.utc(2026, 8, 29, 10),
      );

      expect(reassessed.triageCategory, TriageCategory.critical);
      expect(reassessed.priority, 1);
      expect(reassessed.updatedAt.isAfter(victim.updatedAt), isTrue);
      expect(reassessed.createdAt, victim.createdAt);
    });

    test('every category can be assigned and read back', () async {
      final victim = await register();

      for (final category in TriageCategory.values) {
        await repository.reassess(victim: victim, category: category);
        final stored = await repository.readVictim(victim.id);

        expect(stored!.triageCategory, category);
        expect(stored.priority, category.priority);
      }
    });

    test('every status can be assigned and read back', () async {
      final victim = await register();

      for (final status in VictimStatus.values) {
        await repository.changeStatus(victim: victim, status: status);
        expect((await repository.readVictim(victim.id))!.status, status);
      }
    });

    test('marking evacuated leaves the triage category untouched', () async {
      final victim = await register(triage: TriageCategory.critical);

      final evacuated = await repository.changeStatus(
        victim: victim,
        status: VictimStatus.evacuated,
      );

      expect(evacuated.status, VictimStatus.evacuated);
      expect(evacuated.triageCategory, TriageCategory.critical);
    });

    test('editing rewrites the fields it was given', () async {
      final victim = await register();

      final updated = await repository.update(
        victim: victim,
        draft: draft(
          triage: TriageCategory.moderate,
          name: 'R. Desai-Patel',
          age: 35,
          injury: 'Fractured femur, splinted',
        ),
      );

      final stored = await repository.readVictim(victim.id);

      expect(stored!.name, 'R. Desai-Patel');
      expect(stored.age, 35);
      expect(stored.ageGroup, AgeGroup.adult);
      expect(stored.triageCategory, TriageCategory.moderate);
      expect(stored.temporaryId, updated.temporaryId);
    });

    test('clearing a field stores null rather than an empty string', () async {
      final victim = await register();

      await repository.update(
        victim: victim,
        draft: draft(injury: '', name: ''),
      );

      final stored = await repository.readVictim(victim.id);

      expect(stored!.injuryType, isNull);
      expect(stored.name, isNull);
    });
  });

  group('list ordering and filtering', () {
    Future<void> seed() async {
      await register(name: 'Stable One', triage: TriageCategory.stable);
      await register(name: 'Critical One', triage: TriageCategory.critical);
      await register(name: 'Moderate One', triage: TriageCategory.moderate);
      await register(name: 'Urgent One', triage: TriageCategory.urgent);
    }

    test('sorts critical first', () async {
      await seed();

      final victims = await repository.readVictims();

      expect(
        victims.map((victim) => victim.triageCategory).toList(),
        [
          TriageCategory.critical,
          TriageCategory.urgent,
          TriageCategory.moderate,
          TriageCategory.stable,
        ],
      );
    });

    test('sinks evacuated and deceased below everyone still open', () async {
      await seed();
      final critical = (await repository.readVictims()).first;
      await repository.changeStatus(
        victim: critical,
        status: VictimStatus.evacuated,
      );

      final victims = await repository.readVictims();

      expect(victims.first.triageCategory, TriageCategory.urgent);
      expect(victims.last.name, 'Critical One');
    });

    test('filters by triage category', () async {
      await seed();

      final victims = await repository.readVictims(
        const VictimQuery(triage: TriageCategory.critical),
      );

      expect(victims, hasLength(1));
      expect(victims.single.name, 'Critical One');
    });

    test('filters by status', () async {
      await seed();
      final first = (await repository.readVictims()).first;
      await repository.changeStatus(
        victim: first,
        status: VictimStatus.awaitingEvacuation,
      );

      final victims = await repository.readVictims(
        const VictimQuery(status: VictimStatus.awaitingEvacuation),
      );

      expect(victims, hasLength(1));
      expect(victims.single.id, first.id);
    });

    test('searches name, field id and injury, case-insensitively', () async {
      await seed();
      final tagged = await register(
        name: 'Zoya Khan',
        injury: 'Smoke inhalation',
      );

      expect(
        (await repository.readVictims(const VictimQuery(search: 'zoya')))
            .single
            .name,
        'Zoya Khan',
      );
      expect(
        (await repository.readVictims(const VictimQuery(search: 'INHALATION')))
            .single
            .name,
        'Zoya Khan',
      );
      expect(
        (await repository.readVictims(VictimQuery(search: tagged.temporaryId)))
            .single
            .id,
        tagged.id,
      );
    });

    test('combines search with a filter', () async {
      await seed();

      final victims = await repository.readVictims(
        const VictimQuery(search: 'one', triage: TriageCategory.urgent),
      );

      expect(victims, hasLength(1));
      expect(victims.single.name, 'Urgent One');
    });

    test('an unmatched search returns nothing rather than everything', () async {
      await seed();

      expect(
        await repository.readVictims(const VictimQuery(search: 'no-such-name')),
        isEmpty,
      );
    });
  });

  group('board counts', () {
    test('counts by category, openness and pending synchronisation', () async {
      await register(triage: TriageCategory.critical);
      await register(triage: TriageCategory.critical);
      await register(triage: TriageCategory.stable);
      final evacuee = await register(triage: TriageCategory.moderate);
      await repository.changeStatus(
        victim: evacuee,
        status: VictimStatus.evacuated,
      );

      final board = await repository.watchBoard().first;

      expect(board.total, 4);
      expect(board.countOf(TriageCategory.critical), 2);
      expect(board.countOf(TriageCategory.stable), 1);
      expect(board.countOf(TriageCategory.urgent), 0);
      expect(board.open, 3);
      expect(board.pendingSync, 4);
    });
  });

  group('live queries', () {
    test('the list stream emits when a victim is registered', () async {
      final emissions = <List<Victim>>[];
      final subscription =
          repository.watchVictims(const VictimQuery()).listen(emissions.add);

      await register(name: 'Streamed Person');
      await pumpEventQueue();
      await subscription.cancel();

      expect(emissions.last.single.name, 'Streamed Person');
    });
  });
}
