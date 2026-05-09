// Skill toolbar — bottom center
const SKILL_DATA = [
  { id: 'climber',  ko: '등반',   key: '1', icon: '../../assets/icons/skills/climber.svg' },
  { id: 'floater',  ko: '낙하산', key: '2', icon: '../../assets/icons/skills/floater.svg' },
  { id: 'bomber',   ko: '폭탄',   key: '3', icon: '../../assets/icons/skills/bomber.svg' },
  { id: 'blocker',  ko: '차단',   key: '4', icon: '../../assets/icons/skills/blocker.svg' },
  { id: 'builder',  ko: '계단',   key: '5', icon: '../../assets/icons/skills/builder.svg' },
  { id: 'basher',   ko: '굴착',   key: '6', icon: '../../assets/icons/skills/basher.svg' },
  { id: 'miner',    ko: '채굴',   key: '7', icon: '../../assets/icons/skills/miner.svg' },
  { id: 'digger',   ko: '땅파기', key: '8', icon: '../../assets/icons/skills/digger.svg' },
];

function SkillToolbar({ inventory, selected, onSelect }) {
  // Sits in its own band below the stage (stage reserves bottom: 132)
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0, height: 132,
      display: 'flex', gap: 14, padding: '18px 18px 14px',
      alignItems: 'center', justifyContent: 'center',
      background: 'var(--surface-sunk, var(--cream-200))',
      borderTop: '3px solid var(--ink)',
    }}>
      {SKILL_DATA.map(s => (
        <SkillSlot key={s.id}
          icon={s.icon} name={s.ko} hotkey={s.key}
          count={inventory[s.id] ?? 0}
          selected={selected === s.id}
          onClick={() => onSelect(s.id)}
        />
      ))}
    </div>
  );
}

window.SkillToolbar = SkillToolbar;
window.SKILL_DATA = SKILL_DATA;
