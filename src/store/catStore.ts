import { create } from 'zustand';
import type { Cat, EggSlot } from '../types/cat';

interface CatState {
  cats: Cat[];
  slots: EggSlot[];
  addCat: (cat: Cat) => void;
  updateSlot: (id: string, patch: Partial<EggSlot>) => void;
}

const initialSlots: EggSlot[] = [
  {
    id: 'slot-1',
    breed: null,
    status: 'empty',
    energyRequired: 100,
    energyCurrent: 0,
    startedAt: null,
  },
  {
    id: 'slot-2',
    breed: null,
    status: 'locked',
    energyRequired: 200,
    energyCurrent: 0,
    startedAt: null,
  },
  {
    id: 'slot-3',
    breed: null,
    status: 'locked',
    energyRequired: 300,
    energyCurrent: 0,
    startedAt: null,
  },
];

export const useCatStore = create<CatState>((set) => ({
  cats: [],
  slots: initialSlots,
  addCat: (cat) =>
    set((state) => ({
      cats: [...state.cats, cat],
    })),
  updateSlot: (id, patch) =>
    set((state) => ({
      slots: state.slots.map((slot) =>
        slot.id === id ? { ...slot, ...patch, id: slot.id } : slot,
      ),
    })),
}));
