export interface SignInState {
  currentDay: number;
  lastSignInDate: string;
  claimedDays: boolean[];
  makeUpCount: number;
  cycleStartDate: string;
}

export interface NewbieGoal {
  id: number;
  completed: boolean;
  claimed: boolean;
  unlocked: boolean;
}

export interface EventCard {
  id: string;
  type: 'steps_milestone' | 'hatch_boost' | 'collection';
  title: string;
  startTime: number;
  endTime: number;
  status: 'upcoming' | 'active' | 'ended';
}
