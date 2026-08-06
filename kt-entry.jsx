// Official KubbTracker — entry point + identity frames.

// ── 1. Game Tracker briefing with third mode ──────────────
function KTEntry() {
  const mode = (label, sub, sel, pill) => (
    <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start', padding: '12px 14px', borderBottom: '0.5px solid rgba(13,23,38,0.08)', background: sel ? OF.soft2 : 'transparent' }}>
      <div style={{ width: 20, height: 20, borderRadius: 99, border: sel ? `2px solid ${OF.blue}` : '1px solid rgba(13,23,38,0.25)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, marginTop: 1 }}>
        {sel && <div style={{ width: 10, height: 10, borderRadius: 99, background: OF.blue }}></div>}
      </div>
      <div style={{ flex: 1 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 7 }}>
          <span style={{ fontFamily: KF.sans, fontSize: 14, fontWeight: 600, letterSpacing: -0.2, color: '#0D1726' }}>{label}</span>
          {pill}
        </div>
        <div style={{ fontFamily: KF.sans, fontSize: 12, color: 'rgba(13,23,38,0.55)', marginTop: 2, lineHeight: 1.45 }}>{sub}</div>
      </div>
    </div>
  );
  return (
    <KubbPhone>
      <KTNav back="Cancel" title="Game Tracker" trailing={<span style={{ color: KT.swedishBlue }}>{ic.info}</span>}></KTNav>
      <div style={{ padding: '4px 16px 0', overflow: 'hidden', flex: 1, display: 'flex', flexDirection: 'column' }}>
        <div style={{ background: `linear-gradient(160deg, ${OF.soft} 0%, rgba(51,89,139,0.02) 70%)`, border: `1px solid ${OF.line}`, borderRadius: 18, padding: '18px 18px 16px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <KubbEyebrow style={{ padding: 0, color: OF.blue }}>Match play</KubbEyebrow>
            <OfficialPill></OfficialPill>
          </div>
          <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 30, letterSpacing: -1.1, color: '#0D1726', marginTop: 6, lineHeight: 1.08 }}>Log a real game</div>
          <div style={{ fontFamily: KF.sans, fontSize: 13, color: 'rgba(13,23,38,0.6)', marginTop: 7, lineHeight: 1.5 }}>Track a match turn by turn — solo, against an opponent, or live on kubbtracker.com.</div>
        </div>
        <KubbEyebrow style={{ margin: '18px 0 8px' }}>Mode</KubbEyebrow>
        <KubbCard>
          {mode('Phantom Game', 'Solo — play both sides, track your own field efficiency', false)}
          {mode('Competitive Match', 'Log a live game against an opponent turn by turn', false)}
          {mode('Official KubbTracker', 'Online vs a registered player — every turn syncs to kubbtracker.com', true, <OfficialPill></OfficialPill>)}
        </KubbCard>
        <KubbEyebrow style={{ margin: '16px 0 8px', color: OF.blue }}>Playing as</KubbEyebrow>
        <KubbCard>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 14px' }}>
            <Ava name="Scott Thompson" size={36}></Ava>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: KF.sans, fontSize: 14.5, fontWeight: 600, letterSpacing: -0.2, color: '#0D1726' }}>Scott Thompson</div>
              <div style={{ fontFamily: KF.mono, fontSize: 9.5, fontWeight: 700, letterSpacing: 1, color: 'rgba(13,23,38,0.45)', marginTop: 2 }}>KUBBTRACKER PLAYER #142</div>
            </div>
            {ic.chevR('rgba(13,23,38,0.3)')}
          </div>
        </KubbCard>
        <div style={{ marginTop: 'auto', paddingBottom: 24 }}>
          <KTCta label="Create official match" color={OF.navy}></KTCta>
          <KTGhost label="Join with a match link" style={{ marginTop: 10 }}></KTGhost>
        </div>
      </div>
    </KubbPhone>
  );
}

// ── 2. Identity — pick who you are from the roster ────────
function KTIdentityPick() {
  return (
    <KubbPhone>
      <KTNav back="Settings" title="KubbTracker Player"></KTNav>
      <div style={{ padding: '8px 16px 0', flex: 1, overflow: 'hidden' }}>
        <div style={{ fontFamily: KF.sans, fontSize: 13, color: 'rgba(13,23,38,0.6)', lineHeight: 1.5, padding: '0 2px 12px' }}>Official matches are played as a registered KubbTracker player. Pick yourself once — it's saved for every match.</div>
        <SearchField value="sco"></SearchField>
        <KubbCard style={{ marginTop: 12 }}>
          <RosterRow name="Scott Thompson" pid="142" selected></RosterRow>
          <RosterRow name="Scott Berger" pid="88"></RosterRow>
          <RosterRow name="Prescott Lane" pid="121" isLast></RosterRow>
        </KubbCard>
        <div style={{ background: 'rgba(254,204,2,0.12)', border: '1px solid rgba(138,103,0,0.2)', borderRadius: 12, padding: '11px 13px', marginTop: 14, display: 'flex', gap: 10 }}>
          <span style={{ color: '#8A6700', flexShrink: 0, marginTop: 1 }}>{ic.info}</span>
          <div style={{ fontFamily: KF.sans, fontSize: 12, lineHeight: 1.5, color: 'rgba(13,23,38,0.7)' }}>The roster is managed on kubbtracker.com — there's no self-signup. Don't see yourself? <span style={{ fontWeight: 700, color: '#8A6700' }}>Ask Dave to add you</span>, then pull to refresh.</div>
        </div>
      </div>
      <div style={{ padding: '0 16px 24px' }}>
        <KTCta label="This is me" color={OF.navy}></KTCta>
      </div>
    </KubbPhone>
  );
}

// ── 3. Identity — linked state in Settings ────────────────
function KTIdentityLinked() {
  return (
    <KubbPhone>
      <KTNav back="Settings" title="KubbTracker"></KTNav>
      <div style={{ padding: '8px 16px 0', flex: 1 }}>
        <KubbCard style={{ padding: '18px 16px', display: 'flex', alignItems: 'center', gap: 14 }}>
          <Ava name="Scott Thompson" size={52}></Ava>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 21, letterSpacing: -0.6, color: '#0D1726' }}>Scott Thompson</div>
            <div style={{ fontFamily: KF.mono, fontSize: 9.5, fontWeight: 700, letterSpacing: 1.1, color: 'rgba(13,23,38,0.45)', marginTop: 4 }}>PLAYER #142 · LINKED</div>
          </div>
          <span style={{ color: OF.green }}>{ic.check}</span>
        </KubbCard>
        <KubbEyebrow style={{ margin: '18px 0 8px' }}>Match defaults</KubbEyebrow>
        <KubbCard>
          <KubbRow label="Match type" detail="1 vs 1" chevron></KubbRow>
          <KubbRow label="Race to" detail="2 games" chevron></KubbRow>
          <div style={{ padding: '0 0' }}>
            <ToggleRow label="Chime when it's my turn" sub="Plays a sound when the opponent finishes" on tint={OF.blue} isLast></ToggleRow>
          </div>
        </KubbCard>
        <KubbEyebrow style={{ margin: '18px 0 8px' }}>Account</KubbEyebrow>
        <KubbCard>
          <KubbRow label="View my page on kubbtracker.com" chevron></KubbRow>
          <div style={{ padding: '13px 16px', fontFamily: KF.sans, fontSize: 15, fontWeight: 500, color: OF.miss, letterSpacing: -0.2 }}>Unlink player</div>
        </KubbCard>
        <div style={{ fontFamily: KF.sans, fontSize: 11.5, color: 'rgba(13,23,38,0.45)', lineHeight: 1.5, padding: '12px 4px 0' }}>Anyone with a match link can view it — KubbTracker has no accounts or passwords. Your link only decides which side you enter turns for.</div>
      </div>
    </KubbPhone>
  );
}

Object.assign(window, { KTEntry, KTIdentityPick, KTIdentityLinked });
