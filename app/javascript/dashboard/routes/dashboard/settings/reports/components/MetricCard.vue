<template>
  <div class="bg-white dark:bg-gray-800 rounded-lg shadow-sm border border-gray-200 dark:border-gray-700 p-6">
    <div class="flex items-center">
      <div class="flex-shrink-0">
        <div :class="iconColorClass" class="w-8 h-8 rounded-md flex items-center justify-center">
          <i :class="icon" class="w-4 h-4 text-white" />
        </div>
      </div>
      <div class="ml-5 w-0 flex-1">
        <dl>
          <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 truncate">
            {{ title }}
          </dt>
          <dd class="text-lg font-medium text-gray-900 dark:text-gray-100">
            {{ value }}
          </dd>
        </dl>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'MetricCard',
  props: {
    title: {
      type: String,
      required: true,
    },
    value: {
      type: [String, Number],
      required: true,
    },
    icon: {
      type: String,
      required: true,
    },
    color: {
      type: String,
      default: 'blue',
      validator: value => ['blue', 'green', 'yellow', 'red', 'purple', 'orange'].includes(value),
    },
  },
  computed: {
    iconColorClass() {
      const colors = {
        blue: 'bg-blue-500',
        green: 'bg-green-500',
        yellow: 'bg-yellow-500',
        red: 'bg-red-500',
        purple: 'bg-purple-500',
        orange: 'bg-orange-500',
      };
      return colors[this.color] || colors.blue;
    },
  },
};
</script>
