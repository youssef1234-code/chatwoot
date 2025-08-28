<script setup>
// [TODO] Use Teleport to move the modal to the end of the body
import { ref, computed, defineEmits, onMounted } from 'vue';
import { useEventListener } from '@vueuse/core';
import Button from 'dashboard/components-next/button/Button.vue';

const { modalType, closeOnBackdropClick, onClose, expandable } = defineProps({
  closeOnBackdropClick: { type: Boolean, default: true },
  showCloseButton: { type: Boolean, default: true },
  onClose: { type: Function, required: true },
  fullWidth: { type: Boolean, default: false },
  modalType: { type: String, default: 'centered' },
  size: { type: String, default: '' },
  // When true, show an expand/minimize control that grows the modal container
  expandable: { type: Boolean, default: true },
});

const emit = defineEmits(['close']);
const show = defineModel('show', { type: Boolean, default: false });
const isExpanded = ref(false);

const modalClassName = computed(() => {
  const modalClassNameMap = {
    centered: '',
    'right-aligned': 'right-aligned',
  };

  return `modal-mask skip-context-menu ${modalClassNameMap[modalType] || ''}`;
});

// [TODO] Revisit this logic to use outside click directive
const mousedDownOnBackdrop = ref(false);

const handleMouseDown = () => {
  mousedDownOnBackdrop.value = true;
};

const close = () => {
  isExpanded.value = false;
  show.value = false;
  emit('close');
  onClose();
};

const onMouseUp = () => {
  if (mousedDownOnBackdrop.value) {
    mousedDownOnBackdrop.value = false;
    if (closeOnBackdropClick) {
      close();
    }
  }
};

const onKeydown = e => {
  if (show.value && e.code === 'Escape') {
    close();
    e.stopPropagation();
  }
};

const toggleExpand = () => {
  if (!expandable) return;
  isExpanded.value = !isExpanded.value;
};

useEventListener(document.body, 'mouseup', onMouseUp);
useEventListener(document, 'keydown', onKeydown);

onMounted(() => {
  if (import.meta.env.DEV && onClose && typeof onClose === 'function') {
    // eslint-disable-next-line no-console
    console.warn(
      "[DEPRECATED] The 'onClose' prop is deprecated. Please use the 'close' event instead."
    );
  }
});
</script>

<template>
  <transition name="modal-fade">
    <div
      v-if="show"
      :class="modalClassName"
      transition="modal"
      @mousedown="handleMouseDown"
    >
      <div
        class="relative max-h-full bg-n-alpha-3 shadow-md modal-container rtl:text-right skip-context-menu flex flex-col overflow-hidden"
        :class="{
          'rounded-xl w-[37.5rem]': !fullWidth,
          'items-center rounded-none flex h-full justify-center w-full':
            fullWidth,
          [size]: true,
          expanded: isExpanded && !fullWidth,
        }"
        @mouse.stop
        @mousedown="event => event.stopPropagation()"
      >
        <Button
          v-if="expandable"
          ghost
          slate
          :icon="isExpanded ? 'i-lucide-minimize-2' : 'i-lucide-maximize-2'"
          class="absolute z-10 ltr:right-10 rtl:left-10 top-2"
          :aria-label="isExpanded ? 'Minimize modal' : 'Expand modal'"
          @click="toggleExpand"
        />
        <Button
          v-if="showCloseButton"
          ghost
          slate
          icon="i-lucide-x"
          class="absolute z-10 ltr:right-2 rtl:left-2 top-2"
          @click="close"
        />
        <slot />
      </div>
    </div>
  </transition>
</template>

<style lang="scss">
.modal-mask {
  @apply flex items-center justify-center bg-n-alpha-black2 backdrop-blur-[4px] z-[9990] h-full left-0 fixed top-0 w-full;

  .modal-container {
    transition: width 280ms cubic-bezier(0.4, 0.0, 0.2, 1),
      max-width 280ms cubic-bezier(0.4, 0.0, 0.2, 1),
      height 280ms cubic-bezier(0.4, 0.0, 0.2, 1),
      transform 280ms cubic-bezier(0.4, 0.0, 0.2, 1),
      opacity 280ms cubic-bezier(0.4, 0.0, 0.2, 1);
    will-change: width, height, transform, opacity;
    &.medium {
      @apply max-w-[80%] w-[56.25rem];
    }

    &.expanded {
      @apply w-[95vw] max-w-[95vw] h-[90vh];
      animation: modalExpand 300ms cubic-bezier(0.4, 0.0, 0.2, 1);
    }

    // .content-box {
    //   @apply h-auto p-0;
    // }
    .content {
      @apply p-8;
    }

    form,
    .modal-content {
      @apply pt-4 pb-8 px-8 self-center;

      a {
        @apply p-4;
      }
    }
  }
}

.modal-big {
  @apply w-full;
}

.modal-mask.right-aligned {
  @apply justify-end;

  .modal-container {
    @apply rounded-none h-full w-[30rem];
  }
}

.modal-enter,
.modal-leave {
  @apply opacity-0;
}

.modal-enter .modal-container,
.modal-leave .modal-container {
  transform: scale(1.1);
}

@keyframes modalExpand {
  0% { 
    transform: scale(0.96) translateZ(0); 
    opacity: 0.9; 
  }
  60% { 
    transform: scale(1.01) translateZ(0); 
    opacity: 0.98; 
  }
  100% { 
    transform: scale(1) translateZ(0); 
    opacity: 1; 
  }
}
</style>
