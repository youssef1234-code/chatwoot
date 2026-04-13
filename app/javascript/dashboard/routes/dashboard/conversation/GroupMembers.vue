<script>
import Thumbnail from 'dashboard/components/widgets/Thumbnail.vue';
import Spinner from 'dashboard/components-next/spinner/Spinner.vue';
import { mapGetters } from 'vuex';
import { frontendURL } from 'dashboard/helper/URLHelper';

export default {
  components: {
    Thumbnail,
    Spinner,
  },
  props: {
    conversationId: {
      type: [Number, String],
      required: true,
    },
  },
  computed: {
    ...mapGetters({
      currentAccountId: 'getCurrentAccountId',
    }),
    contactParticipants() {
      return this.$store.getters[
        'conversationContactParticipants/getByConversationId'
      ](this.conversationId);
    },
    uiFlags() {
      return this.$store.getters[
        'conversationContactParticipants/getUIFlags'
      ];
    },
  },
  watch: {
    conversationId(newId, oldId) {
      if (newId && newId !== oldId) {
        this.fetchContactParticipants();
      }
    },
  },
  mounted() {
    this.fetchContactParticipants();
  },
  methods: {
    fetchContactParticipants() {
      this.$store.dispatch('conversationContactParticipants/show', {
        conversationId: this.conversationId,
      });
    },
    contactUrl(contactId) {
      return frontendURL(
        `accounts/${this.currentAccountId}/contacts/${contactId}`
      );
    },
  },
};
</script>

<template>
  <div v-if="!uiFlags.isFetching">
    <div
      v-if="!contactParticipants.length"
      class="no-members-message px-4 p-3"
    >
      <span class="text-sm text-slate-500 dark:text-slate-400">
        {{ $t('CONVERSATION_SIDEBAR.NO_GROUP_MEMBERS') }}
      </span>
    </div>
    <div v-else class="group-members-list px-4 py-2 flex flex-col gap-1">
      <router-link
        v-for="contact in contactParticipants"
        :key="contact.id"
        :to="contactUrl(contact.id)"
        class="group-member-item flex items-center gap-3 px-3 py-2 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-800 transition-colors"
      >
        <Thumbnail
          :src="contact.thumbnail"
          :username="contact.name"
          size="28px"
        />
        <div class="flex flex-col min-w-0">
          <span
            class="text-sm font-medium text-slate-800 dark:text-slate-100 truncate"
          >
            {{ contact.name }}
          </span>
          <span
            v-if="contact.phone_number"
            class="text-xs text-slate-500 dark:text-slate-400 truncate"
          >
            {{ contact.phone_number }}
          </span>
        </div>
      </router-link>
    </div>
  </div>
  <div v-else class="flex items-center justify-center py-5">
    <Spinner />
  </div>
</template>

<style scoped>
.group-member-item {
  text-decoration: none;
}
</style>
