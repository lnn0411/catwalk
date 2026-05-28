import { useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useCatStore } from '../store/catStore';
import { useEnergyStore } from '../store/energyStore';
import { useEnergy } from '../hooks/useEnergy';
import { useStepCounter } from '../hooks/useStepCounter';

const DevToolsPanel = () => {
  const [open, setOpen] = useState(false);
  const location = useLocation();
  const navigate = useNavigate();
  const { steps, setSteps, setSpeed } = useStepCounter();
  const addSteps = useEnergyStore((state) => state.addSteps);
  const { energy, maxEnergy, fillEnergy } = useEnergy();
  const slots = useCatStore((state) => state.slots);
  const updateSlot = useCatStore((state) => state.updateSlot);

  const completeHatch = () => {
    const target = slots.find((slot) => slot.status === 'incubating') ?? slots[0];

    if (target) {
      updateSlot(target.id, {
        status: 'complete',
        energyCurrent: target.energyRequired,
      });
    }

    navigate('/hatch-complete');
  };

  return (
    <aside className="dev-tools">
      {open ? (
        <div className="dev-tools__panel">
          <div className="dev-tools__row">步数：{steps}</div>
          <div className="dev-tools__row">能量：{energy}/{maxEnergy}</div>
          <div className="dev-tools__row">路由：{location.pathname}</div>
          <div className="dev-tools__actions">
            <button type="button" onClick={() => addSteps(100)}>+100步</button>
            <button type="button" onClick={() => addSteps(1000)}>+1000步</button>
            <button type="button" onClick={() => addSteps(5000)}>+5000步</button>
            <button type="button" onClick={() => setSteps(0)}>清零</button>
            <button type="button" onClick={() => setSpeed(1)}>慢</button>
            <button type="button" onClick={() => setSpeed(3)}>中</button>
            <button type="button" onClick={() => setSpeed(10)}>快</button>
            <button type="button" onClick={fillEnergy}>一键满能量</button>
            <button type="button" onClick={completeHatch}>一键孵化</button>
            <button type="button" onClick={() => navigate('/dormant')}>欢迎回来</button>
          </div>
        </div>
      ) : null}
      <button
        type="button"
        className="dev-tools__toggle"
        onClick={() => setOpen((value) => !value)}
      >
        Dev
      </button>
    </aside>
  );
};

const DevTools = () => {
  if (process.env.NODE_ENV !== 'development') {
    return null;
  }

  return <DevToolsPanel />;
};

export default DevTools;
