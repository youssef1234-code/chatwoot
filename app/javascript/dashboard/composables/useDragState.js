import { ref, readonly } from "vue";

const draggedTicket = ref(null);
const isDragging = ref(false);

export const useDragState = () => {
  const setDraggedTicket = (ticket) => {
    draggedTicket.value = ticket;
    isDragging.value = !!ticket;
  };

  const clearDraggedTicket = () => {
    draggedTicket.value = null;
    isDragging.value = false;
  };

  return {
    draggedTicket: readonly(draggedTicket),
    isDragging: readonly(isDragging),
    setDraggedTicket,
    clearDraggedTicket,
  };
};
