// Official KubbTracker — waiting-for-opponent variations.

function WaitShell({ children }) {
  return (
    <KubbPhone>
      <KTNav back="Exit" title="Game 2" trailing={<OfficialPill></OfficialPill>}></KTNav>
      <ScoreStrip ys={1} os={0} active="opp"></ScoreStrip>
      <div style={{ flex: 1, overflow: 'hidden', padding: '0 16px', display: 'flex', flexDirection: 'column' }}>{children}</div>
    </KubbPhone>
  );
}

// ── A. The Field — live board sketch ───────────────────────
function KTWaitField() {
  return (
    <WaitShell>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', margin: '14px 2px 8px' }}>
        <KubbEyebrow style={{ padding: 0 }}>Dave is throwing</KubbEyebrow>
        <Listen label="Every 6s"></Listen>
      </div>
      <FieldSketch opp={[1, 0, 1, 1, 0]} you={[1, 1, 1, 1, 1]} fieldYou={2} fieldOpp={0} oppName="Dave — throwing" youName="You"></FieldSketch>
      <KubbEyebrow style={{ margin: '14px 0 8px' }}>Last action</KubbEyebrow>
      <KubbCard>
        <FeedRow turn="2" player="Scott Thompson · You" you text="4 eight-meter throws, hit 3 baseline kubbs. Advantage line 2 ft." isLast></FeedRow>
      </KubbCard>
      <div style={{ marginTop: 'auto', paddingBottom: 26, textAlign: 'center' }}>
        <div style={{ fontFamily: KF.sans, fontSize: 12, color: 'rgba(13,23,38,0.5)', lineHeight: 1.5 }}>You'll get a chime the moment it's your turn.<br></br>Feel free to lock your phone.</div>
      </div>
    </WaitShell>
  );
}

// ── B. Quiet — hero + one sentence ─────────────────────────
function KTWaitQuiet() {
  return (
    <WaitShell>
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', textAlign: 'center' }}>
        <div style={{ margin: '0 auto' }}><Ava name="Dave Akin" size={64} color="#7C6FA0"></Ava></div>
        <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 34, letterSpacing: -1.3, color: '#0D1726', marginTop: 18, lineHeight: 1.12 }}>Dave is throwing</div>
        <div style={{ marginTop: 12 }}><Listen></Listen></div>
        <div style={{ margin: '30px 12px 0', background: '#fff', borderRadius: 16, padding: '14px 16px', boxShadow: '0 1px 2px rgba(13,23,38,0.04), 0 4px 14px rgba(13,23,38,0.05)', textAlign: 'left' }}>
          <div style={{ fontFamily: KF.mono, fontSize: 9, fontWeight: 700, letterSpacing: 1.3, textTransform: 'uppercase', color: 'rgba(13,23,38,0.45)', marginBottom: 6 }}>While you wait — Dave gets</div>
          <div style={{ fontFamily: KF.sans, fontSize: 13, lineHeight: 1.55, color: 'rgba(13,23,38,0.75)' }}>4 batons · 2 field kubbs to clear on his side · your advantage line at <b>2 ft from the king</b>.</div>
        </div>
      </div>
      <div style={{ paddingBottom: 26, textAlign: 'center', fontFamily: KF.sans, fontSize: 12, color: 'rgba(13,23,38,0.5)' }}>Chime on · you can lock your phone</div>
    </WaitShell>
  );
}

// ── C. Play-by-play ticker ─────────────────────────────────
function KTWaitFeed() {
  return (
    <WaitShell>
      <div style={{ margin: '14px 0 0', background: OF.soft2, border: `1px dashed ${OF.line}`, borderRadius: 13, padding: '12px 14px', display: 'flex', alignItems: 'center', gap: 11 }}>
        <Ava name="Dave Akin" size={30} color="#7C6FA0"></Ava>
        <div style={{ flex: 1, fontFamily: KF.sans, fontSize: 13, fontWeight: 600, color: '#0D1726' }}>Dave is throwing…</div>
        <Listen label="6s"></Listen>
      </div>
      <KubbEyebrow style={{ margin: '16px 0 8px' }}>Play-by-play · newest first</KubbEyebrow>
      <KubbCard style={{ flex: 1, overflow: 'hidden' }}>
        <FeedRow turn="2" player="Scott Thompson · You" you text="4 eight-meter throws, hit 3 baseline kubbs (incl. a double). 1 field kubb left — advantage line 2 ft."></FeedRow>
        <FeedRow turn="2" player="Dave Akin" text="4 eight-meter throws and hit 2 baseline kubbs."></FeedRow>
        <FeedRow turn="1" player="Scott Thompson · You" you text="2 eight-meter throws and hit 2 baseline kubbs."></FeedRow>
        <FeedRow turn="1" player="Dave Akin" text="2 eight-meter throws and hit 1 baseline kubb." isLast></FeedRow>
      </KubbCard>
      <div style={{ padding: '12px 0 26px', textAlign: 'center', fontFamily: KF.sans, fontSize: 12, color: 'rgba(13,23,38,0.5)' }}>Turn counters are per player — you're both on turn 2.</div>
    </WaitShell>
  );
}

Object.assign(window, { WaitShell, KTWaitField, KTWaitQuiet, KTWaitFeed });
