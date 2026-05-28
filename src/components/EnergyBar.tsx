interface EnergyBarProps {
  current: number;
  max: number;
  variant?: 'blue' | 'green';
}

const colors = {
  blue: '#3b82f6',
  green: '#22c55e',
};

const EnergyBar = ({ current, max, variant = 'blue' }: EnergyBarProps) => {
  const percent = max > 0 ? Math.min(Math.max((current / max) * 100, 0), 100) : 0;

  return (
    <div className="energy-bar" aria-label={`Energy ${current}/${max}`}>
      <div
        className="energy-bar__fill"
        style={{
          width: `${percent}%`,
          backgroundColor: colors[variant],
          transition: 'width 300ms linear',
        }}
      />
    </div>
  );
};

export default EnergyBar;
