// Official KubbTracker — the turn loop: entry, finish guard, early king, undo.

function TurnShell({ children, cta, note, active = 'you', game = 'Game 2 · Turn 2', ys = 1, os = 0 }) {
  return (
    <KubbPhone>
      <KTNav back="Exit" title={game} trailing={<OfficialPill></OfficialPill>}></KTNav>
      <ScoreStrip ys={ys} os={os} active={active}></ScoreStrip>
      <div style={{ flex: 1, overflow: 'hidden', padding: '0 16px', display: 'flex', flexDirection: 'column' }}>{children}</div>
      {(cta || note) && (
        <div style={{ padding: '8px 16px 14px', background: 'linear-gradient(rgba(250,248,243,0), #FAF8F3 30%)' }}>
          {note}
          {cta}
        </div>
      )}
    </KubbPhone>
  );
}

// ── 9. Turn entry — the centerpiece ────────────────────────
function KTTurn() {
  return (
    <TurnShell
      cta={<KTCta label="Submit turn" color={OF.navy}></KTCta>}
      note={<Receipt style={{ marginBottom: 10 }}>4 eight-meter throws · <b>3 baseline kubbs</b> (2 + the double) · 1 field kubb left → advantage line 2 ft from the king.</Receipt>}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '10px 2px 6px' }}>
        <KubbEyebrow style={{ padding: 0, color: OF.blue }}>Your turn</KubbEyebrow>
        <MonoTag color={OF.blue} bg={OF.soft}>Round 2 · 4 batons</MonoTag>
      </div>
      <div style={{ overflow: 'hidden', flex: 1 }}>
        <KubbCard>
          <Stepper label="8-meter throws" sub="Batons thrown from the baseline" value={4} max={4}></Stepper>
          <Stepper label="Baseline kubbs hit" sub="Normal throws only · Dave has 3 standing" value={2} max={3} accent={OF.blue} isLast></Stepper>
        </KubbCard>
        <KubbCard style={{ marginTop: 10 }}>
          <ToggleRow label="Base kubb double" sub={<span>One baton took a field kubb <b>and</b> a baseline kubb. Counted on top — don't add it above.</span>} on tint={OF.blue} isLast></ToggleRow>
          <div style={{ margin: '0 14px 12px', padding: '7px 10px', borderRadius: 9, background: OF.soft2, fontFamily: KF.mono, fontSize: 9.5, fontWeight: 700, letterSpacing: 0.8, color: OF.blue }}>RECORDS 3 BASELINE KUBBS — 2 ENTERED + 1 DOUBLE</div>
        </KubbCard>
        <KubbCard style={{ marginTop: 10 }}>
          <Stepper label="Field kubbs left standing" sub="Uncleared on your side — gives Dave a line" value={1} max={2}></Stepper>
          <div style={{ padding: '10px 14px', borderBottom: '0.5px solid rgba(13,23,38,0.08)' }}>
            <div style={{ fontFamily: KF.sans, fontSize: 14, fontWeight: 600, letterSpacing: -0.2, color: '#0D1726', marginBottom: 8 }}>Advantage line given</div>
            <ChipRow options={['At the king', '1 ft', '2 ft', '4 ft', '6 ft', 'At baseline']} value="2 ft"></ChipRow>
          </div>
          <Stepper label="Penalty kubbs" sub="Thrown out of bounds twice" value={0} max={2} isLast></Stepper>
        </KubbCard>
      </div>
    </TurnShell>
  );
}

// ── 10. King phase + finish guard ──────────────────────────
function KTFinish() {
  return (
    <KubbPhone>
      <KTNav back="Exit" title="Game 2 · Turn 4" trailing={<OfficialPill></OfficialPill>}></KTNav>
      <ScoreStrip ys={1} os={0} active="you"></ScoreStrip>
      <div style={{ flex: 1, padding: '0 16px', opacity: 0.5 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '14px 2px 8px' }}>
          <KubbEyebrow style={{ padding: 0, color: OF.blue }}>Your turn</KubbEyebrow>
          <MonoTag color={OF.blue} bg={OF.soft}>Round 3 · 6 batons</MonoTag>
        </div>
        <KubbCard>
          <Stepper label="8-meter throws" sub="Baseline is clear — throwing at the king" value={2} max={6}></Stepper>
          <Stepper label="King shots" sub="Cumulative, over all turns" value={2} max={20} accent={OF.goldInk}></Stepper>
          <ToggleRow label="King down" sub="The winning hit" on tint={OF.green} isLast></ToggleRow>
        </KubbCard>
      </div>
      <Sheet>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <div style={{ width: 15, height: 28, borderRadius: 4, background: OF.gold, border: '1px solid rgba(13,23,38,0.2)' }}></div>
          <KubbEyebrow style={{ padding: 0, color: OF.green }}>King down · game over</KubbEyebrow>
        </div>
        <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 30, letterSpacing: -1.1, color: '#0D1726', marginTop: 8 }}>End Game 2 — you win?</div>
        <div style={{ margin: '14px 0 16px', background: '#fff', borderRadius: 14, boxShadow: '0 1px 2px rgba(13,23,38,0.05)', overflow: 'hidden' }}>
          {[['Baseline cleared', '5 of 5 kubbs down'], ['King shots', '2 over all turns'], ['Game finished flag', 'Locks the game on kubbtracker.com']].map(([l, s], i, a) => (
            <div key={l} style={{ display: 'flex', alignItems: 'center', gap: 11, padding: '10px 14px', borderBottom: i < a.length - 1 ? '0.5px solid rgba(13,23,38,0.08)' : 'none' }}>
              <span style={{ color: OF.green }}>{ic.check}</span>
              <div style={{ flex: 1, fontFamily: KF.sans, fontSize: 13.5, fontWeight: 600, letterSpacing: -0.2 }}>{l}</div>
              <div style={{ fontFamily: KF.mono, fontSize: 9.5, fontWeight: 700, letterSpacing: 0.6, color: 'rgba(13,23,38,0.45)', textTransform: 'uppercase' }}>{s}</div>
            </div>
          ))}
        </div>
        <KTCta label="End game — Scott wins 2–0" color={OF.green}></KTCta>
        <div style={{ textAlign: 'center', fontFamily: KF.sans, fontSize: 13, fontWeight: 600, color: 'rgba(13,23,38,0.55)', padding: '14px 0 0' }}>Not yet — keep editing</div>
      </Sheet>
    </KubbPhone>
  );
}

// ── 11. Early king guard ───────────────────────────────────
function KTEarlyKing() {
  return (
    <KubbPhone>
      <KTNav back="Exit" title="Game 2 · Turn 2" trailing={<OfficialPill></OfficialPill>}></KTNav>
      <ScoreStrip ys={1} os={0} active="you"></ScoreStrip>
      <div style={{ flex: 1, padding: '0 16px', opacity: 0.5 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '14px 2px 8px' }}>
          <KubbEyebrow style={{ padding: 0, color: OF.blue }}>Your turn</KubbEyebrow>
          <MonoTag color={OF.blue} bg={OF.soft}>Round 2 · 4 batons</MonoTag>
        </div>
        <KubbCard>
          <Stepper label="8-meter throws" value={3} max={4}></Stepper>
          <Stepper label="Baseline kubbs hit" sub="Dave has 3 standing" value={1} max={3} isLast></Stepper>
        </KubbCard>
      </div>
      <Sheet tint="rgba(76,17,17,0.45)">
        <KubbEyebrow style={{ padding: 0, color: OF.miss }}>Hold on</KubbEyebrow>
        <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 30, letterSpacing: -1.1, color: '#0D1726', marginTop: 8 }}>King down early?</div>
        <div style={{ fontFamily: KF.sans, fontSize: 13.5, lineHeight: 1.55, color: 'rgba(13,23,38,0.65)', margin: '10px 0 18px' }}>Dave still has <b>3 baseline kubbs standing</b>. Toppling the king before the baseline is clear is an <b style={{ color: OF.miss }}>automatic loss</b> — and it can't be undone once Dave plays his turn.</div>
        <KTCta label="It happened — take the loss" color={OF.miss}></KTCta>
        <div style={{ textAlign: 'center', fontFamily: KF.sans, fontSize: 13, fontWeight: 600, color: 'rgba(13,23,38,0.55)', padding: '14px 0 0' }}>Go back — the king is fine</div>
      </Sheet>
    </KubbPhone>
  );
}

// ── 12. Turn sent + undo window ────────────────────────────
function KTUndo() {
  return (
    <KubbPhone>
      <KTNav back="Exit" title="Game 2" trailing={<OfficialPill></OfficialPill>}></KTNav>
      <ScoreStrip ys={1} os={0} active="opp"></ScoreStrip>
      <div style={{ flex: 1, padding: '0 16px', display: 'flex', flexDirection: 'column' }}>
        <div style={{ margin: '14px 0 0', background: 'rgba(31,102,70,0.08)', border: '1px solid rgba(31,102,70,0.2)', borderRadius: 13, padding: '11px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
          <span style={{ color: OF.green }}>{ic.check}</span>
          <div style={{ flex: 1, fontFamily: KF.sans, fontSize: 13, fontWeight: 600, color: '#0D1726' }}>Turn 2 sent to KubbTracker</div>
        </div>
        <KubbEyebrow style={{ margin: '18px 0 8px' }}>Your last turn</KubbEyebrow>
        <KubbCard>
          <FeedRow turn="2" player="Scott Thompson · You" you text="4 eight-meter throws, hit 3 baseline kubbs (incl. a base kubb double). 1 field kubb left — advantage line 2 ft." isLast></FeedRow>
          <div style={{ borderTop: '0.5px solid rgba(13,23,38,0.08)', padding: '11px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
            <span style={{ color: OF.miss }}>{ic.trash}</span>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: KF.sans, fontSize: 14, fontWeight: 600, color: OF.miss, letterSpacing: -0.2 }}>Cancel last turn</div>
              <div style={{ fontFamily: KF.sans, fontSize: 11.5, color: 'rgba(13,23,38,0.5)', marginTop: 2 }}>Available until Dave enters his turn</div>
            </div>
            {ic.chevR('rgba(13,23,38,0.3)')}
          </div>
        </KubbCard>
        <div style={{ marginTop: 'auto', paddingBottom: 28, display: 'flex', flexDirection: 'column', gap: 14, alignItems: 'center' }}>
          <Listen label="Dave is up · listening every 6s"></Listen>
        </div>
      </div>
    </KubbPhone>
  );
}

Object.assign(window, { TurnShell, KTTurn, KTFinish, KTEarlyKing, KTUndo });
