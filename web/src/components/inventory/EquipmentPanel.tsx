import React, { useCallback, useRef } from 'react';
import { useDrag, useDrop } from 'react-dnd';
import { useAppDispatch, useAppSelector } from '../../store';
import { selectWardrobeItems } from '../../store/inventory';
import { DragSource } from '../../typings';
import { Items } from '../../store/items';
import { getItemUrl } from '../../helpers';
import { fetchNui } from '../../utils/fetchNui';
import { closeTooltip, openTooltip } from '../../store/tooltip';
import { openContextMenu } from '../../store/contextMenu';

const SLOT_LABELS: Record<string, string> = {
  hat: 'Hut',
  glasses: 'Brille',
  ear: 'Ohrschmuck',
  watch: 'Uhr',
  bracelet: 'Armband',
  mask: 'Maske',
  hair: 'Frisur',
  torso: 'Oberkörper',
  undershirt: 'Unterhemd',
  top: 'Oberteil',
  decal: 'Abzeichen',
  legs: 'Hose',
  shoes: 'Schuhe',
  bag: 'Tasche',
  accessory: 'Accessoire',
  armor: 'Schutzweste',
};

const SLOT_ICONS: Record<string, string> = {
  hat: '🎩',
  glasses: '🕶️',
  ear: '💎',
  watch: '⌚',
  bracelet: '📿',
  mask: '🎭',
  hair: '💇',
  torso: '👔',
  undershirt: '👕',
  top: '🧥',
  decal: '🏷️',
  legs: '👖',
  shoes: '👟',
  bag: '🎒',
  accessory: '🧣',
  armor: '🦺',
};

const SLOT_ORDER = [
  ['hat', 'glasses'],
  ['ear', 'watch'],
  ['bracelet', 'mask'],
  ['hair', 'torso'],
  ['undershirt', 'top'],
  ['decal', 'legs'],
  ['shoes', 'bag'],
  ['accessory', 'armor'],
];

interface EquipmentSlotProps {
  slotType: string;
}

const EquipmentSlot: React.FC<EquipmentSlotProps> = ({ slotType }) => {
  const dispatch = useAppDispatch();
  const wardrobeItems = useAppSelector(selectWardrobeItems);
  const item = wardrobeItems[slotType] ?? null;
  const timerRef = useRef<number | null>(null);

  const [{ isDragging }, drag] = useDrag<DragSource, void, { isDragging: boolean }>(
    () => ({
      type: 'SLOT',
      collect: (monitor) => ({ isDragging: monitor.isDragging() }),
      item: () => {
        if (!item?.name) return null as any;
        return {
          inventory: 'wardrobe' as any,
          item: { name: item.name, slot: item.slot },
          image: `url(${getItemUrl(item as any) || 'none'})`,
          slotType,
        };
      },
      canDrag: () => !!item?.name,
    }),
    [item, slotType]
  );

  const [{ isOver }, drop] = useDrop<DragSource, void, { isOver: boolean }>(
    () => ({
      accept: 'SLOT',
      collect: (monitor) => ({ isOver: monitor.isOver() }),
      drop: (source) => {
        if (source.inventory === ('wardrobe' as any)) return;
        dispatch(closeTooltip());
        fetchNui('clothing:equipFromInventory', {
          fromSlot: source.item.slot,
          slotType,
        });
      },
      canDrop: (source) => source.inventory !== ('wardrobe' as any),
    }),
    [slotType]
  );

  const connectRef = (el: HTMLDivElement | null) => {
    if (!el) return;
    drag(drop(el));
  };

  const handleContext = (e: React.MouseEvent<HTMLDivElement>) => {
    e.preventDefault();
    if (!item?.name) return;
    dispatch(openContextMenu({ item: item as any, coords: { x: e.clientX, y: e.clientY } }));
  };

  const handleDoubleClick = () => {
    if (!item?.name) return;
    fetchNui('clothing:unequipToInventory', { slotType });
  };

  const itemData = item?.name ? Items[item.name] : null;
  const imageUrl = item?.name ? getItemUrl(item as any) : null;
  const label = item?.name ? (item.metadata?.label || itemData?.label || item.name) : SLOT_LABELS[slotType];

  return (
    <div
      ref={connectRef}
      className={`equipment-slot ${isOver ? 'equipment-slot--over' : ''} ${isDragging ? 'equipment-slot--dragging' : ''} ${item?.name ? 'equipment-slot--equipped' : ''}`}
      onContextMenu={handleContext}
      onDoubleClick={handleDoubleClick}
      style={{
        backgroundImage: imageUrl ? `url(${imageUrl})` : 'none',
        opacity: isDragging ? 0.4 : 1,
      }}
      onMouseEnter={() => {
        if (!item?.name) return;
        timerRef.current = window.setTimeout(() => {
          dispatch(openTooltip({ item: item as any, inventoryType: 'player' }));
        }, 500) as unknown as number;
      }}
      onMouseLeave={() => {
        dispatch(closeTooltip());
        if (timerRef.current) {
          clearTimeout(timerRef.current);
          timerRef.current = null;
        }
      }}
    >
      {!item?.name && (
        <span className="equipment-slot-icon">{SLOT_ICONS[slotType]}</span>
      )}
      <div className="equipment-slot-label">
        {label}
      </div>
    </div>
  );
};

const EquipmentPanel: React.FC = () => {
  return (
    <div className="equipment-panel">
      <div className="equipment-panel-header">
        <p>Garderobe</p>
      </div>
      <div className="equipment-panel-grid">
        {SLOT_ORDER.map((row, rowIdx) => (
          <div key={rowIdx} className="equipment-panel-row">
            {row.map((slotType) => (
              <EquipmentSlot key={slotType} slotType={slotType} />
            ))}
          </div>
        ))}
      </div>
      <div className="equipment-panel-hint">
        Doppelklick zum Ausziehen
      </div>
    </div>
  );
};

export default EquipmentPanel;
