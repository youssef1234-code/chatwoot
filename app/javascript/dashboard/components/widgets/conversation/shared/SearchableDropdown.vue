<script setup>
import { ref, computed, watch } from 'vue';

const props = defineProps({
  label: {
    type: String,
    required: true,
  },
  placeholder: {
    type: String,
    default: '',
  },
  items: {
    type: Array,
    default: () => [],
  },
  errorMessage: {
    type: String,
    default: '',
  },
  value: {
    type: String,
    default: '',
  },
  disabled: {
    type: Boolean,
    default: false,
  },
});

const emit = defineEmits(['select']);

const searchText = ref('');
const isOpen = ref(false);
const selectedItem = ref(null);

// Computed for filtered items based on search
const filteredItems = computed(() => {
  if (!searchText.value.trim()) return props.items;
  
  const query = searchText.value.toLowerCase().trim();
  
  return props.items.filter(item => {
    if (!item || !item.name) return false;
    
    const nameMatch = item.name.toLowerCase().includes(query);
    const idMatch = item.id && item.id.toString().toLowerCase().includes(query);
    const keyMatch = item.key && item.key.toLowerCase().includes(query);
    
    return nameMatch || idMatch || keyMatch;
  });
});

// What to display in the input field
const displayText = computed(() => {
  if (isOpen.value) {
    return searchText.value; // Show what user is typing when open
  }
  return selectedItem.value ? selectedItem.value.name : ''; // Show selected item when closed
});

const selectItem = (item) => {
  selectedItem.value = item;
  searchText.value = item.name;
  isOpen.value = false;
  emit('select', item);
};

const onInput = (event) => {
  searchText.value = event.target.value;
  isOpen.value = true;
  
  // Clear selection if input is cleared
  if (!event.target.value) {
    selectedItem.value = null;
    emit('select', null);
  }
};

const onFocus = () => {
  if (props.disabled) return;
  isOpen.value = true;
  // When focusing, show current search or clear for new search
  if (selectedItem.value && !searchText.value) {
    searchText.value = '';
  }
};

const onBlur = () => {
  setTimeout(() => {
    isOpen.value = false;
    // Restore selected item text if no new selection was made
    if (selectedItem.value && !searchText.value) {
      searchText.value = selectedItem.value.name;
    }
  }, 200);
};

const clearSelection = () => {
  selectedItem.value = null;
  searchText.value = '';
  emit('select', null);
};

// Watch for external value changes (parent component setting value)
watch(() => props.value, (newValue) => {
  if (newValue && props.items.length > 0) {
    const item = props.items.find(item => item.id === newValue);
    if (item) {
      selectedItem.value = item;
      searchText.value = item.name;
    }
  } else if (!newValue) {
    selectedItem.value = null;
    searchText.value = '';
  }
}, { immediate: true });

// Watch for items changes
watch(() => props.items, (newItems) => {
  if (props.value && newItems.length > 0) {
    const item = newItems.find(item => item.id === props.value);
    if (item) {
      selectedItem.value = item;
      searchText.value = item.name;
    }
  }
}, { immediate: true });
</script>

<template>
  <div class="relative mb-4">
    <!-- Label -->
    <label class="block text-sm font-medium text-slate-900 dark:text-slate-100 mb-2">
      {{ label }}
    </label>
    
    <!-- Input Container -->
    <div class="relative">
      <input
        :value="displayText"
        :placeholder="placeholder"
        :disabled="disabled"
        :readonly="disabled"
        class="w-full px-3 py-2 pr-10 border border-slate-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-slate-100 placeholder:text-slate-500 dark:placeholder:text-slate-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors disabled:opacity-60 disabled:cursor-not-allowed disabled:bg-slate-100 dark:disabled:bg-slate-700"
        :class="{
          'border-red-500 focus:ring-red-500 focus:border-red-500': errorMessage,
          'rounded-b-none border-b-0': isOpen
        }"
        @input="onInput"
        @focus="onFocus"
        @blur="onBlur"
      />

      <!-- Clear button -->
      <button
        v-if="selectedItem && !disabled"
        type="button"
        class="absolute right-8 top-1/2 transform -translate-y-1/2 p-1 text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 transition-colors"
        @click="clearSelection"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
      
      <!-- Dropdown arrow -->
      <div class="absolute right-3 top-1/2 transform -translate-y-1/2 pointer-events-none">
        <svg 
          class="w-4 h-4 text-slate-500 dark:text-slate-400 transition-transform duration-200"
          :class="{ 'rotate-180': isOpen }"
          fill="none" 
          stroke="currentColor" 
          viewBox="0 0 24 24"
        >
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
        </svg>
      </div>
      
      <!-- Dropdown menu -->
      <div
        v-if="isOpen"
        class="absolute z-50 w-full bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-600 border-t-0 rounded-b-lg shadow-lg max-h-48 overflow-y-auto"
      >
        <div v-if="searchText && filteredItems.length === 0" class="px-3 py-2 text-sm text-slate-500 dark:text-slate-400">
          No results found for "{{ searchText }}"
        </div>
        <button
          v-for="item in filteredItems"
          :key="item.id"
          type="button"
          :class="{
            'bg-blue-50 dark:bg-blue-900/30 border-blue-100 dark:border-blue-700': selectedItem && selectedItem.id === item.id
          }"
          class="w-full px-3 py-2 text-left text-sm hover:bg-slate-50 dark:hover:bg-slate-700 focus:bg-slate-50 dark:focus:bg-slate-700 focus:outline-none border-b border-slate-200 dark:border-slate-600 last:border-b-0 transition-colors"
          @click="selectItem(item)"
        >
          <div class="flex justify-between items-center">
            <span class="font-medium text-slate-900 dark:text-slate-100">{{ item.name }}</span>
            <span v-if="item.id && item.id !== item.name" class="text-xs text-slate-500 dark:text-slate-400">{{ item.id }}</span>
          </div>
        </button>
      </div>
    </div>

    <!-- Error message -->
    <div v-if="errorMessage" class="mt-1 text-sm text-red-500">
      {{ errorMessage }}
    </div>
  </div>
</template>
