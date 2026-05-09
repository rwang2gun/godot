// HUD — top counters + time + release rate
const { useState: useStateHud } = React;

function HUD({ candyHP, inTransit, saved, lost, time, releaseRate, onRateChange, onPause, paused }) {
  return (
    <>
      {/* top-left counters */}
      <div style={{
        position: 'absolute', top: 24, left: 24, display: 'flex', gap: 10,
      }}>
        <Counter label="candy hp"  koLabel="사탕 HP"  value={candyHP}  color="var(--c-candy-hp)" animateKey={candyHP}/>
        <Counter label="in transit" koLabel="운반 중"  value={inTransit} color="var(--c-in-transit)" animateKey={inTransit}/>
        <Counter label="saved"     koLabel="귀가"     value={saved}    color="var(--c-saved)" animateKey={saved}/>
        <Counter label="lost"      koLabel="잃음"     value={lost}     color="var(--c-lost)" animateKey={lost}/>
      </div>

      {/* top-right time + rate + pause */}
      <div style={{
        position: 'absolute', top: 24, right: 24, display: 'flex', gap: 10, alignItems: 'flex-start',
      }}>
        <Counter label="time" koLabel="남은 시간" value={time} color="var(--c-time)" animateKey={Math.floor(time/5)}/>
        <div style={{
          background: 'var(--surface)', border: '3px solid var(--ink)',
          borderRadius: 'var(--r-lg)', boxShadow: 'var(--shadow-sticker-sm)',
          padding: '10px 14px', minWidth: 160,
        }}>
          <div style={{
            fontFamily: 'var(--font-display)', fontSize: 12,
            color: 'var(--fg-muted)', textTransform: 'uppercase',
          }}>release rate · 출구 속도</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 4 }}>
            <button onClick={() => onRateChange(Math.max(1, releaseRate - 5))}
              style={rateBtn}>−</button>
            <div style={{ fontFamily: 'var(--font-display)', fontSize: 24, color: 'var(--ink)', minWidth: 36, textAlign: 'center' }}>{releaseRate}</div>
            <button onClick={() => onRateChange(Math.min(99, releaseRate + 5))}
              style={rateBtn}>+</button>
          </div>
        </div>
        <button onClick={onPause} style={{
          width: 56, height: 56, border: '3px solid var(--ink)', borderRadius: 'var(--r-lg)',
          background: paused ? 'var(--mint-500)' : 'var(--cream-100)',
          boxShadow: 'var(--shadow-sticker-sm), var(--gloss)',
          fontFamily: 'var(--font-display)', fontSize: 22, cursor: 'pointer',
        }}>{paused ? '▶' : 'II'}</button>
      </div>
    </>
  );
}

const rateBtn = {
  width: 28, height: 28, border: '2px solid var(--ink)', borderRadius: 8,
  background: 'var(--cream-100)', fontFamily: 'var(--font-display)', fontSize: 16, cursor: 'pointer',
  boxShadow: 'var(--shadow-sticker-sm)',
};

window.HUD = HUD;
