<script setup>
import { ref, computed, onMounted, onUnmounted, watch } from 'vue';
import { useI18n } from 'vue-i18n';
import { useAlert, useTrack } from 'dashboard/composables';
import PlaneAPI from 'dashboard/api/integrations/plane';
import Spinner from 'shared/components/Spinner.vue';
import NextButton from 'dashboard/components-next/button/Button.vue';
import PlaneIssueItem from './PlaneIssueItem.vue';
import CreateOrLinkIssue from './CreateOrLinkIssue.vue';
import { usePlaneIssues } from 'dashboard/composables/usePlaneIssues';

const PLANE_EVENTS = {
  UNLINK_ISSUE: 'Unlinked Plane Issue',
};

const props = defineProps({
  conversationId: {
    type: [Number, String],
    required: true,
  },
});

const { t } = useI18n();
const shouldShowCreateModal = ref(false);

// Single source of truth — composable handles events, debouncing, API calls
const { issues: linkedIssues, isLoading, refresh, removeIssue } = usePlaneIssues(
  computed(() => props.conversationId)
);

const hasIssues = computed(() => linkedIssues.value.length > 0);

const unlinkIssue = async (projectId, issueId) => {
  try {
    await PlaneAPI.unlinkIssue(projectId, issueId, props.conversationId);
    useTrack(PLANE_EVENTS.UNLINK_ISSUE);
    removeIssue(issueId);
    window.dispatchEvent(new CustomEvent('plane:issues-updated'));
    useAlert(t('INTEGRATION_SETTINGS.PLANE.UNLINK.SUCCESS'));
  } catch (error) {
    useAlert(t('INTEGRATION_SETTINGS.PLANE.UNLINK.ERROR'));
  }
};

const openCreateModal = () => {
  shouldShowCreateModal.value = true;
};

const closeCreateModal = () => {
  shouldShowCreateModal.value = false;
  refresh();
  window.dispatchEvent(new CustomEvent('plane:issues-updated'));
};

const handlePlaneCreateLink = (event) => {
  if (event.detail && event.detail.conversationId.toString() === props.conversationId.toString()) {
    openCreateModal();
  }
};

onMounted(() => {
  window.addEventListener('plane:open-create-link', handlePlaneCreateLink);
});

onUnmounted(() => {
  window.removeEventListener('plane:open-create-link', handlePlaneCreateLink);
});
</script>

<template>
  <div>
    <div class="px-4 pt-3 pb-2">
      <NextButton
        ghost
        xs
        icon="i-lucide-plus"
        :label="$t('INTEGRATION_SETTINGS.PLANE.ADD_OR_LINK_BUTTON')"
        @click="openCreateModal"
      />
    </div>

    <div v-if="isLoading" class="flex justify-center p-8">
      <Spinner />
    </div>

    <div v-else-if="!hasIssues" class="flex justify-center p-4">
      <p class="text-sm text-n-slate-11">
        {{ $t('INTEGRATION_SETTINGS.PLANE.NO_LINKED_ISSUES') }}
      </p>
    </div>

    <div v-else class="space-y-2 px-4 pb-4">
      <PlaneIssueItem
        v-for="issue in linkedIssues"
        :key="issue.id"
        :issue="issue"
        :conversation-id="props.conversationId"
        @unlink="unlinkIssue"
        @refresh="refresh"
      />
    </div>

    <CreateOrLinkIssue
      v-if="shouldShowCreateModal"
      :conversation-id="props.conversationId"
      @close="closeCreateModal"
    />
  </div>
</template>
