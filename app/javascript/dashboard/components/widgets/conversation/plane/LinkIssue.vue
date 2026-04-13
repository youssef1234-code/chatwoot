<script setup>
import { ref, computed } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import PlaneAPI from 'dashboard/api/integrations/plane';
import Button from 'dashboard/components-next/button/Button.vue';
import Input from 'dashboard/components-next/input/Input.vue';
import { parsePlaneAPIErrorResponse } from './helpers/apiErrorHelper';
import { getPlaneStateColor, getPlaneStateBgColor } from 'dashboard/composables/usePlaneIssues';

const PLANE_EVENTS = {
  LINK_ISSUE: 'Linked Plane Issue',
};

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
  title: {
    type: String,
    default: '',
  },
});

const emit = defineEmits(['close', 'issue-linked']);

const { t } = useI18n();

const issues = ref([]);
const selectedOption = ref({});
const shouldShowDropdown = ref(false);
const isFetching = ref(false);
const isLinking = ref(false);
const searchQuery = ref('');

const toggleDropdown = () => {
  issues.value = [];
  shouldShowDropdown.value = !shouldShowDropdown.value;
};

const linkIssueTitle = computed(() => {
  return selectedOption.value.id
    ? selectedOption.value.name
    : t('INTEGRATION_SETTINGS.PLANE.LINK.SELECT');
});

const isSubmitDisabled = computed(() => {
  return !selectedOption.value.id || isLinking.value;
});

const onSelectIssue = item => {
  selectedOption.value = item;
  toggleDropdown();
};

const onClose = () => {
  emit('close');
};

const onSearch = async (value) => {
  issues.value = [];
  if (!value) return;
  
  try {
    isFetching.value = true;
    const response = await PlaneAPI.searchIssues(value);
    issues.value = response.data.map(issue => ({
      id: issue.id,
      name: `${issue.sequence_id || issue.id.substring(0, 8)} - ${issue.name}`,
      sequence_id: issue.sequence_id,
      project_id: issue.project_id,
      title: issue.name,
      state: issue.state_name,
      priority: issue.priority,
      url: issue.url
    }));
  } catch (error) {
    const errorMessage = parsePlaneAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.PLANE.LINK.ERROR')
    );
    useAlert(errorMessage);
  } finally {
    isFetching.value = false;
  }
};

const linkIssue = async () => {
  const { id: issueId, project_id: projectId, title } = selectedOption.value;
  try {
    isLinking.value = true;
    await PlaneAPI.linkIssue(props.conversationId, projectId, issueId, title);
    useAlert(t('INTEGRATION_SETTINGS.PLANE.LINK.LINK_SUCCESS'));
    
    // Emit event for escalation workflow
    emit('issue-linked', {
      id: issueId,
      name: selectedOption.value.name,
      ...selectedOption.value
    });
    
    // Emit event for other components to update
    window.dispatchEvent(new CustomEvent('plane:issues-updated'));
    
    searchQuery.value = '';
    issues.value = [];
    onClose();
    useTrack(PLANE_EVENTS.LINK_ISSUE);
  } catch (error) {
    const errorMessage = parsePlaneAPIErrorResponse(
      error,
      t('INTEGRATION_SETTINGS.PLANE.LINK.LINK_ERROR')
    );
    useAlert(errorMessage);
  } finally {
    isLinking.value = false;
  }
};

const getStatusBgColor = (state) => getPlaneStateBgColor(state);
const getStatusTextColor = (state) => getPlaneStateColor(state);
</script>

<template>
  <div class="flex flex-col h-full">
    <div class="flex-1 p-6">
      <p class="text-sm text-n-slate-11 mb-4">
        {{ $t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK.DESCRIPTION') }}
      </p>

      <div
        class="flex flex-col border border-n-weak rounded-xl transition-all duration-200"
        :class="shouldShowDropdown ? 'h-[256px]' : 'gap-2'"
      >
        <Button
          variant="outline"
          class="justify-between w-full h-[2.5rem] py-1.5 px-3 rounded-xl"
          @click="toggleDropdown"
        >
          {{ linkIssueTitle }}
          <i class="i-lucide-chevron-down"></i>
        </Button>
        
        <div v-if="shouldShowDropdown" class="border-t border-n-weak">
          <Input
            v-model="searchQuery"
            :placeholder="$t('INTEGRATION_SETTINGS.PLANE.LINK.SEARCH')"
            class="m-2"
            @update:modelValue="onSearch"
          />
          <div class="max-h-48 overflow-y-auto p-2">
            <div v-if="isFetching" class="p-2 text-sm text-slate-600 dark:text-slate-400">
              {{ $t('INTEGRATION_SETTINGS.PLANE.LINK.LOADING') }}
            </div>
            <div
              v-for="issue in issues"
              :key="issue.id"
              class="p-2 cursor-pointer hover:bg-slate-100 dark:hover:bg-slate-700 rounded"
              :class="{ 'bg-slate-100 dark:bg-slate-700': selectedOption.id === issue.id }"
              @click="onSelectIssue(issue)"
            >
              <div class="flex items-center justify-between">
                <span class="font-medium text-slate-900 dark:text-slate-100">
                  {{ issue.sequence_id || issue.id.substring(0, 8) }}
                </span>
                <span 
                  v-if="issue.state"
                  class="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium"
                  :style="{ backgroundColor: getStatusBgColor(issue.state), color: getStatusTextColor(issue.state) }"
                >
                  {{ issue.state }}
                </span>
              </div>
              <div class="text-sm text-slate-600 dark:text-slate-400 truncate">{{ issue.title }}</div>
            </div>
            <div v-if="issues.length === 0 && searchQuery && !isFetching" class="p-2 text-sm text-slate-600 dark:text-slate-400">
              {{ $t('INTEGRATION_SETTINGS.PLANE.LINK.EMPTY_LIST') }}
            </div>
          </div>
        </div>
      </div>

      <div v-if="!shouldShowDropdown && !selectedOption.id" class="mt-2">
        <p class="text-xs text-slate-500 dark:text-slate-400">
          {{ $t('INTEGRATION_SETTINGS.PLANE.LINK.EMPTY_LIST') }}
        </p>
      </div>
    </div>

    <!-- Footer -->
    <div class="flex justify-end gap-3 p-6 pt-4 border-t border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-800">
      <Button ghost slate :label="$t('INTEGRATION_SETTINGS.PLANE.CANCEL')" @click="onClose" />
      <Button
        blue
        :label="$t('INTEGRATION_SETTINGS.PLANE.LINK.TITLE')"
        :loading="isLinking"
        :disabled="isSubmitDisabled"
        @click="linkIssue"
      />
    </div>
  </div>
</template>
