export function SyncArchitecture() {
  const stages = [
    ["FIELD DEVICE A", "LOCAL DB", "OPERATION A"],
    ["FIELD DEVICE B", "LOCAL DB", "OPERATION B"],
  ];

  return (
    <div className="space-y-3 p-4 font-mono text-xs text-ink-300">
      <p className="label-caps text-ink-500">Transport-independent sync</p>
      <div className="grid gap-3 sm:grid-cols-2">
        {stages.map((column) => (
          <ol key={column[0]} className="space-y-1 rounded-sm border border-navy-700 p-3">
            {column.map((step) => (
              <li key={step}>{step}</li>
            ))}
          </ol>
        ))}
      </div>
      <p className="text-center text-ink-500">↓ simulated transport (later: BLE / Wi-Fi Direct / LoRa)</p>
      <p className="rounded-sm border border-accent-500/40 bg-accent-500/8 p-3 text-center text-ink-100">
        SYNC SERVICE → CRDT ENGINE → CONFLICT DETECTED → DETERMINISTIC MERGE
      </p>
      <p className="text-center text-nominal">SHARED STATE · DEVICE A = DEVICE B</p>
      <p className="text-[11px] leading-relaxed text-ink-500">
        The CRDT layer does not know how bytes arrived. Mesh radios are Slice 5. This dashboard
        shows peer ingest and the Road R-12 development scenario — not live mesh networking.
      </p>
    </div>
  );
}
