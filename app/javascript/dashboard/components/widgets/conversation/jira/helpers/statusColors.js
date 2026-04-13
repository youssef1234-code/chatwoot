import { ref } from 'vue';
import JiraAPI from 'dashboard/api/integrations/jira';

const colorMapping = ref({});
const lowerCaseMapping = ref({});
let loaded = false;
let loading = null;

export async function loadStatusColors() {
  if (loaded && Object.keys(colorMapping.value).length > 0) return colorMapping.value;
  if (loading) return loading;

  loading = JiraAPI.getSettings()
    .then(response => {
      const mapping = response.data?.status_color_mapping || {};
      colorMapping.value = mapping;
      // Build lowercase lookup for case-insensitive matching
      const lower = {};
      Object.entries(mapping).forEach(([key, value]) => {
        lower[key.toLowerCase()] = value;
      });
      lowerCaseMapping.value = lower;
      loaded = true;
      loading = null;
      return colorMapping.value;
    })
    .catch(err => {
      console.error('[JIRA Colors] Failed to load status colors:', err);
      // Don't set loaded=true on failure so it retries next time
      loading = null;
      return {};
    });

  return loading;
}

export function getStatusHexColor(statusName) {
  if (!statusName) return null;
  const result = colorMapping.value[statusName]
    || lowerCaseMapping.value[statusName.toLowerCase()]
    || null;
  return result;
}

export function resetStatusColors() {
  loaded = false;
  loading = null;
  colorMapping.value = {};
  lowerCaseMapping.value = {};
}
