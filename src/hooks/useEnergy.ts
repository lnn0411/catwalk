import { useEnergyStore } from '../store/energyStore';
import { useMemo } from 'react';

export const useEnergy = () => {
  const { energy, maxEnergy, fillEnergy } = useEnergyStore(
    (state) => ({ energy: state.energy, maxEnergy: state.maxEnergy, fillEnergy: state.fillEnergy })
  );
  const percent = useMemo(
    () => (maxEnergy > 0 ? Math.round((energy / maxEnergy) * 100) : 0),
    [energy, maxEnergy]
  );

  return { energy, maxEnergy, fillEnergy, percent };
};
