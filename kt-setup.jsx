// Official KubbTracker — match setup: create, join, lobby, lag.

// ── 4. Create match ────────────────────────────────────────
function KTCreate() {
  return (
    <KubbPhone>
      <KTNav back="Back" title="New Official Match"></KTNav>
      <div style={{ padding: '8px 16px 0', flex: 1, display: 'flex', flexDirection: 'column' }}>
        <KubbEyebrow style={{ marginBottom: 8, color: OF.blue }}>Opponent</KubbEyebrow>
        <KubbCard>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 14px' }}>
            <Ava name="Dave Akin" size={36} color="#7C6FA0"></Ava>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: KF.sans, fontSize: 14.5, fontWeight: 600, letterSpacing: -0.2, color: '#0D1726' }}>Dave Akin</div>
              <div style={{ fontFamily: KF.mono, fontSize: 9.5, fontWeight: 700, letterSpacing: 1, color: 'rgba(13,23,38,0.45)', marginTop: 2 }}>PLAYER #87 · FROM THE ROSTER</div>
            </div>
            {ic.chevR('rgba(13,23,38,0.3)')}
          </div>
        </KubbCard>
        <KubbEyebrow style={{ margin: '16px 0 8px' }}>Match type</KubbEyebrow>
        <div style={{ display: 'flex', background: 'rgba(13,23,38,0.05)', borderRadius: 12, padding: 3 }}>
          {['1 vs 1', '2 vs 2', '3 vs 3'].map((o, i) => (
            <div key={o} style={{ flex: 1, textAlign: 'center', padding: '9px 0', borderRadius: 9, fontFamily: KF.sans, fontSize: 13, fontWeight: i === 0 ? 700 : 500, background: i === 0 ? '#fff' : 'transparent', color: i === 0 ? '#0D1726' : 'rgba(13,23,38,0.55)', boxShadow: i === 0 ? '0 1px 4px rgba(13,23,38,0.1)' : 'none' }}>{o}</div>
          ))}
        </div>
        <KubbEyebrow style={{ margin: '16px 0 8px' }}>Race to</KubbEyebrow>
        <ChipRow options={['1', '2', '3', '4', '5', 'Best of 5']} value="2"></ChipRow>
        <div style={{ fontFamily: KF.sans, fontSize: 11.5, color: 'rgba(13,23,38,0.45)', marginTop: 8, padding: '0 2px', lineHeight: 1.5 }}>First to 2 game wins takes the match. The lag is thrown once — first throw alternates every game after that.</div>
        <div style={{ marginTop: 'auto', paddingBottom: 24 }}>
          <Receipt style={{ marginBottom: 12 }}>Scott Thompson vs Dave Akin · 1 vs 1 · Race to 2 — a match link is created on kubbtracker.com to share with Dave.</Receipt>
          <KTCta label="Create match" color={OF.navy}></KTCta>
        </div>
      </div>
    </KubbPhone>
  );
}

// ── 5. Join with a link / match ID ─────────────────────────
function KTJoin() {
  return (
    <KubbPhone>
      <KTNav back="Back" title="Join a Match"></KTNav>
      <div style={{ padding: '8px 16px 0', flex: 1, display: 'flex', flexDirection: 'column' }}>
        <KubbEyebrow style={{ marginBottom: 8, color: OF.blue }}>Match link or ID</KubbEyebrow>
        <div style={{ display: 'flex', gap: 8 }}>
          <div style={{ flex: 1, background: '#fff', border: `1.5px solid ${OF.blue}`, borderRadius: 12, padding: '11px 13px', fontFamily: KF.mono, fontSize: 12.5, color: '#0D1726', overflow: 'hidden', whiteSpace: 'nowrap', textOverflow: 'ellipsis' }}>kubbtracker.com/match.php?matchid=1774</div>
          <div style={{ width: 74, borderRadius: 12, background: OF.soft, color: OF.blue, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: KF.sans, fontSize: 12.5, fontWeight: 700 }}>Paste</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, margin: '18px 0 8px' }}>
          <KubbEyebrow style={{ padding: 0 }}>Found match</KubbEyebrow>
          <MonoTag color={OF.green} bg="rgba(31,102,70,0.1)">Live</MonoTag>
        </div>
        <KubbCard style={{ padding: '16px 16px 14px' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 20, letterSpacing: -0.6, color: '#0D1726' }}>Scott Thompson <span style={{ color: 'rgba(13,23,38,0.35)', fontSize: 15 }}>vs</span> Dave Akin</div>
          </div>
          <div style={{ fontFamily: KF.mono, fontSize: 9.5, fontWeight: 700, letterSpacing: 1.1, color: 'rgba(13,23,38,0.45)', marginTop: 6 }}>MATCH #1774 · 1 VS 1 · RACE TO 2 · NOT STARTED</div>
          <div style={{ height: 1, background: 'rgba(13,23,38,0.07)', margin: '13px 0' }}></div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            <Ava name="Scott Thompson" size={30}></Ava>
            <div style={{ fontFamily: KF.sans, fontSize: 12.5, color: 'rgba(13,23,38,0.7)', lineHeight: 1.45 }}>You'll enter turns for <b style={{ color: '#0D1726' }}>Scott Thompson</b> — matched to your linked player.</div>
          </div>
        </KubbCard>
        <div style={{ background: OF.soft2, border: `1px solid ${OF.line}`, borderRadius: 12, padding: '10px 13px', marginTop: 12, fontFamily: KF.sans, fontSize: 11.5, lineHeight: 1.5, color: 'rgba(13,23,38,0.6)' }}>If your linked player isn't in a match, you can still open it as a <b>spectator</b> — watching only, no turn entry.</div>
        <div style={{ marginTop: 'auto', paddingBottom: 24 }}>
          <KTCta label="Join as Scott" color={OF.navy}></KTCta>
        </div>
      </div>
    </KubbPhone>
  );
}

// ── 6. Lobby — pre-match, share + start ────────────────────
function KTLobby() {
  return (
    <KubbPhone>
      <KTNav back="Exit" title="Match #1774" trailing={<OfficialPill></OfficialPill>}></KTNav>
      <div style={{ padding: '10px 16px 0', flex: 1, display: 'flex', flexDirection: 'column' }}>
        <KubbCard style={{ padding: '22px 18px', textAlign: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 18 }}>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, flex: 1 }}>
              <Ava name="Scott Thompson" size={54}></Ava>
              <div style={{ fontFamily: KF.sans, fontSize: 13.5, fontWeight: 700, letterSpacing: -0.2 }}>Scott Thompson</div>
              <MonoTag color={OF.blue} bg={OF.soft}>You</MonoTag>
            </div>
            <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontSize: 19, color: 'rgba(13,23,38,0.35)' }}>vs</div>
            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 8, flex: 1 }}>
              <Ava name="Dave Akin" size={54} color="#7C6FA0"></Ava>
              <div style={{ fontFamily: KF.sans, fontSize: 13.5, fontWeight: 700, letterSpacing: -0.2 }}>Dave Akin</div>
              <MonoTag>Opponent</MonoTag>
            </div>
          </div>
          <div style={{ fontFamily: KF.mono, fontSize: 9.5, fontWeight: 700, letterSpacing: 1.2, color: 'rgba(13,23,38,0.45)', marginTop: 18 }}>1 VS 1 · RACE TO 2 · FRIENDLIES</div>
        </KubbCard>
        <KubbEyebrow style={{ margin: '18px 0 8px' }}>Share with Dave</KubbEyebrow>
        <KubbCard>
          <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '11px 14px' }}>
            <div style={{ flex: 1, fontFamily: KF.mono, fontSize: 11.5, color: 'rgba(13,23,38,0.65)', overflow: 'hidden', whiteSpace: 'nowrap', textOverflow: 'ellipsis' }}>kubbtracker.com/match.php?matchid=1774</div>
            <div style={{ padding: '6px 12px', borderRadius: 9, background: OF.soft, color: OF.blue, fontFamily: KF.sans, fontSize: 12, fontWeight: 700 }}>Copy</div>
          </div>
        </KubbCard>
        <div style={{ fontFamily: KF.sans, fontSize: 11.5, color: 'rgba(13,23,38,0.45)', lineHeight: 1.5, padding: '10px 2px 0' }}>Dave can play from his own phone or any browser — the link is the whole login.</div>
        <div style={{ marginTop: 'auto', paddingBottom: 24 }}>
          <KTCta label="Start match" color={OF.navy}></KTCta>
          <div style={{ textAlign: 'center', fontFamily: KF.sans, fontSize: 12, color: 'rgba(13,23,38,0.5)', marginTop: 12 }}>Starting opens the lag — the king toss that decides who throws first.</div>
        </div>
      </div>
    </KubbPhone>
  );
}

// ── 7. Lag entry ───────────────────────────────────────────
function KTLag() {
  return (
    <KubbPhone>
      <KTNav back="Match" title="The Lag" trailing={<OfficialPill></OfficialPill>}></KTNav>
      <div style={{ padding: '6px 16px 0', flex: 1, display: 'flex', flexDirection: 'column' }}>
        <div style={{ fontFamily: KF.sans, fontSize: 13, color: 'rgba(13,23,38,0.6)', lineHeight: 1.5, padding: '0 2px' }}>Each side throws one baton at the king. Closest without knocking it starts Game 1.</div>
        <KubbEyebrow style={{ margin: '16px 0 8px', color: OF.blue }}>Your throw landed</KubbEyebrow>
        <KubbCard style={{ padding: '18px 16px', textAlign: 'center' }}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 18 }}>
            <div style={{ width: 40, height: 40, borderRadius: 12, background: OF.soft, color: OF.blue, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: KF.sans, fontSize: 21, fontWeight: 600 }}>−</div>
            <div>
              <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 52, letterSpacing: -2, color: '#0D1726', lineHeight: 1 }}>3<span style={{ fontSize: 22, letterSpacing: 0, marginLeft: 4, color: 'rgba(13,23,38,0.5)' }}>in</span></div>
              <div style={{ fontFamily: KF.mono, fontSize: 9, fontWeight: 700, letterSpacing: 1.3, textTransform: 'uppercase', color: 'rgba(13,23,38,0.45)', marginTop: 6 }}>From the king</div>
            </div>
            <div style={{ width: 40, height: 40, borderRadius: 12, background: OF.soft, color: OF.blue, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: KF.sans, fontSize: 21, fontWeight: 600 }}>+</div>
          </div>
          <div style={{ display: 'flex', gap: 7, justifyContent: 'center', marginTop: 16, flexWrap: 'wrap' }}>
            {['Touching the king', 'Not even close', 'Knocked the king'].map((o, i) => (
              <div key={o} style={{ padding: '7px 11px', borderRadius: 10, fontFamily: KF.sans, fontSize: 12, fontWeight: 500, border: '1px solid rgba(13,23,38,0.12)', color: i === 2 ? OF.miss : 'rgba(13,23,38,0.7)', background: '#fff' }}>{o}</div>
            ))}
          </div>
        </KubbCard>
        <KubbEyebrow style={{ margin: '16px 0 8px' }}>Dave's lag</KubbEyebrow>
        <KubbCard>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '13px 14px' }}>
            <Ava name="Dave Akin" size={32} color="#7C6FA0"></Ava>
            <div style={{ flex: 1, fontFamily: KF.sans, fontSize: 13, color: 'rgba(13,23,38,0.55)' }}>Not entered yet</div>
            <Listen label="Listening"></Listen>
          </div>
        </KubbCard>
        <div style={{ marginTop: 'auto', paddingBottom: 24 }}>
          <KTCta label="Lock in my lag" color={OF.navy}></KTCta>
          <div style={{ textAlign: 'center', fontFamily: KF.sans, fontSize: 12, color: 'rgba(13,23,38,0.5)', marginTop: 12 }}>Locked once sent — the game starts when both lags are in.</div>
        </div>
      </div>
    </KubbPhone>
  );
}

// ── 8. Lag result ──────────────────────────────────────────
function KTLagResult() {
  return (
    <KubbPhone>
      <KTNav back="Match" title="The Lag" trailing={<OfficialPill></OfficialPill>}></KTNav>
      <div style={{ padding: '6px 16px 0', flex: 1, display: 'flex', flexDirection: 'column' }}>
        <div style={{ flex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center', textAlign: 'center' }}>
          <div style={{ fontFamily: KF.mono, fontSize: 10, fontWeight: 700, letterSpacing: 1.8, textTransform: 'uppercase', color: OF.blue }}>Lag won</div>
          <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 40, letterSpacing: -1.6, color: '#0D1726', marginTop: 8, lineHeight: 1.1 }}>Dave throws first</div>
          <div style={{ display: 'flex', justifyContent: 'center', gap: 12, marginTop: 26 }}>
            {[{ n: 'Scott Thompson', v: '3 in', win: false, me: true }, { n: 'Dave Akin', v: '1 in', win: true }].map((p) => (
              <div key={p.n} style={{ width: 150, background: '#fff', borderRadius: 16, padding: '16px 12px', boxShadow: '0 1px 2px rgba(13,23,38,0.04), 0 4px 14px rgba(13,23,38,0.05)', border: p.win ? `1.5px solid ${OF.blue}` : '1px solid transparent' }}>
                <Ava name={p.n} size={40} color={p.me ? OF.blue : '#7C6FA0'}></Ava>
                <div style={{ fontFamily: KF.sans, fontSize: 12.5, fontWeight: 700, marginTop: 10, letterSpacing: -0.2 }}>{p.n}</div>
                <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 26, letterSpacing: -1, marginTop: 6, color: p.win ? OF.blue : 'rgba(13,23,38,0.45)' }}>{p.v}</div>
                <div style={{ fontFamily: KF.mono, fontSize: 8.5, fontWeight: 700, letterSpacing: 1.1, textTransform: 'uppercase', color: 'rgba(13,23,38,0.4)', marginTop: 3 }}>from the king</div>
              </div>
            ))}
          </div>
          <div style={{ fontFamily: KF.sans, fontSize: 12.5, color: 'rgba(13,23,38,0.55)', marginTop: 24, lineHeight: 1.55, padding: '0 24px' }}>The lag is thrown once per match. Game 2 flips to you, Game 3 back to Dave — first throw alternates from this result.</div>
        </div>
        <div style={{ paddingBottom: 24 }}>
          <KTCta label="Go to Game 1" color={OF.navy}></KTCta>
        </div>
      </div>
    </KubbPhone>
  );
}

Object.assign(window, { KTCreate, KTJoin, KTLobby, KTLag, KTLagResult });
