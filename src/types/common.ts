export interface RewardItem {
  type: 'coin' | 'gem' | 'petal' | 'item' | 'costume';
  amount: number;
  itemId?: string;
}
