import { Inventory } from './inventory';
import { Slot } from './slot';

export type WardrobeItem = Slot & {
  slotType: string;
};

export type State = {
  leftInventory: Inventory;
  rightInventory: Inventory;
  wardrobeItems: Record<string, WardrobeItem | null>;
  itemAmount: number;
  shiftPressed: boolean;
  isBusy: boolean;
  additionalMetadata: Array<{ metadata: string; value: string }>;
  history?: {
    leftInventory: Inventory;
    rightInventory: Inventory;
  };
};
