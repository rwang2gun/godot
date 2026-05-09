// CandyAnts UI Kit — shared atoms (buttons, chips, counters, skill slot)
// Plain in-browser Babel JSX. Components attach to window for cross-script use.

const { useState } = React;

function Button({ kind = 'primary', size = 'md', children, onClick, disabled }) {
  const [pressed, setPressed] = useState(false);
  const palette = {
    primary:   { bg: 'var(--peach-500)', fg: 'var(--ink)' },
    secondary: { bg: 'var(--cream-100)', fg: 'var(--ink)' },
    success:   { bg: 'var(--mint-500)',  fg: 'var(--ink)' },
    danger:    { bg: 'var(--berry-500)', fg: '#fff' },
    ghost:     { bg: 'transparent',      fg: 'var(--ink)' },
  }[kind];
  const sizes = {
    sm: { padding: '6px 14px', fontSize: 14 },
    md: { padding: '10px 22px', fontSize: 18 },
    lg: { padding: '14px 28px', fontSize: 22 },
  }[size];
  return (
    <button
      onMouseDown={() => setPressed(true)}
      onMouseUp={() => setPressed(false)}
      onMouseLeave={() => setPressed(false)}
      onClick={onClick}
      disabled={disabled}
      style={{
        fontFamily: 'var(--font-display)',
        ...sizes,
        background: palette.bg,
        color: palette.fg,
        border: '3px solid var(--ink)',
        borderRadius: 'var(--r-lg)',
        boxShadow: pressed
          ? 'var(--shadow-sticker-sm), var(--gloss-press)'
          : 'var(--shadow-sticker), var(--gloss)',
        transform: pressed ? 'translate(2px,2px)' : 'translate(0,0)',
        transition: 'transform 120ms var(--ease-boop), box-shadow 120ms',
        cursor: disabled ? 'not-allowed' : 'pointer',
        opacity: disabled ? 0.5 : 1,
        filter: disabled ? 'saturate(.5)' : 'none',
      }}
    >
      {children}
    </button>
  );
}

function Chip({ color = 'var(--peach-500)', children }) {
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '4px 12px', background: color, color: 'var(--ink)',
      border: '3px solid var(--ink)', borderRadius: 999,
      fontFamily: 'var(--font-display)', fontSize: 14,
      boxShadow: 'var(--shadow-sticker-sm)',
    }}>{children}</span>
  );
}

function Counter({ label, koLabel, value, color, animateKey }) {
  return (
    <div style={{
      background: 'var(--surface)', border: '3px solid var(--ink)',
      borderRadius: 'var(--r-lg)', boxShadow: 'var(--shadow-sticker-sm)',
      padding: '10px 14px', minWidth: 92, textAlign: 'left',
    }}>
      <div style={{
        fontFamily: 'var(--font-display)', fontSize: 12,
        color: 'var(--fg-muted)', textTransform: 'uppercase', letterSpacing: '.04em',
      }}>
        <span style={{
          display: 'inline-block', width: 10, height: 10, borderRadius: 999,
          background: color, border: '2px solid var(--ink)',
          verticalAlign: 'middle', marginRight: 6,
        }}/>{label}
      </div>
      <div key={animateKey} style={{
        fontFamily: 'var(--font-display)', fontSize: 32, lineHeight: 1, color,
        animation: 'caPop 220ms var(--ease-boop)',
      }}>{value}</div>
      <div style={{ fontFamily: 'var(--font-display)', fontSize: 11, color: 'var(--fg-muted)' }}>{koLabel}</div>
    </div>
  );
}

function SkillSlot({ icon, name, count, selected, onClick, hotkey }) {
  const empty = count <= 0;
  return (
    <button onClick={onClick} disabled={empty} style={{
      width: 88, height: 88, padding: 0, position: 'relative', cursor: empty ? 'not-allowed' : 'pointer',
      background: selected ? 'var(--peach-300)' : 'var(--cream-100)',
      border: '3px solid var(--ink)', borderRadius: 'var(--r-lg)',
      boxShadow: selected ? 'var(--shadow-sticker), var(--gloss), 0 0 0 3px var(--mint-500)'
                          : 'var(--shadow-sticker-sm), var(--gloss)',
      filter: empty ? 'saturate(.3) opacity(.55)' : 'none',
      transition: 'transform 120ms var(--ease-boop), box-shadow 120ms',
    }}>
      <img src={icon} alt={name} style={{ width: 56, height: 56 }}/>
      <span style={{
        position: 'absolute', right: -6, top: -8, background: empty ? 'var(--ink-500)' : 'var(--ink)',
        color: '#fff', fontFamily: 'var(--font-display)', fontSize: 13,
        padding: '2px 8px', borderRadius: 999, border: '2px solid var(--cream-50)',
      }}>{count}</span>
      {hotkey && (
        <span style={{
          position: 'absolute', left: 4, top: 4, fontSize: 10, fontFamily: 'JetBrains Mono, monospace',
          color: 'var(--fg-muted)', background: 'oklch(1 0 0 / .7)', padding: '0 4px', borderRadius: 4,
        }}>{hotkey}</span>
      )}
      <span style={{
        position: 'absolute', left: 0, right: 0, bottom: -18,
        fontFamily: 'var(--font-display)', fontSize: 11, color: 'var(--fg-muted)',
      }}>{name}</span>
    </button>
  );
}

Object.assign(window, { Button, Chip, Counter, SkillSlot });
