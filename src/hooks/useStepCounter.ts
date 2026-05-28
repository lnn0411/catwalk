import { useEffect, useState } from 'react';
import { useEnergyStore } from '../store/energyStore';

interface StepCounterState {
  steps: number;
  isAuthorized: boolean;
  setSteps: (steps: number) => void;
  setSpeed: (speed: number) => void;
}

const useMockStepCounter = (): StepCounterState => {
  const steps = useEnergyStore((state) => state.steps);
  const addSteps = useEnergyStore((state) => state.addSteps);
  const setStoreSteps = useEnergyStore((state) => state.setSteps);
  const [speed, setSpeed] = useState(3);

  useEffect(() => {
    const timer = window.setInterval(() => {
      addSteps(speed);
    }, 1000);

    return () => window.clearInterval(timer);
  }, [addSteps, speed]);

  return {
    steps,
    isAuthorized: true,
    setSteps: setStoreSteps,
    setSpeed,
  };
};

const useRealStepCounter = (): StepCounterState => ({
  steps: 0,
  isAuthorized: false,
  setSteps: () => undefined,
  setSpeed: () => undefined,
});

export const useStepCounter =
  process.env.NODE_ENV === 'development'
    ? useMockStepCounter
    : useRealStepCounter;
