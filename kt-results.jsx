// Official KubbTracker — between games, results, history, failure states.

// ── 13. Match hub between games ────────────────────────────
function KTHub() {
  const row = (g, t1, k1, t2, k2, turns, winner, open) => (
    <div style={{ display: 'flex', alignItems: 'center', padding: '10px 14px', borderBottom: open ? 'none' : '0.5px solid rgba(13,23,38,0.08)', background: open ? OF.soft2 : 'transparent' }}>
      <div style={{ width: 24, fontFamily: KF.mono, fontSize: 10.5, fontWeight: 700, color: 'rgba(13,23,38,0.45)' }}>{g}</div>
      <div style={{ flex: 1, fontFamily: KF.sans, fontSize: 12.5, color: 'rgba(13,23,38,0.8)' }}>{t1} <span style={{ fontFamily: KF.mono, fontSize: 10.5, fontWeight: 700, color: 'rgba(13,23,38,0.45)' }}>{k1}</span> · {t2} <span style={{ fontFamily: KF.mono, fontSize: 10.5, fontWeight: 700, color: 'rgba(13,23,38,0.45)' }}>{k2}</span></div>
      <div style={{ width: 52, fontFamily: KF.mono, fontSize: 9.5, fontWeight: 700, letterSpacing: 0.5, color: 'rgba(13,23,38,0.4)', textAlign: 'center' }}>{turns} TRN</div>
      {open
        ? <MonoTag color={OF.blue} bg={OF.soft}>Open</MonoTag>
        : <div style={{ fontFamily: KF.sans, fontSize: 12, fontWeight: 700, color: '#0D1726', width: 44, textAlign: 'right' }}>{winner}</div>}
    </div>
  );
  return (
    <KubbPhone>
      <KTNav back="Exit" title="Match #1774" trailing={<OfficialPill></OfficialPill>}></KTNav>
      <div style={{ padding: '10px 16px 0', flex: 1, display: 'flex', flexDirection: 'column' }}>
        <KubbCard style={{ padding: '20px 18px', textAlign: 'center' }}>
          <KubbEyebrow style={{ padding: 0, color: OF.green }}>Game 1 — yours</KubbEyebrow>
          <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'center', gap: 14, marginTop: 10 }}>
            <span style={{ fontFamily: KF.sans, fontSize: 13, fontWeight: 700 }}>Scott</span>
            <span style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 46, letterSpacing: -2, lineHeight: 1 }}>1<span style={{ color: 'rgba(13,23,38,0.3)', padding: '0 8px' }}>–</span>0</span>
            <span style={{ fontFamily: KF.sans, fontSize: 13, fontWeight: 700, color: 'rgba(13,23,38,0.55)' }}>Dave</span>
          </div>
          <div style={{ fontFamily: KF.mono, fontSize: 9.5, fontWeight: 700, letterSpacing: 1.2, color: 'rgba(13,23,38,0.45)', marginTop: 10 }}>RACE TO 2 · ONE MORE TAKES IT</div>
        </KubbCard>
        <KubbEyebrow style={{ margin: '16px 0 8px' }}>Games</KubbEyebrow>
        <KubbCard>
          {row('1', 'Scott', 0, 'Dave', 2, 3, 'Scott')}
          {row('2', 'Dave', 5, 'Scott', 5, 0, null, true)}
        </KubbCard>
        <div style={{ background: OF.soft2, border: `1px solid ${OF.line}`, borderRadius: 12, padding: '10px 13px', marginTop: 12, display: 'flex', gap: 10, alignItems: 'flex-start' }}>
          <span style={{ color: OF.blue, flexShrink: 0, marginTop: 1 }}>{ic.info}</span>
          <div style={{ fontFamily: KF.sans, fontSize: 12, lineHeight: 1.5, color: 'rgba(13,23,38,0.65)' }}><b>You throw first in Game 2.</b> No re-lag — the opening throw alternates from the original lag every game.</div>
        </div>
        <div style={{ marginTop: 'auto', paddingBottom: 24 }}>
          <KTCta label="Enter Game 2" color={OF.navy}></KTCta>
        </div>
      </div>
    </KubbPhone>
  );
}

// ── 14. Match complete ─────────────────────────────────────
function KTComplete() {
  const stat = (l, v, sub) => (
    <div style={{ flex: 1, background: '#fff', borderRadius: 14, padding: '12px 12px 10px', boxShadow: '0 1px 2px rgba(13,23,38,0.04), 0 4px 14px rgba(13,23,38,0.05)' }}>
      <div style={{ fontFamily: KF.mono, fontSize: 8.5, fontWeight: 700, letterSpacing: 1.1, textTransform: 'uppercase', color: 'rgba(13,23,38,0.45)' }}>{l}</div>
      <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 24, letterSpacing: -0.8, color: '#0D1726', marginTop: 4 }}>{v}</div>
      <div style={{ fontFamily: KF.sans, fontSize: 10.5, color: 'rgba(13,23,38,0.5)', marginTop: 2 }}>{sub}</div>
    </div>
  );
  return (
    <KubbPhone>
      <KTNav back="Done" title="Match #1774" trailing={<OfficialPill></OfficialPill>}></KTNav>
      <div style={{ padding: '10px 16px 0', flex: 1, display: 'flex', flexDirection: 'column', overflow: 'hidden' }}>
        <div style={{ background: `linear-gradient(160deg, rgba(254,204,2,0.18), rgba(254,204,2,0.04) 70%)`, border: '1px solid rgba(138,103,0,0.18)', borderRadius: 18, padding: '20px 18px', textAlign: 'center' }}>
          <KubbEyebrow style={{ padding: 0, color: OF.goldInk }}>Official match won</KubbEyebrow>
          <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 36, letterSpacing: -1.5, color: '#0D1726', marginTop: 8, lineHeight: 1.1 }}>You beat Dave 2–0</div>
          <div style={{ fontFamily: KF.mono, fontSize: 9.5, fontWeight: 700, letterSpacing: 1.2, color: 'rgba(13,23,38,0.5)', marginTop: 8 }}>1 VS 1 · RACE TO 2 · AUG 6, 2026</div>
        </div>
        <KubbEyebrow style={{ margin: '14px 0 8px' }}>Your match stats</KubbEyebrow>
        <div style={{ display: 'flex', gap: 8 }}>
          {stat('8m throws', '10 of 13', '77% accuracy')}
          {stat('Penalties', '0', 'clean match')}
          {stat('Advantages', '1', 'line given once')}
        </div>
        <KubbEyebrow style={{ margin: '14px 0 8px' }}>Games</KubbEyebrow>
        <KubbCard>
          {[['1', 'Scott over Dave', '0–2 kubbs · 3 turns'], ['2', 'Scott over Dave', '2–0 kubbs · 3 turns']].map(([g, w, s], i) => (
            <div key={g} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 14px', borderBottom: i === 0 ? '0.5px solid rgba(13,23,38,0.08)' : 'none' }}>
              <div style={{ width: 24, height: 24, borderRadius: 7, background: 'rgba(31,102,70,0.1)', color: OF.green, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: KF.mono, fontSize: 10.5, fontWeight: 700 }}>{g}</div>
              <div style={{ flex: 1, fontFamily: KF.sans, fontSize: 13, fontWeight: 600 }}>{w}</div>
              <div style={{ fontFamily: KF.mono, fontSize: 9.5, fontWeight: 700, letterSpacing: 0.4, color: 'rgba(13,23,38,0.45)', textTransform: 'uppercase' }}>{s}</div>
            </div>
          ))}
        </KubbCard>
        <div style={{ display: 'flex', alignItems: 'center', gap: 9, padding: '12px 4px 0' }}>
          <span style={{ color: OF.green }}>{ic.check}</span>
          <div style={{ fontFamily: KF.sans, fontSize: 12, color: 'rgba(13,23,38,0.6)' }}>Saved to Game Tracker history · synced to kubbtracker.com</div>
        </div>
        <div style={{ marginTop: 'auto', paddingBottom: 24 }}>
          <KTCta label="Done" color={OF.navy}></KTCta>
        </div>
      </div>
    </KubbPhone>
  );
}

// ── 15. History with official rows ─────────────────────────
function KTHistory() {
  const row = (date, sub, badge, right, rightSub, i, last) => (
    <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', borderBottom: last ? 'none' : '0.5px solid rgba(13,23,38,0.08)' }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
          <span style={{ fontFamily: KF.sans, fontSize: 13.5, fontWeight: 600, letterSpacing: -0.2 }}>{date}</span>
          {badge}
        </div>
        <div style={{ fontFamily: KF.sans, fontSize: 11.5, color: 'rgba(13,23,38,0.5)', marginTop: 3 }}>{sub}</div>
      </div>
      <div style={{ textAlign: 'right' }}>
        <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 17, letterSpacing: -0.4 }}>{right}</div>
        <div style={{ fontFamily: KF.mono, fontSize: 8.5, fontWeight: 700, letterSpacing: 0.8, color: 'rgba(13,23,38,0.4)', textTransform: 'uppercase', marginTop: 2 }}>{rightSub}</div>
      </div>
    </div>
  );
  return (
    <KubbPhone>
      <KTNav back="History" title="Game Tracker"></KTNav>
      <div style={{ padding: '8px 16px 0', flex: 1, overflow: 'hidden' }}>
        <ChipRow options={['All', 'Phantom', 'Competitive', 'Official']} value="All" style={{ marginBottom: 14 }}></ChipRow>
        <KubbEyebrow style={{ marginBottom: 8 }}>August 2026</KubbEyebrow>
        <KubbCard>
          {row('Wed, Aug 6', 'vs Dave Akin · match #1774 · synced ✓', <OfficialPill></OfficialPill>, 'W 2–0', '77% ACC', 1)}
          {row('Mon, Aug 4', 'vs Erik · side A attack', <MonoTag color="#7C6FA0" bg="rgba(124,111,160,0.12)">Match</MonoTag>, 'L 1–2', '68% ACC', 2)}
          {row('Sun, Aug 3', 'solo · both sides', <MonoTag color="#7C6FA0" bg="rgba(124,111,160,0.12)">Phantom</MonoTag>, '9 turns', '81% EFF', 3)}
          {row('Sat, Aug 2', 'vs Dave Akin · match #1773 · synced ✓', <OfficialPill></OfficialPill>, 'L 0–1', '50% ACC', 4, true)}
        </KubbCard>
        <div style={{ fontFamily: KF.sans, fontSize: 11.5, color: 'rgba(13,23,38,0.45)', lineHeight: 1.5, padding: '12px 4px 0' }}>Official matches count toward your Game Tracker stats. Tap one to see the play-by-play or open it on kubbtracker.com.</div>
      </div>
    </KubbPhone>
  );
}

// ── 16. Connection lost ────────────────────────────────────
function KTOffline() {
  return (
    <KubbPhone>
      <KTNav back="Exit" title="Game 2" trailing={<OfficialPill></OfficialPill>}></KTNav>
      <div style={{ margin: '4px 16px 0', background: 'rgba(197,48,48,0.08)', border: '1px solid rgba(197,48,48,0.25)', borderRadius: 13, padding: '10px 14px', display: 'flex', alignItems: 'center', gap: 10 }}>
        <span style={{ width: 8, height: 8, borderRadius: 99, background: OF.miss, flexShrink: 0 }}></span>
        <div style={{ flex: 1, fontFamily: KF.sans, fontSize: 13, fontWeight: 600, color: OF.miss }}>Can't reach kubbtracker.com</div>
        <div style={{ fontFamily: KF.mono, fontSize: 9, fontWeight: 700, letterSpacing: 0.8, color: 'rgba(13,23,38,0.45)' }}>RETRY IN 4S</div>
      </div>
      <div style={{ flex: 1, padding: '0 16px', display: 'flex', flexDirection: 'column', justifyContent: 'center', textAlign: 'center' }}>
        <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 30, letterSpacing: -1.1, color: '#0D1726' }}>Nothing is lost</div>
        <div style={{ fontFamily: KF.sans, fontSize: 13, lineHeight: 1.55, color: 'rgba(13,23,38,0.6)', margin: '10px 24px 0' }}>KubbTracker keeps the whole match on its side. When you're back online we re-read the live state and pick up exactly where the match is.</div>
        <div style={{ margin: '22px 12px 0', background: '#fff', borderRadius: 14, padding: '12px 14px', boxShadow: '0 1px 2px rgba(13,23,38,0.04), 0 4px 14px rgba(13,23,38,0.05)', textAlign: 'left' }}>
          <div style={{ fontFamily: KF.mono, fontSize: 9, fontWeight: 700, letterSpacing: 1.2, textTransform: 'uppercase', color: 'rgba(13,23,38,0.45)', marginBottom: 6 }}>Last confirmed by server</div>
          <div style={{ fontFamily: KF.sans, fontSize: 12.5, lineHeight: 1.5, color: 'rgba(13,23,38,0.75)' }}>Game 2 · your turn 2 accepted · 12:42 — the unsent draft below is kept on this phone.</div>
        </div>
      </div>
      <div style={{ padding: '0 16px 24px' }}>
        <KTCta label="Retry now" color={OF.navy}></KTCta>
      </div>
    </KubbPhone>
  );
}

// ── 17. Out of sync / moved on ─────────────────────────────
function KTStale() {
  return (
    <KubbPhone>
      <KTNav back="Exit" title="Game 2 · Turn 3" trailing={<OfficialPill></OfficialPill>}></KTNav>
      <ScoreStrip ys={1} os={0} active="you"></ScoreStrip>
      <div style={{ flex: 1, padding: '0 16px', opacity: 0.5 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '14px 2px 8px' }}>
          <KubbEyebrow style={{ padding: 0, color: OF.blue }}>Your turn</KubbEyebrow>
          <MonoTag color={OF.blue} bg={OF.soft}>Round 3 · 6 batons</MonoTag>
        </div>
        <KubbCard>
          <Stepper label="8-meter throws" value={2} max={6}></Stepper>
          <Stepper label="Baseline kubbs hit" value={1} max={2} isLast></Stepper>
        </KubbCard>
      </div>
      <Sheet>
        <KubbEyebrow style={{ padding: 0, color: OF.blue }}>Match updated elsewhere</KubbEyebrow>
        <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 30, letterSpacing: -1.1, color: '#0D1726', marginTop: 8 }}>This match moved on</div>
        <div style={{ fontFamily: KF.sans, fontSize: 13.5, lineHeight: 1.55, color: 'rgba(13,23,38,0.65)', margin: '10px 0 16px' }}>A turn was entered from another device — the form you were editing is stale. We pulled the live state from kubbtracker.com; the kubb counts and baton limits below it have changed.</div>
        <KTCta label="Show the live state" color={OF.navy}></KTCta>
        <div style={{ textAlign: 'center', fontFamily: KF.sans, fontSize: 12, color: 'rgba(13,23,38,0.5)', padding: '13px 0 0' }}>Your draft was discarded — limits are recomputed every turn.</div>
      </Sheet>
    </KubbPhone>
  );
}

Object.assign(window, { KTHub, KTComplete, KTHistory, KTOffline, KTStale });
