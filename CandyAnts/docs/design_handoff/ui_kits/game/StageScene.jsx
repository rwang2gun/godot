// Stage scene — animated mock of ants walking + carrying candy
const { useState: useStateStage, useEffect: useEffectStage } = React;

function StageScene({ paused, onPick, onSave, onLost }) {
  const [t, setT] = useStateStage(0);
  useEffectStage(() => {
    if (paused) return;
    let id;
    const tick = () => { setT(v => v + 1); id = requestAnimationFrame(tick); };
    id = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(id);
  }, [paused]);

  // 6 ants in various phases. Position is t-driven, looped.
  const ants = Array.from({ length: 6 }, (_, i) => {
    const phase = ((t * 0.7 + i * 60) % 240) / 240;   // 0..1
    const carrying = phase > 0.5;
    // Walk right 0..0.5, walk left 0.5..1
    const x = carrying ? 200 + (1 - (phase - 0.5) * 2) * 760 : 200 + phase * 2 * 760;
    return { x, carrying, i };
  });

  // Bottom 132px is reserved for the skill toolbar band — stage sits entirely above it
  return (
    <div style={{
      position: 'absolute', left: 0, right: 0, top: 0, bottom: 132,
      background: `linear-gradient(180deg, var(--sky-300) 0%, oklch(0.93 0.06 145) 70%)`,
      overflow: 'hidden',
      borderBottom: '3px solid var(--ink)',
    }}>
      {/* sprinkle texture */}
      <svg style={{ position: 'absolute', inset: 0, opacity: 0.45 }} width="100%" height="100%">
        <defs>
          <pattern id="dots" width="44" height="44" patternUnits="userSpaceOnUse">
            <circle cx="10" cy="10" r="2.5" fill="oklch(1 0 0 / 0.6)"/>
            <circle cx="32" cy="30" r="1.8" fill="oklch(0.78 0.155 28 / 0.3)"/>
          </pattern>
        </defs>
        <rect width="100%" height="100%" fill="url(#dots)"/>
      </svg>

      {/* hills */}
      <svg style={{ position: 'absolute', inset: 0 }} viewBox="0 0 1200 600" preserveAspectRatio="none">
        <path d="M 0 440 Q 240 380 480 420 T 960 410 T 1200 430 L 1200 600 L 0 600 Z" fill="oklch(0.88 0.07 145)"/>
        <path d="M 0 480 Q 360 440 720 470 T 1200 480 L 1200 600 L 0 600 Z" fill="oklch(0.84 0.09 140)"/>
      </svg>

      {/* ground line */}
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 60, height: 6,
        background: 'var(--ink)',
      }}/>
      <div style={{
        position: 'absolute', left: 0, right: 0, bottom: 0, height: 60,
        background: 'oklch(0.78 0.10 80)',
      }}/>

      {/* home (left) */}
      <div style={{ position: 'absolute', left: 80, bottom: 40, animation: 'caBob 1.6s var(--ease-boop) infinite' }}>
        <img src="../../assets/sprites/home.svg" width="110" height="110"/>
      </div>

      {/* candy (right) */}
      <div style={{ position: 'absolute', right: 100, bottom: 66 }}>
        <img src="../../assets/sprites/candy.svg" width="150"/>
      </div>

      {/* ants */}
      {ants.map(a => (
        <div key={a.i} style={{
          position: 'absolute', left: a.x, bottom: 62,
          transform: a.carrying ? 'scaleX(-1)' : 'none',
          transition: 'none',
        }}>
          <img src={a.carrying ? '../../assets/sprites/ant_carrying.svg' : '../../assets/sprites/ant.svg'}
               width="56" height="56"/>
        </div>
      ))}

      {/* stage label chip */}
      <div style={{
        position: 'absolute', left: '50%', top: 24, transform: 'translateX(-50%)',
        padding: '8px 18px', background: 'var(--cream-100)',
        border: '3px solid var(--ink)', borderRadius: 999,
        boxShadow: 'var(--shadow-sticker-sm)',
        fontFamily: 'var(--font-display)', fontSize: 18,
      }}>Stage 1 · 첫 외출</div>
    </div>
  );
}

window.StageScene = StageScene;
