import { create } from 'zustand';
import type { NewbieGoal } from '../types/activity';

interface NewbieState {
  goals: NewbieGoal[];
  completeGoal: (id: number) => void;
  claimGoal: (id: number) => void;
}

const initialGoals: NewbieGoal[] = [
  { id: 1, completed: false, claimed: false, unlocked: true },
  { id: 2, completed: false, claimed: false, unlocked: true },
  { id: 3, completed: false, claimed: false, unlocked: false },
];

export const useNewbieStore = create<NewbieState>((set) => ({
  goals: initialGoals,
  completeGoal: (id) =>
    set((state) => ({
      goals: state.goals.map((goal) =>
        goal.id === id ? { ...goal, completed: true } : goal,
      ),
    })),
  claimGoal: (id) =>
    set((state) => ({
      goals: state.goals.map((goal) =>
        goal.id === id && goal.completed
          ? { ...goal, claimed: true }
          : goal,
      ),
    })),
}));
