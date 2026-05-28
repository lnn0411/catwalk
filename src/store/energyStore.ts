import { create } from 'zustand';

interface EnergyState {
  steps: number;
  energy: number;
  maxEnergy: number;
  addSteps: (amount: number) => void;
  setSteps: (steps: number) => void;
  fillEnergy: () => void;
}

const clamp = (value: number, min: number, max: number) =>
  Math.min(Math.max(value, min), max);

const stepsToEnergy = (steps: number) => Math.floor(steps / 100);

export const useEnergyStore = create<EnergyState>((set) => ({
  steps: 0,
  energy: 0,
  maxEnergy: 100,
  addSteps: (amount) =>
    set((state) => {
      const nextSteps = Math.max(0, state.steps + amount);
      return {
        steps: nextSteps,
        energy: clamp(state.energy + stepsToEnergy(Math.max(0, amount)), 0, state.maxEnergy),
      };
    }),
  setSteps: (steps) =>
    set((state) => {
      const nextSteps = Math.max(0, steps);
      return {
        steps: nextSteps,
        energy: clamp(stepsToEnergy(nextSteps), 0, state.maxEnergy),
      };
    }),
  fillEnergy: () =>
    set((state) => ({
      energy: state.maxEnergy,
    })),
}));
