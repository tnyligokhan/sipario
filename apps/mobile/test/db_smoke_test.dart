import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sipario/data/app_database.dart';

void main() {
  test('in-memory Drift açılır ve customers yazılıp okunur', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            id: 'c1',
            name: 'Test',
            updatedOccurredAt: '2026-07-13T10:00:00Z',
          ),
        );

    final rows = await db.select(db.customers).get();
    expect(rows, hasLength(1));
    expect(rows.first.name, 'Test');

    // sync_meta singleton beforeOpen ile kurulur.
    final meta = await db.syncState();
    expect(meta.id, 1);
    expect(meta.lastPulledSeq, 0);
  });
}
