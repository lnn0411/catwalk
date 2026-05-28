import { useEnergyStore } from '../store/energyStore';

export const useEnergy = () => {
  const energy = useEnergyStore((state) => state.energy);
  const maxEnergy = useEnergyStore((state) => state.maxEnergy);
  const fillEnergy = useEnergyStore((state) => state.fillEnergy);
  const percent = maxEnergy > 0 ? Math.round((energy / maxEnergy) * 100) : 0;

  return {
    energy,
    maxEnergy,
    fillEnergy,
    percent,
  };
};
