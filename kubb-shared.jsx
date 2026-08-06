// Shared tokens + primitives for Kubb Coach settings redesign.

const KT = {
  // light
  paper: '#FAF8F3',
  paper2: '#EEECE4',
  card: '#FFFFFF',
  hero: '#0D1726',
  text: '#0D1726',
  textSec: 'rgba(13,23,38,0.62)',
  textTer: 'rgba(13,23,38,0.38)',
  sep: 'rgba(13,23,38,0.08)',
  sepStrong: 'rgba(13,23,38,0.14)',
  // dark
  paperD: '#111418',
  paper2D: '#1A1C22',
  cardD: '#1C2028',
  textD: '#F2EEE5',
  textSecD: 'rgba(242,238,229,0.62)',
  textTerD: 'rgba(242,238,229,0.35)',
  sepD: 'rgba(255,255,255,0.08)',
  // brand
  swedishBlue: '#006AA7',
  swedishGold: '#FECC02',
  forestGreen: '#59A44D',
  phase4m: '#E08E27',
  phasePC: '#C0392B',
  phaseGT: '#7C6FA0',
};

const KF = {
  serif: '"Fraunces", "Fraunces 72pt", Georgia, serif',
  sans: '"Inter", -apple-system, system-ui, sans-serif',
  mono: '"JetBrains Mono", ui-monospace, "SF Mono", monospace',
};

// Theme helper
function useKT(dark) {
  return {
    paper: dark ? KT.paperD : KT.paper,
    paper2: dark ? KT.paper2D : KT.paper2,
    card: dark ? KT.cardD : KT.card,
    text: dark ? KT.textD : KT.text,
    textSec: dark ? KT.textSecD : KT.textSec,
    textTer: dark ? KT.textTerD : KT.textTer,
    sep: dark ? KT.sepD : KT.sep,
    sepStrong: dark ? 'rgba(255,255,255,0.16)' : KT.sepStrong,
    hero: KT.hero,
  };
}

// ─── Phone frame ────────────────────────────────────────────
function KubbPhone({ dark = false, bg, children, width = 393, height = 852 }) {
  const t = useKT(dark);
  return (
    <IOSDevice width={width} height={height} dark={dark}>
      <div style={{
        position: 'absolute', inset: 0,
        background: bg ?? t.paper,
        display: 'flex', flexDirection: 'column',
        fontFamily: KF.sans, color: t.text,
      }}>
        <IOSStatusBar dark={dark} />
        <div style={{ flex: 1, overflow: 'hidden', position: 'relative' }}>{children}</div>
      </div>
    </IOSDevice>
  );
}

// ─── Inline nav (back + centered title) ─────────────────────
function KubbInlineNav({ title, dark = false, trailing = null }) {
  const t = useKT(dark);
  return (
    <div style={{
      display: 'flex', alignItems: 'center', justifyContent: 'space-between',
      padding: '8px 16px 6px', height: 44, flexShrink: 0,
    }}>
      <button style={{
        all: 'unset', display: 'flex', alignItems: 'center', gap: 4,
        color: KT.swedishBlue, fontFamily: KF.sans, fontSize: 17, letterSpacing: -0.4,
        cursor: 'pointer',
      }}>
        <svg width="11" height="18" viewBox="0 0 11 18" fill="none">
          <path d="M9.5 1.5L2 9l7.5 7.5" stroke={KT.swedishBlue} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
        <span>Settings</span>
      </button>
      <div style={{
        position: 'absolute', left: 0, right: 0, textAlign: 'center',
        fontFamily: KF.sans, fontSize: 17, fontWeight: 600, color: t.text,
        letterSpacing: -0.4, pointerEvents: 'none',
      }}>{title}</div>
      <div style={{ minWidth: 60, textAlign: 'right' }}>{trailing}</div>
    </div>
  );
}

// ─── Large title nav (for Settings root) ────────────────────
function KubbLargeTitle({ title, eyebrow, dark = false }) {
  const t = useKT(dark);
  return (
    <div style={{ padding: '8px 20px 12px', flexShrink: 0 }}>
      {eyebrow && (
        <div style={{
          fontFamily: KF.mono, fontSize: 10, fontWeight: 700,
          letterSpacing: 1.8, textTransform: 'uppercase',
          color: t.textSec, marginBottom: 6,
        }}>{eyebrow}</div>
      )}
      <div style={{
        fontFamily: KF.serif, fontSize: 36, fontWeight: 500,
        letterSpacing: -1.1, color: t.text, lineHeight: 1.05,
      }}>{title}</div>
    </div>
  );
}

// ─── Section eyebrow (mono uppercase) ───────────────────────
function KubbEyebrow({ children, dark = false, style = {} }) {
  const t = useKT(dark);
  return (
    <div style={{
      fontFamily: KF.mono, fontSize: 10, fontWeight: 700,
      letterSpacing: 1.8, textTransform: 'uppercase',
      color: t.textSec, padding: '0 4px',
      ...style,
    }}>{children}</div>
  );
}

// ─── Card container ─────────────────────────────────────────
function KubbCard({ children, dark = false, style = {} }) {
  const t = useKT(dark);
  return (
    <div style={{
      background: t.card, borderRadius: 16,
      boxShadow: dark
        ? '0 1px 2px rgba(0,0,0,0.4), 0 4px 14px rgba(0,0,0,0.18)'
        : '0 1px 2px rgba(13,23,38,0.04), 0 4px 14px rgba(13,23,38,0.05)',
      overflow: 'hidden',
      ...style,
    }}>{children}</div>
  );
}

// ─── Settings row ───────────────────────────────────────────
function KubbRow({ label, sub, detail, iconBg, icon, dark = false, chevron = true, isLast = false, accent }) {
  const t = useKT(dark);
  return (
    <div style={{
      display: 'flex', alignItems: 'center', gap: 12,
      padding: '12px 16px', minHeight: 56,
      borderBottom: isLast ? 'none' : `0.5px solid ${t.sep}`,
      position: 'relative',
    }}>
      {iconBg !== undefined && (
        <div style={{
          width: 32, height: 32, borderRadius: 8,
          background: iconBg, flexShrink: 0,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: '#fff',
        }}>
          {icon}
        </div>
      )}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{
          fontFamily: KF.sans, fontSize: 15, fontWeight: 500,
          color: t.text, letterSpacing: -0.2,
        }}>{label}</div>
        {sub && (
          <div style={{
            fontFamily: KF.mono, fontSize: 10, fontWeight: 700,
            letterSpacing: 0.6, color: accent ?? t.textSec, marginTop: 3,
            textTransform: 'uppercase',
          }}>{sub}</div>
        )}
      </div>
      {detail && (
        <div style={{
          fontFamily: KF.sans, fontSize: 14, color: t.textSec, letterSpacing: -0.2,
        }}>{detail}</div>
      )}
      {chevron && (
        <svg width="7" height="12" viewBox="0 0 7 12" style={{ flexShrink: 0 }}>
          <path d="M1 1l5 5-5 5" stroke={t.textTer} strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
      )}
    </div>
  );
}

// ─── Toggle (iOS-style switch) ──────────────────────────────
function KubbToggle({ on = false, tint = KT.forestGreen, dark = false }) {
  return (
    <div style={{
      width: 51, height: 31, borderRadius: 999,
      background: on ? tint : (dark ? 'rgba(120,120,128,0.32)' : 'rgba(120,120,128,0.16)'),
      position: 'relative', transition: 'background 0.2s', flexShrink: 0,
    }}>
      <div style={{
        position: 'absolute', top: 2, left: on ? 22 : 2,
        width: 27, height: 27, borderRadius: 999,
        background: '#fff',
        boxShadow: '0 3px 8px rgba(0,0,0,0.15), 0 1px 1px rgba(0,0,0,0.06)',
        transition: 'left 0.2s',
      }}/>
    </div>
  );
}

// ─── Icons (inline SVG) ─────────────────────────────────────
const ic = {
  scope: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2"/><circle cx="12" cy="12" r="3" fill="currentColor"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>,
  envelope: <svg width="16" height="13" viewBox="0 0 24 19" fill="none"><rect x="1" y="1" width="22" height="17" rx="2.5" stroke="currentColor" strokeWidth="2"/><path d="M2 4l10 7 10-7" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  trophy: <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M7 4h10v3a5 5 0 0 1-10 0V4zM4 5h3v2a3 3 0 0 1-3-3V5zm13 0h3v0a3 3 0 0 1-3 3V5zM10 14h4v3l2 1v2H8v-2l2-1v-3z"/></svg>,
  speaker: <svg width="16" height="14" viewBox="0 0 22 19" fill="none"><path d="M3 7h3l5-4v13l-5-4H3V7z" fill="currentColor"/><path d="M14 6c1.5 1 2 2.3 2 4s-0.5 3-2 4M16.5 3c2.5 1.7 3.5 4 3.5 7s-1 5.3-3.5 7" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round"/></svg>,
  drive: <svg width="16" height="14" viewBox="0 0 24 20" fill="none"><rect x="2" y="2" width="20" height="16" rx="3" stroke="currentColor" strokeWidth="2"/><circle cx="6" cy="14" r="1.4" fill="currentColor"/><path d="M2 10h20" stroke="currentColor" strokeWidth="1.5"/></svg>,
  wrench: <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M14.7 6.3a4 4 0 1 0 3 3l5 5-3 3-5-5a4 4 0 0 0-3-3l4 4-2 2-4-4 1-1z"/></svg>,
  sun: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="4" fill="currentColor"/><path d="M12 2v2M12 20v2M4 12H2M22 12h-2M5 5l1.4 1.4M17.6 17.6L19 19M5 19l1.4-1.4M17.6 6.4L19 5" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>,
  haptic: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><rect x="8" y="3" width="8" height="18" rx="2" stroke="currentColor" strokeWidth="2"/><path d="M3 9l2 3-2 3M21 9l-2 3 2 3" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  info: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2"/><circle cx="12" cy="8" r="1.2" fill="currentColor"/><path d="M12 11v6" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>,
  ruler: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M2 16L16 2l6 6L8 22 2 16z" stroke="currentColor" strokeWidth="2" strokeLinejoin="round"/><path d="M6 12l2 2M9 9l2 2M12 6l2 2" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round"/></svg>,
  cloud: <svg width="16" height="13" viewBox="0 0 24 19" fill="none"><path d="M7 16a4 4 0 0 1-1-7.8 6 6 0 0 1 11.6 1A4.5 4.5 0 0 1 17 17H7z" stroke="currentColor" strokeWidth="2" strokeLinejoin="round"/></svg>,
  chevR: (c, s = 12) => <svg width={s*0.6} height={s} viewBox="0 0 7 12" fill="none"><path d="M1 1l5 5-5 5" stroke={c} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" fill="none"/></svg>,
  check: <svg width="14" height="14" viewBox="0 0 14 14" fill="none"><path d="M2 7l3.5 3.5L12 3.5" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  pin: <svg width="11" height="11" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l2 6h6l-5 4 2 8-5-4-5 4 2-8-5-4h6z"/></svg>,
  plus: <svg width="14" height="14" viewBox="0 0 14 14"><path d="M7 2v10M2 7h10" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>,
  flame: <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2c-1 4 3 5 3 9a3 3 0 0 1-6 0c0-1.5.7-2 1-3-3 1-5 4-5 7a7 7 0 1 0 14 0c0-7-6-9-7-13z"/></svg>,
  trash: <svg width="14" height="16" viewBox="0 0 14 16" fill="none"><path d="M2 4h10M5 4V2h4v2M3 4l1 11h6l1-11" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  eye: <svg width="16" height="12" viewBox="0 0 24 16" fill="none"><path d="M1 8s4-7 11-7 11 7 11 7-4 7-11 7S1 8 1 8z" stroke="currentColor" strokeWidth="2"/><circle cx="12" cy="8" r="3" fill="currentColor"/></svg>,
};

// Phase icons mirror SF symbols used in app
const phaseIcon = {
  eightMeters: ic.scope,
  fourMeters: <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2c-1 4 3 5 3 9a3 3 0 0 1-6 0c0-1.5.7-2 1-3-3 1-5 4-5 7a7 7 0 1 0 14 0c0-7-6-9-7-13z"/></svg>,
  inkasting: <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2L4 14h6l-2 8 10-14h-6l2-6z"/></svg>,
  pressureCooker: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><circle cx="12" cy="12" r="9" stroke="currentColor" strokeWidth="2"/><path d="M12 5v7l4 3" stroke="currentColor" strokeWidth="2" strokeLinecap="round"/></svg>,
  gameTracker: <svg width="16" height="16" viewBox="0 0 24 24" fill="none"><path d="M5 3v18M5 4h11l-2 4 2 4H5" stroke="currentColor" strokeWidth="2" strokeLinejoin="round"/></svg>,
};

Object.assign(window, { KT, KF, useKT, KubbPhone, KubbInlineNav, KubbLargeTitle, KubbEyebrow, KubbCard, KubbRow, KubbToggle, ic, phaseIcon });
