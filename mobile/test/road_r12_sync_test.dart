import 'package:drp_mobile/features/sync/application/road_r12_demo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Device A and Device B converge on Road R-12 after simulated sync',
      () async {
    final run = await runRoadR12Scenario();
    addTearDown(() async {
      await run.a.close();
      await run.b.close();
    });

    final hazardA =
        await run.a.hazards.readHazard(RoadR12Demo.entityId);
    final hazardB =
        await run.b.hazards.readHazard(RoadR12Demo.entityId);
    expect(hazardA, isNotNull);
    expect(hazardB, isNotNull);
    expect(hazardA!.type, hazardB!.type);
    expect(hazardA.severity, hazardB.severity);

    final winner = run.result.winners[RoadR12Demo.entityId];
    expect(winner, isNotNull);
    expect(hazardA.type.wireValue, winner!.payload['type']);
    expect(run.result.conflicts, isNotEmpty);

    final pendingA = await run.a.operations.readPending();
    expect(pendingA, isEmpty);
  });
}
