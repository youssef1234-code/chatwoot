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
    <label class="block text-sm font-medium text-n-slate-12 mb-2">
      {{ label }}
    </label>
    
    <!-- Input Container -->
    <div class="relative">
      <input
        :value="displayText"
        :placeholder="placeholder"
        class="w-full px-3 py-2 pr-10 border border-n-weak rounded-lg bg-white text-n-slate-12 placeholder:text-n-slate-10 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-colors"
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
        v-if="selectedItem"
        type="button"
        class="absolute right-8 top-1/2 transform -translate-y-1/2 p-1 text-n-slate-10 hover:text-n-slate-12 transition-colors"
        @click="clearSelection"
      >
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
      
      <!-- Dropdown arrow -->
      <div class="absolute right-3 top-1/2 transform -translate-y-1/2 pointer-events-none">
        <svg 
          class="w-4 h-4 text-n-slate-10 transition-transform duration-200"
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
        class="absolute z-50 w-full bg-white border border-n-weak border-t-0 rounded-b-lg shadow-lg max-h-48 overflow-y-auto"
      >
        <div v-if="searchText && filteredItems.length === 0" class="px-3 py-2 text-sm text-n-slate-10">
          No results found for "{{ searchText }}"
        </div>
        <button
          v-for="item in filteredItems"
          :key="item.id"
          type="button"
          :class="{
            'bg-blue-50 border-blue-100': selectedItem && selectedItem.id === item.id
          }"
          class="w-full px-3 py-2 text-left text-sm hover:bg-n-alpha-2 focus:bg-n-alpha-2 focus:outline-none border-b border-n-alpha-1 last:border-b-0 transition-colors"
          @click="selectItem(item)"
        >
          <div class="flex justify-between items-center">
            <span class="font-medium text-n-slate-12">{{ item.name }}</span>
            <span v-if="item.id && item.id !== item.name" class="text-xs text-n-slate-8">{{ item.id }}</span>
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
