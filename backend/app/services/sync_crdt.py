"""Same total order as the Dart CRDT engine."""

from __future__ import annotations

from app.models.sync_operation import SyncOperation


def compare_operations(a: SyncOperation, b: SyncOperation) -> int:
    if a.logical_timestamp != b.logical_timestamp:
        return -1 if a.logical_timestamp < b.logical_timestamp else 1
    if a.device_id != b.device_id:
        return -1 if a.device_id < b.device_id else 1
    if str(a.operation_id) != str(b.operation_id):
        return -1 if str(a.operation_id) < str(b.operation_id) else 1
    return 0
