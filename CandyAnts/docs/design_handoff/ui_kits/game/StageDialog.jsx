// Win/loss dialog + level select card
function StageDialog({ open, success, score, onRetry, onNext, onClose }) {
  if (!open) return null;
  return (
    <div style={{
      position: 'absolute', inset: 0, zIndex: 100,
      background: 'oklch(0.30 0.04 30 / 0.55)', backdropFilter: 'blur(6px)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
    }}>
      <div style={{
        background: 'var(--surface)', border: '3px solid var(--ink)',
        borderRadius: 'var(--r-2xl)', boxShadow: 'var(--shadow-sticker-lg)',
        padding: 32, width: 480, textAlign: 'center',
        animation: 'caPop 320ms var(--ease-boop)',
      }}>
        <h3 style={{ fontFamily: 'var(--font-display)', fontSize: 36, color: 'var(--ink)', margin: 0 }}>
          {success ? '사탕을 무사히 옮겼어요!' : '사탕이 부족했어요'}
        </h3>
        <p style={{ fontFamily: 'var(--font-body)', fontWeight: 700, fontSize: 18, color: 'var(--fg-muted)', margin: '8px 0 18px' }}>
          {success ? 'The candy made it home.' : 'Not enough candy made it back.'}
        </p>
        {success && (
          <div style={{ display: 'flex', justifyContent: 'center', gap: 8, margin: '6px 0 18px' }}>
            {[0,1,2].map(i => (
              <div key={i} style={{
                width: 44, height: 44, border: '3px solid var(--ink)',
                background: i < score ? 'var(--lemon-500)' : 'var(--cream-200)',
                clipPath: 'polygon(50% 0,61% 35%,98% 35%,68% 57%,79% 91%,50% 70%,21% 91%,32% 57%,2% 35%,39% 35%)',
              }}/>
            ))}
          </div>
        )}
        <div style={{ display: 'flex', gap: 10, justifyContent: 'center' }}>
          <Button kind="secondary" onClick={onRetry}>다시 하기</Button>
          {success ? <Button onClick={onNext}>다음 단계</Button>
                   : <Button kind="primary" onClick={onClose}>계속하기</Button>}
        </div>
      </div>
    </div>
  );
}

window.StageDialog = StageDialog;
