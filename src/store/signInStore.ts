import { create } from 'zustand';
import type { SignInState } from '../types/activity';

interface SignInStore {
  signIn: SignInState;
  setSignIn: (signIn: SignInState) => void;
}

const initialSignIn: SignInState = {
  currentDay: 1,
  lastSignInDate: '',
  claimedDays: Array(7).fill(false),
  makeUpCount: 0,
  cycleStartDate: '',
};

export const useSignInStore = create<SignInStore>((set) => ({
  signIn: initialSignIn,
  setSignIn: (signIn) => set({ signIn }),
}));
