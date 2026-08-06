// Official KubbTracker — shared primitives. Accent = Color.Kubb.duskBlue (#33598B).
const OF = {
  blue: '#33598B',
  soft: 'rgba(51,89,139,0.10)',
  soft2: 'rgba(51,89,139,0.06)',
  line: 'rgba(51,89,139,0.25)',
  navy: '#13254A',
  gold: '#FECC02',
  goldInk: '#8A6700',
  green: '#1F6646',
  miss: '#C53030',
  birch: '#D5C8B5',
  field: '#F6F3EB',
};

function KTNav({ back = 'Game Tracker', title, trailing = null, dark = false }) {
  const t = useKT(dark);
  return (
    <div style={{ display: 'flex', alignItems: 'center', padding: '8px 16px 6px', height: 44, flexShrink: 0, position: 'relative' }}>
      <button style={{ all: 'unset', display: 'flex', alignItems: 'center', gap: 4, color: KT.swedishBlue, fontFamily: KF.sans, fontSize: 17, letterSpacing: -0.4, cursor: 'pointer', zIndex: 1 }}>
        <svg width="11" height="18" viewBox="0 0 11 18" fill="none"><path d="M9.5 1.5L2 9l7.5 7.5" stroke={KT.swedishBlue} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"></path></svg>
        <span>{back}</span>
      </button>
      <div style={{ position: 'absolute', left: 0, right: 0, textAlign: 'center', fontFamily: KF.sans, fontSize: 17, fontWeight: 600, color: t.text, letterSpacing: -0.4, pointerEvents: 'none' }}>{title}</div>
      <div style={{ marginLeft: 'auto', zIndex: 1 }}>{trailing}</div>
    </div>
  );
}

function OfficialPill({ solid = false, style = {} }) {
  return (
    <span style={{ fontFamily: KF.mono, fontSize: 9, fontWeight: 700, letterSpacing: 1.4, textTransform: 'uppercase', padding: '3px 8px 2px', borderRadius: 5, background: solid ? OF.blue : OF.soft, color: solid ? '#fff' : OF.blue, display: 'inline-block', ...style }}>Official</span>
  );
}

function MonoTag({ children, color, bg, style = {} }) {
  return (
    <span style={{ fontFamily: KF.mono, fontSize: 9, fontWeight: 700, letterSpacing: 1.2, textTransform: 'uppercase', padding: '3px 7px 2px', borderRadius: 5, background: bg ?? 'rgba(13,23,38,0.06)', color: color ?? 'rgba(13,23,38,0.62)', display: 'inline-block', ...style }}>{children}</span>
  );
}

function KTCta({ label, color = OF.navy, ink = '#fff', style = {} }) {
  return (
    <div style={{ height: 52, borderRadius: 14, background: color, color: ink, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: KF.sans, fontSize: 13, fontWeight: 800, letterSpacing: 1.1, textTransform: 'uppercase', boxShadow: `0 10px 20px -8px ${color}55`, ...style }}>{label}</div>
  );
}

function KTGhost({ label, color, style = {} }) {
  const c = color ?? 'rgba(13,23,38,0.62)';
  return (
    <div style={{ height: 48, borderRadius: 14, background: '#fff', border: '1px solid rgba(13,23,38,0.14)', color: c, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: KF.sans, fontSize: 13, fontWeight: 700, letterSpacing: 0.6, boxShadow: '0 1px 2px rgba(13,23,38,0.05)', ...style }}>{label}</div>
  );
}

// Compact score strip: names + games score + config
function ScoreStrip({ you = 'Scott', opp = 'Dave', ys = 0, os = 0, sub = 'Race to 2 · 1 vs 1', active = 'you' }) {
  const side = (name, mine, on) => (
    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: mine ? 'flex-start' : 'flex-end', gap: 2 }}>
      <div style={{ fontFamily: KF.sans, fontSize: 12, fontWeight: 700, letterSpacing: -0.2, color: on ? '#0D1726' : 'rgba(13,23,38,0.45)' }}>{name}</div>
      {on && <div style={{ width: 22, height: 3, borderRadius: 2, background: OF.blue }}></div>}
    </div>
  );
  return (
    <div style={{ margin: '4px 16px 0', padding: '10px 14px', background: '#fff', borderRadius: 14, boxShadow: '0 1px 2px rgba(13,23,38,0.04), 0 4px 14px rgba(13,23,38,0.05)', display: 'flex', alignItems: 'center', gap: 12 }}>
      {side(you, true, active === 'you')}
      <div style={{ textAlign: 'center' }}>
        <div style={{ fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 24, letterSpacing: -1, color: '#0D1726', lineHeight: 1 }}>{ys}<span style={{ color: 'rgba(13,23,38,0.3)', padding: '0 5px' }}>–</span>{os}</div>
        <div style={{ fontFamily: KF.mono, fontSize: 8.5, fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase', color: 'rgba(13,23,38,0.45)', marginTop: 3 }}>{sub}</div>
      </div>
      {side(opp, false, active === 'opp')}
    </div>
  );
}

// Stepper row — the workhorse of turn entry
function Stepper({ label, sub, value, max, accent = '#0D1726', dim = false, isLast = false }) {
  const btn = (glyph, off) => (
    <div style={{ width: 34, height: 34, borderRadius: 10, background: off ? 'rgba(13,23,38,0.04)' : OF.soft, color: off ? 'rgba(13,23,38,0.25)' : OF.blue, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: KF.sans, fontSize: 18, fontWeight: 600, flexShrink: 0 }}>{glyph}</div>
  );
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '10px 14px', borderBottom: isLast ? 'none' : '0.5px solid rgba(13,23,38,0.08)', opacity: dim ? 0.45 : 1 }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: KF.sans, fontSize: 14, fontWeight: 600, letterSpacing: -0.2, color: '#0D1726' }}>{label}</div>
        {sub && <div style={{ fontFamily: KF.mono, fontSize: 9, fontWeight: 700, letterSpacing: 0.8, textTransform: 'uppercase', color: 'rgba(13,23,38,0.42)', marginTop: 3 }}>{sub}</div>}
      </div>
      {btn('−', value === 0)}
      <div style={{ width: 34, textAlign: 'center', fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: 24, letterSpacing: -0.8, color: accent }}>{value}</div>
      {btn('+', max !== undefined && value >= max)}
    </div>
  );
}

function ToggleRow({ label, sub, on = false, tint = OF.blue, isLast = false }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '11px 14px', borderBottom: isLast ? 'none' : '0.5px solid rgba(13,23,38,0.08)' }}>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: KF.sans, fontSize: 14, fontWeight: 600, letterSpacing: -0.2, color: '#0D1726' }}>{label}</div>
        {sub && <div style={{ fontFamily: KF.sans, fontSize: 11.5, color: 'rgba(13,23,38,0.55)', marginTop: 3, lineHeight: 1.45 }}>{sub}</div>}
      </div>
      <KubbToggle on={on} tint={tint}></KubbToggle>
    </div>
  );
}

// Horizontal chip selector
function ChipRow({ options, value, wrap = true, style = {} }) {
  return (
    <div style={{ display: 'flex', flexWrap: wrap ? 'wrap' : 'nowrap', gap: 7, ...style }}>
      {options.map((o) => {
        const on = o === value;
        return <div key={o} style={{ padding: '7px 12px', borderRadius: 10, fontFamily: KF.sans, fontSize: 12.5, fontWeight: on ? 700 : 500, letterSpacing: -0.1, background: on ? OF.blue : '#fff', color: on ? '#fff' : 'rgba(13,23,38,0.7)', border: on ? `1px solid ${OF.blue}` : '1px solid rgba(13,23,38,0.12)', whiteSpace: 'nowrap' }}>{o}</div>;
      })}
    </div>
  );
}

// "Will record" receipt — previews the exact KubbTracker sentence
function Receipt({ children, style = {} }) {
  return (
    <div style={{ background: OF.soft2, border: `1px solid ${OF.line}`, borderRadius: 12, padding: '10px 12px', ...style }}>
      <div style={{ fontFamily: KF.mono, fontSize: 9, fontWeight: 700, letterSpacing: 1.4, textTransform: 'uppercase', color: OF.blue, marginBottom: 5 }}>Kubbtracker will record</div>
      <div style={{ fontFamily: KF.sans, fontSize: 12, lineHeight: 1.5, color: 'rgba(13,23,38,0.78)' }}>{children}</div>
    </div>
  );
}

// Pulsing "listening" indicator
function Listen({ label = 'Listening · checks every 6s' }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, justifyContent: 'center' }}>
      <span style={{ position: 'relative', width: 8, height: 8, flexShrink: 0 }}>
        <span style={{ position: 'absolute', inset: 0, borderRadius: 99, background: OF.blue }}></span>
        <span style={{ position: 'absolute', inset: -4, borderRadius: 99, border: `1.5px solid ${OF.blue}`, opacity: 0.35 }}></span>
      </span>
      <span style={{ fontFamily: KF.mono, fontSize: 9.5, fontWeight: 700, letterSpacing: 1.4, textTransform: 'uppercase', color: 'rgba(13,23,38,0.5)' }}>{label}</span>
    </div>
  );
}

// Play-by-play row (per-player turn counters, like the site)
function FeedRow({ turn, player, you = false, text, isLast = false, end = false }) {
  return (
    <div style={{ display: 'flex', gap: 11, padding: '10px 14px', borderBottom: isLast ? 'none' : '0.5px solid rgba(13,23,38,0.08)' }}>
      <div style={{ width: 26, height: 26, borderRadius: 8, background: end ? OF.gold : you ? OF.soft : 'rgba(13,23,38,0.05)', color: end ? OF.goldInk : you ? OF.blue : 'rgba(13,23,38,0.55)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: KF.mono, fontSize: 10.5, fontWeight: 700, flexShrink: 0, marginTop: 1 }}>{turn}</div>
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontFamily: KF.mono, fontSize: 9, fontWeight: 700, letterSpacing: 1, textTransform: 'uppercase', color: you ? OF.blue : 'rgba(13,23,38,0.5)' }}>{player}</div>
        <div style={{ fontFamily: KF.sans, fontSize: 12.5, lineHeight: 1.45, color: 'rgba(13,23,38,0.8)', marginTop: 2 }}>{text}</div>
      </div>
    </div>
  );
}

// Roster row with radio
function RosterRow({ name, pid, selected = false, isLast = false }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', borderBottom: isLast ? 'none' : '0.5px solid rgba(13,23,38,0.08)' }}>
      <div style={{ width: 20, height: 20, borderRadius: 99, border: selected ? `2px solid ${OF.blue}` : '1px solid rgba(13,23,38,0.25)', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>
        {selected && <div style={{ width: 10, height: 10, borderRadius: 99, background: OF.blue }}></div>}
      </div>
      <div style={{ flex: 1, fontFamily: KF.sans, fontSize: 15, fontWeight: selected ? 600 : 500, letterSpacing: -0.2, color: '#0D1726' }}>{name}</div>
      <div style={{ fontFamily: KF.mono, fontSize: 10, fontWeight: 700, letterSpacing: 0.8, color: 'rgba(13,23,38,0.4)' }}>#{pid}</div>
    </div>
  );
}

function SearchField({ value = '', placeholder = 'Search 137 players' }) {
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8, background: 'rgba(13,23,38,0.05)', borderRadius: 11, padding: '9px 12px' }}>
      <svg width="14" height="14" viewBox="0 0 24 24" fill="none"><circle cx="10.5" cy="10.5" r="7" stroke="rgba(13,23,38,0.4)" strokeWidth="2.4"></circle><path d="M16 16l5.5 5.5" stroke="rgba(13,23,38,0.4)" strokeWidth="2.4" strokeLinecap="round"></path></svg>
      <span style={{ fontFamily: KF.sans, fontSize: 14.5, color: value ? '#0D1726' : 'rgba(13,23,38,0.35)', letterSpacing: -0.2 }}>{value || placeholder}</span>
      {value && <span style={{ marginLeft: 'auto', width: 2, height: 17, background: OF.blue, borderRadius: 2 }}></span>}
    </div>
  );
}

// Avatar with initials
function Ava({ name, size = 40, color = OF.blue }) {
  const init = name.split(' ').map((w) => w[0]).slice(0, 2).join('');
  return (
    <div style={{ width: size, height: size, borderRadius: size * 0.32, background: color, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: KF.serif, fontStyle: 'italic', fontWeight: 500, fontSize: size * 0.4, letterSpacing: -0.5, flexShrink: 0 }}>{init}</div>
  );
}

// Bottom sheet overlay (for confirmation frames)
function Sheet({ children, tint = 'rgba(13,23,38,0.42)' }) {
  return (
    <div style={{ position: 'absolute', inset: 0, background: tint, display: 'flex', flexDirection: 'column', justifyContent: 'flex-end', zIndex: 40 }}>
      <div style={{ background: '#FAF8F3', borderRadius: '22px 22px 0 0', padding: '10px 20px 34px', boxShadow: '0 -8px 40px rgba(13,23,38,0.3)' }}>
        <div style={{ width: 36, height: 4.5, borderRadius: 3, background: 'rgba(13,23,38,0.15)', margin: '0 auto 16px' }}></div>
        {children}
      </div>
    </div>
  );
}

// Simple top-down field sketch (rects + circles only)
function FieldSketch({ opp = [1, 1, 0, 1, 0], you = [1, 1, 1, 1, 1], fieldYou = 2, fieldOpp = 0, oppName = 'Dave', youName = 'You' }) {
  const kubb = (up, key) => <div key={key} style={{ width: 13, height: 26, borderRadius: 3, background: up ? OF.birch : 'transparent', border: up ? '1px solid rgba(13,23,38,0.25)' : '1.5px dashed rgba(13,23,38,0.18)', opacity: up ? 1 : 0.7 }}></div>;
  const lbl = (s) => <div style={{ fontFamily: KF.mono, fontSize: 8.5, fontWeight: 700, letterSpacing: 1.2, textTransform: 'uppercase', color: 'rgba(13,23,38,0.45)', textAlign: 'center' }}>{s}</div>;
  const fieldDots = (n) => (
    <div style={{ display: 'flex', gap: 8, justifyContent: 'center', minHeight: 20, alignItems: 'center' }}>
      {Array.from({ length: n }).map((_, i) => <div key={i} style={{ width: 11, height: 20, borderRadius: 3, background: OF.birch, border: '1px solid rgba(13,23,38,0.25)', transform: `rotate(${i % 2 ? 8 : -6}deg)` }}></div>)}
      {n === 0 && <div style={{ fontFamily: KF.mono, fontSize: 8, letterSpacing: 1, color: 'rgba(13,23,38,0.25)' }}>CLEAR</div>}
    </div>
  );
  return (
    <div style={{ background: OF.field, border: '1px solid rgba(13,23,38,0.08)', borderRadius: 16, padding: '14px 16px', display: 'flex', flexDirection: 'column', gap: 9 }}>
      {lbl(`${oppName} · ${opp.filter(Boolean).length} standing`)}
      <div style={{ display: 'flex', gap: 18, justifyContent: 'center' }}>{opp.map((u, i) => kubb(u, i))}</div>
      {fieldDots(fieldOpp)}
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
        <div style={{ flex: 1, height: 1, background: 'rgba(13,23,38,0.1)' }}></div>
        <div style={{ width: 16, height: 32, borderRadius: 4, background: OF.gold, border: '1px solid rgba(13,23,38,0.2)' }}></div>
        <div style={{ flex: 1, height: 1, background: 'rgba(13,23,38,0.1)' }}></div>
      </div>
      {fieldDots(fieldYou)}
      <div style={{ display: 'flex', gap: 18, justifyContent: 'center' }}>{you.map((u, i) => kubb(u, i))}</div>
      {lbl(`${youName} · ${you.filter(Boolean).length} standing`)}
    </div>
  );
}

Object.assign(window, { OF, KTNav, OfficialPill, MonoTag, KTCta, KTGhost, ScoreStrip, Stepper, ToggleRow, ChipRow, Receipt, Listen, FeedRow, RosterRow, SearchField, Ava, Sheet, FieldSketch });
