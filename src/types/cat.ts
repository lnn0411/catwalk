export type CatBreed = 'orange' | 'british' | 'siamese';

export type CatLevel = 1 | 2 | 3 | 4 | 5;

export type SlotStatus = 'locked' | 'empty' | 'incubating' | 'complete';

export type TaskStatus = 'todo' | 'claimable' | 'claimed';

export interface Cat {
  id: string;
  breed: CatBreed;
  name: string;
  level: CatLevel;
  exp: number;
  affection: number;
  affectionLevel: 1 | 2 | 3 | 4 | 5;
  createdAt: number;
}

export interface EggSlot {
  id: string;
  breed: CatBreed | null;
  status: SlotStatus;
  energyRequired: number;
  energyCurrent: number;
  startedAt: number | null;
}
