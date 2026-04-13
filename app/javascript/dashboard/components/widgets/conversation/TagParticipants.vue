<script setup>
import { ref, computed, watch, nextTick } from 'vue';
import { useKeyboardNavigableList } from 'dashboard/composables/useKeyboardNavigableList';

const props = defineProps({
  searchKey: {
    type: String,
    default: '',
  },
  participants: {
    type: Array,
    default: () => [],
  },
});

const emit = defineEmits(['selectParticipant']);

const tagParticipantsRef = ref(null);
const selectedIndex = ref(0);

const items = computed(() => {
  if (!props.searchKey) {
    return props.participants;
  }
  const key = props.searchKey.toLowerCase();
  return props.participants.filter(
    p =>
      (p.name && p.name.toLowerCase().includes(key)) ||
      (p.phone && p.phone.includes(key))
  );
});

const adjustScroll = () => {
  nextTick(() => {
    if (tagParticipantsRef.value) {
      tagParticipantsRef.value.scrollTop = 50 * selectedIndex.value;
    }
  });
};

const onSelect = () => {
  emit('selectParticipant', items.value[selectedIndex.value]);
};

useKeyboardNavigableList({
  items,
  onSelect,
  adjustScroll,
  selectedIndex,
});

watch(items, newList => {
  if (newList.length < selectedIndex.value + 1) {
    selectedIndex.value = 0;
  }
});

const onHover = index => {
  selectedIndex.value = index;
};

const onItemSelect = index => {
  selectedIndex.value = index;
  onSelect();
};

const getInitial = name => {
  return name ? name.charAt(0).toUpperCase() : '?';
};
</script>

<template>
  <div>
    <ul
      v-if="items.length"
      ref="tagParticipantsRef"
      class="vertical dropdown menu mention--box bg-n-solid-1 p-1 rounded-xl text-sm overflow-auto absolute w-full z-20 shadow-md left-0 leading-[1.2] bottom-full max-h-[12.5rem] border border-solid border-n-strong"
    >
      <li
        v-for="(participant, index) in items"
        :id="`mention-item-${index}`"
        :key="participant.wa_id || index"
        :class="{
          'bg-n-alpha-black2': index === selectedIndex,
          'last:mb-0': items.length <= 4,
        }"
        class="flex items-center px-2 py-1 rounded-md cursor-pointer"
        @click="onItemSelect(index)"
        @mouseover="onHover(index)"
      >
        <div
          class="mr-2 flex items-center justify-center w-6 h-6 rounded-full bg-woot-500 text-white text-xs font-medium flex-shrink-0"
        >
          {{ getInitial(participant.name) }}
        </div>
        <div
          class="flex-1 max-w-full overflow-hidden whitespace-nowrap text-ellipsis"
        >
          <h5
            class="mb-0 overflow-hidden text-sm text-n-slate-11 whitespace-nowrap text-ellipsis"
            :class="{ 'text-n-slate-12': index === selectedIndex }"
          >
            {{ participant.name }}
          </h5>
          <div
            v-if="participant.phone"
            class="overflow-hidden text-xs whitespace-nowrap text-ellipsis text-n-slate-10"
            :class="{ 'text-n-slate-11': index === selectedIndex }"
          >
            +{{ participant.phone }}
          </div>
        </div>
      </li>
    </ul>
  </div>
</template>
