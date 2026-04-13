<template>
  <Modal
    :show="showModal"
    :on-close="() => $emit('close')"
    :close-on-backdrop-click="false"
  >
    <div class="w-full max-w-4xl mx-auto">
      <div class="flex flex-col h-[700px]">
        <!-- Header -->
        <div
          class="flex items-center justify-between p-6 border-b border-slate-200 dark:border-slate-600"
        >
          <div class="flex items-center gap-4">
            <div
              class="w-10 h-10 bg-purple-600 rounded-lg text-white text-lg flex items-center justify-center font-bold"
            >
              T
            </div>
            <div>
              <h2
                class="text-lg font-semibold text-slate-900 dark:text-slate-100"
              >
                {{ $t("TICKETS.DETAIL.TITLE") }} #{{ ticket.id }}
              </h2>
              <div class="flex items-center gap-3 mt-1">
                <!-- Status Badge -->
                <span
                  class="px-2 py-1 text-xs font-medium rounded-full border"
                  :class="getStatusBadgeColor(effectiveStatus)"
                >
                  {{ $t(`TICKETS.STATUS.${effectiveStatus?.toUpperCase()}`) }}
                </span>
                <!-- Priority Badge -->
                <span
                  class="px-2 py-1 text-xs font-medium rounded-full border"
                  :class="getPriorityBadgeColor(ticket.priority)"
                >
                  {{ $t(`TICKETS.PRIORITY.${ticket.priority?.toUpperCase()}`) }}
                </span>
                <!-- Category Badge -->
                <span
                  v-if="ticket.category"
                  class="px-2 py-1 text-xs font-medium rounded-full border bg-purple-50 text-purple-700 border-purple-200 dark:bg-purple-900/20 dark:text-purple-300 dark:border-purple-800"
                >
                  {{ ticket.category }}
                </span>
                <!-- JIRA Badge -->
                <span
                  v-if="ticket.jira_issue_key"
                  class="px-2 py-1 text-xs font-medium rounded-full bg-blue-50 text-blue-700 border border-blue-200"
                >
                  {{ ticket.jira_issue_key }}
                </span>
                <!-- Plane Badge -->
                <span
                  v-if="ticket.plane_issue_id"
                  class="px-2 py-1 text-xs font-medium rounded-full bg-indigo-50 text-indigo-700 border border-indigo-200"
                >
                  {{ $t('TICKETS.PLANE_LINKED') }}
                </span>
              </div>
            </div>
          </div>
        </div>

        <!-- Tabs Navigation -->
        <div class="flex border-b border-slate-200 dark:border-slate-600">
          <button
            v-for="tab in tabs"
            :key="tab.id"
            @click="activeTab = tab.id"
            :class="[
              activeTab === tab.id
                ? 'text-blue-600 dark:text-blue-400 border-b-2 border-blue-600 dark:border-blue-400 bg-blue-50 dark:bg-blue-900/30'
                : 'text-slate-600 dark:text-slate-400 hover:text-slate-800 dark:hover:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700',
              'flex-1 px-6 py-3 text-sm font-medium transition-colors',
            ]"
          >
            <Icon :icon="tab.icon" class="w-4 h-4 mr-2" />
            {{ tab.label }}
          </button>
        </div>

        <!-- Tab Content -->
        <div class="flex-1 overflow-hidden">
          <!-- Basic Information Tab -->
          <div
            v-show="activeTab === 'basic'"
            class="h-full overflow-y-auto p-6 space-y-6"
          >
            <form @submit.prevent="saveChanges" class="space-y-6">
              <!-- Title -->
              <div>
                <label class="block text-sm font-medium text-n-slate-12 mb-2">
                  {{ $t("TICKETS.TRACKING.TITLE") }} *
                </label>
                <input
                  v-model="editForm.title"
                  type="text"
                  class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                  :placeholder="$t('TICKETS.TRACKING.SEARCH_PLACEHOLDER')"
                  required
                  @input="markAsChanged"
                />
                <p v-if="errors.title" class="mt-1 text-sm text-red-600">
                  {{ errors.title }}
                </p>
              </div>

              <!-- Description -->
              <div>
                <label class="block text-sm font-medium text-n-slate-12 mb-2">
                  {{ $t("TICKETS.DESCRIPTION") }}
                </label>
                <textarea
                  v-model="editForm.description"
                  rows="4"
                  class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                  :placeholder="$t('TICKETS.DESCRIPTION_PLACEHOLDER')"
                  @input="markAsChanged"
                ></textarea>
                <p v-if="errors.description" class="mt-1 text-sm text-red-600">
                  {{ errors.description }}
                </p>
              </div>

              <!-- Status, Priority, and Category in one row -->
              <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div>
                  <label class="block text-sm font-medium text-n-slate-12 mb-2">
                    {{ $t("TICKETS.STATUS.LABEL") }}
                  </label>
                  <select
                    v-model="editForm.status"
                    class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                    @change="markAsChanged"
                  >
                    <option value="open">
                      {{ $t("TICKETS.STATUS.OPEN") }}
                    </option>
                    <option value="in_progress">
                      {{ $t("TICKETS.STATUS.IN_PROGRESS") }}
                    </option>
                    <option value="escalated">
                      {{ $t("TICKETS.STATUS.ESCALATED") }}
                    </option>
                    <option value="resolved">
                      {{ $t("TICKETS.STATUS.RESOLVED") }}
                    </option>
                    <option value="closed">
                      {{ $t("TICKETS.STATUS.CLOSED") }}
                    </option>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium text-n-slate-12 mb-2">
                    {{ $t("TICKETS.PRIORITY.LABEL") }}
                  </label>
                  <select
                    v-model="editForm.priority"
                    class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                    @change="markAsChanged"
                  >
                    <option value="low">
                      {{ $t("TICKETS.PRIORITY.LOW") }}
                    </option>
                    <option value="medium">
                      {{ $t("TICKETS.PRIORITY.MEDIUM") }}
                    </option>
                    <option value="high">
                      {{ $t("TICKETS.PRIORITY.HIGH") }}
                    </option>
                    <option value="urgent">
                      {{ $t("TICKETS.PRIORITY.URGENT") }}
                    </option>
                  </select>
                </div>
                <div>
                  <label class="block text-sm font-medium text-n-slate-12 mb-2">
                    {{ $t("TICKETS.CATEGORY.LABEL") }}
                  </label>
                  <select
                    v-model="editForm.category"
                    class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                    @change="markAsChanged"
                  >
                    <option value="">
                      {{ $t("TICKETS.CATEGORY.SELECT") }}
                    </option>
                    <option
                      v-for="category in availableCategories"
                      :key="category"
                      :value="category"
                    >
                      {{ category }}
                    </option>
                  </select>
                </div>
              </div>

              <!-- Assigned Agent -->
              <div>
                <label class="block text-sm font-medium text-n-slate-12 mb-2">
                  {{ $t("TICKETS.DETAIL.ASSIGNED_AGENT") }}
                </label>
                <select
                  v-model="editForm.assigned_agent_id"
                  class="w-full px-3 py-2 border border-n-slate-6 rounded-md focus:outline-none focus:ring-2 focus:ring-n-blue-6 bg-n-slate-1 text-n-slate-12"
                  @change="markAsChanged"
                >
                  <option value="">{{ $t("TICKETS.UNASSIGNED") }}</option>
                  <option
                    v-for="agent in agents"
                    :key="agent.id"
                    :value="agent.id"
                  >
                    {{ agent.name }}
                  </option>
                </select>
                <div
                  v-if="assignedAgent"
                  class="mt-3 flex items-center gap-3 p-3 bg-n-slate-2 rounded-lg border border-n-weak"
                >
                  <div
                    class="w-8 h-8 bg-gradient-to-br from-green-500 to-teal-600 rounded-full flex items-center justify-center text-white text-sm font-medium"
                  >
                    {{ getInitials(assignedAgent.name) }}
                  </div>
                  <div>
                    <p class="font-medium text-n-slate-12">
                      {{ assignedAgent.name }}
                    </p>
                    <p class="text-sm text-n-slate-10">
                      {{ assignedAgent.email }}
                    </p>
                  </div>
                </div>
              </div>

              <!-- Enhanced Customer Information -->
              <div
                v-if="ticket.contact"
                class="p-6 bg-n-slate-2 rounded-lg border border-n-weak"
              >
                <div class="flex items-center justify-between mb-4">
                  <h3
                    class="text-lg font-semibold text-n-slate-12 flex items-center gap-2"
                  >
                    <Icon icon="i-lucide-user-circle" class="w-5 h-5" />
                    {{ $t("TICKETS.DETAIL.CUSTOMER_INFO") }}
                  </h3>
                  <Button ghost slate size="sm" @click="openCustomerProfile">
                    <Icon icon="i-lucide-external-link" class="w-4 h-4 mr-2" />
                    {{ $t("TICKETS.DETAIL.VIEW_PROFILE") }}
                  </Button>
                </div>
                <div class="space-y-4">
                  <!-- Customer Name and Avatar -->
                  <div
                    class="flex items-center gap-4 p-3 bg-n-slate-1 rounded-lg"
                  >
                    <div
                      class="w-12 h-12 bg-gradient-to-br from-blue-500 to-purple-600 rounded-full flex items-center justify-center text-white text-lg font-bold"
                    >
                      {{ getInitials(ticket.contact.name) }}
                    </div>
                    <div class="flex-1">
                      <h4 class="font-semibold text-n-slate-12 text-lg">
                        {{ ticket.contact.name }}
                      </h4>
                      <p class="text-n-slate-10">{{ ticket.contact.email }}</p>
                    </div>
                  </div>

                  <!-- Contact Details Grid -->
                  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                    <!-- Phone -->
                    <div
                      v-if="ticket.contact.phone_number"
                      class="flex items-center gap-3 p-3 bg-n-slate-1 rounded-lg"
                    >
                      <div
                        class="w-8 h-8 bg-blue-100 dark:bg-blue-900/30 rounded-lg flex items-center justify-center"
                      >
                        <Icon
                          icon="i-lucide-phone"
                          class="w-4 h-4 text-blue-600 dark:text-blue-400"
                        />
                      </div>
                      <div>
                        <p
                          class="text-xs font-medium text-n-slate-10 uppercase tracking-wide"
                        >
                          Phone
                        </p>
                        <p class="text-sm font-medium text-n-slate-12">
                          {{ ticket.contact.phone_number }}
                        </p>
                      </div>
                    </div>

                    <!-- Location -->
                    <div
                      v-if="ticket.contact.location"
                      class="flex items-center gap-3 p-3 bg-n-slate-1 rounded-lg"
                    >
                      <div
                        class="w-8 h-8 bg-green-100 dark:bg-green-900/30 rounded-lg flex items-center justify-center"
                      >
                        <Icon
                          icon="i-lucide-map-pin"
                          class="w-4 h-4 text-green-600 dark:text-green-400"
                        />
                      </div>
                      <div>
                        <p
                          class="text-xs font-medium text-n-slate-10 uppercase tracking-wide"
                        >
                          Location
                        </p>
                        <p class="text-sm font-medium text-n-slate-12">
                          {{ ticket.contact.location }}
                        </p>
                      </div>
                    </div>
                  </div>

                  <!-- Organization -->
                  <div
                    v-if="ticket.contact.company || ticket.contact.organization"
                    class="p-4 bg-gradient-to-r from-purple-50 to-pink-50 dark:from-purple-900/20 dark:to-pink-900/20 rounded-lg border border-purple-200 dark:border-purple-800"
                  >
                    <div class="flex items-center gap-3">
                      <div
                        class="w-10 h-10 bg-purple-100 dark:bg-purple-900/50 rounded-lg flex items-center justify-center"
                      >
                        <Icon
                          icon="i-lucide-building-2"
                          class="w-5 h-5 text-purple-600 dark:text-purple-400"
                        />
                      </div>
                      <div class="flex-1">
                        <p
                          class="text-xs font-semibold text-purple-700 dark:text-purple-300 uppercase tracking-wide"
                        >
                          Organization
                        </p>
                        <h4
                          class="text-lg font-bold text-purple-900 dark:text-purple-100"
                        >
                          {{
                            ticket.contact.company ||
                            ticket.contact.organization
                          }}
                        </h4>
                        <p
                          v-if="ticket.contact.company_size"
                          class="text-sm text-purple-700 dark:text-purple-300"
                        >
                          {{ ticket.contact.company_size }} employees
                        </p>
                      </div>
                    </div>
                  </div>

                  <!-- Additional Info -->
                  <div
                    v-if="
                      ticket.contact.additional_attributes &&
                      Object.keys(ticket.contact.additional_attributes).length >
                        0
                    "
                    class="space-y-2"
                  >
                    <h5
                      class="text-sm font-semibold text-n-slate-12 flex items-center gap-2"
                    >
                      <Icon icon="i-lucide-info" class="w-4 h-4" />
                      Additional Information
                    </h5>
                    <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
                      <div
                        v-for="(value, key) in ticket.contact
                          .additional_attributes"
                        :key="key"
                        class="flex items-center gap-2 p-2 bg-n-slate-1 rounded text-sm"
                      >
                        <span class="font-medium text-n-slate-10 capitalize"
                          >{{ key.replace(/_/g, " ") }}:</span
                        >
                        <span class="text-n-slate-12">{{ value }}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Escalation Section -->
              <div
                v-if="canEscalateToJira || canEscalateToPlane"
                class="p-4 bg-amber-50 dark:bg-amber-900/20 rounded-lg border border-amber-200 dark:border-amber-800"
              >
                <h3
                  class="text-sm font-medium text-amber-900 dark:text-amber-100 mb-3"
                >
                  {{ $t("TICKETS.DETAIL.ESCALATION") }}
                </h3>
                <div class="flex flex-wrap items-center gap-3">
                  <Button
                    v-if="canEscalateToJira"
                    amber
                    size="sm"
                    :loading="isEscalating"
                    @click="showEscalateModal"
                  >
                    {{ $t("TICKETS.DETAIL.ESCALATE_TO_JIRA") }}
                  </Button>
                  <Button
                    v-if="canEscalateToPlane"
                    variant="solid"
                    color="indigo"
                    size="sm"
                    @click="showEscalateToPlaneModal = true"
                  >
                    {{ $t("TICKETS.DETAIL.ESCALATE_TO_PLANE") }}
                  </Button>
                </div>
                <p class="text-xs text-amber-800 dark:text-amber-200 mt-2">
                  {{ $t("TICKETS.DETAIL.ESCALATE_DESCRIPTION") }}
                </p>
              </div>

              <!-- Timestamps -->
              <div class="p-4 bg-n-slate-2 rounded-lg border border-n-weak">
                <h3
                  class="text-sm font-medium text-n-slate-12 mb-3 flex items-center gap-2"
                >
                  <Icon icon="i-lucide-clock" class="w-4 h-4" />
                  {{ $t("TICKETS.DETAIL.TIMESTAMPS") }}
                </h3>
                <div class="space-y-2 text-sm">
                  <div class="flex justify-between">
                    <span class="text-n-slate-10"
                      >{{ $t("TICKETS.DETAIL.CREATED_AT") }}:</span
                    >
                    <span class="text-n-slate-12 font-medium">{{
                      formatDate(ticket.created_at)
                    }}</span>
                  </div>
                  <div
                    v-if="ticket.updated_at !== ticket.created_at"
                    class="flex justify-between"
                  >
                    <span class="text-n-slate-10"
                      >{{ $t("TICKETS.DETAIL.UPDATED_AT") }}:</span
                    >
                    <span class="text-n-slate-12 font-medium">{{
                      formatDate(ticket.updated_at)
                    }}</span>
                  </div>
                  <div v-if="ticket.resolved_at" class="flex justify-between">
                    <span class="text-n-slate-10"
                      >{{ $t("TICKETS.DETAIL.RESOLVED_AT") }}:</span
                    >
                    <span class="text-n-slate-12 font-medium">{{
                      formatDate(ticket.resolved_at)
                    }}</span>
                  </div>
                  <div
                    v-if="ticket.duration_to_resolve"
                    class="flex justify-between"
                  >
                    <span class="text-n-slate-10"
                      >{{ $t("TICKETS.DETAIL.RESOLUTION_TIME") }}:</span
                    >
                    <span class="text-n-slate-12 font-medium">{{
                      ticket.duration_to_resolve
                    }}</span>
                  </div>
                </div>
              </div>
            </form>
          </div>

          <!-- JIRA Integration Tab -->
          <div v-show="activeTab === 'jira'" class="h-full overflow-y-auto p-6">
            <div
              v-if="ticket.jira_issue_key || canEscalateToJira"
              class="max-w-2xl"
            >
              <!-- Existing JIRA Issue -->
              <div
                v-if="ticket.jira_issue_key"
                class="p-6 bg-gradient-to-br from-blue-50 to-indigo-50 dark:from-blue-900/30 dark:to-indigo-900/30 rounded-xl border-2 border-blue-200 dark:border-blue-700 shadow-lg"
              >
                <div class="flex items-center justify-between mb-6">
                  <div class="flex items-center gap-4">
                    <div
                      class="w-12 h-12 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-xl flex items-center justify-center shadow-md"
                    >
                      <Icon
                        icon="i-lucide-external-link"
                        class="w-6 h-6 text-white"
                      />
                    </div>
                    <div>
                      <h3
                        class="text-xl font-bold text-blue-900 dark:text-blue-100 flex items-center gap-2"
                      >
                        {{ ticket.jira_issue_key }}
                        <span
                          class="px-2 py-1 bg-blue-100 dark:bg-blue-800 text-blue-800 dark:text-blue-200 rounded-full text-xs font-medium"
                        >
                          LINKED
                        </span>
                      </h3>
                      <p
                        class="text-sm text-blue-700 dark:text-blue-300 flex items-center gap-1"
                      >
                        <Icon icon="i-lucide-link" class="w-4 h-4" />
                        {{ $t("TICKETS.DETAIL.LINKED_JIRA_ISSUE") }}
                      </p>
                    </div>
                  </div>
                  <Button
                    variant="solid"
                    color="blue"
                    size="lg"
                    @click="openJiraIssue"
                    class="shadow-md hover:shadow-lg transition-shadow"
                  >
                    <Icon icon="i-lucide-external-link" class="w-4 h-4 mr-2" />
                    {{ $t("TICKETS.VIEW_IN_JIRA") }}
                  </Button>
                </div>

                <!-- JIRA Issue Details -->
                <div v-if="jiraIssueDetails" class="space-y-6">
                  <div class="grid grid-cols-2 gap-6">
                    <div
                      class="p-4 bg-white dark:bg-slate-800 rounded-lg border border-blue-200 dark:border-blue-700"
                    >
                      <div class="flex items-center gap-2 mb-2">
                        <Icon
                          icon="i-lucide-activity"
                          class="w-4 h-4 text-green-600"
                        />
                        <span
                          class="text-sm font-semibold text-blue-800 dark:text-blue-200"
                        >
                          {{ $t("TICKETS.DETAIL.JIRA_STATUS") }}
                        </span>
                      </div>
                      <span
                        class="text-lg font-bold text-green-700 dark:text-green-400"
                      >
                        {{ jiraIssueDetails.status }}
                      </span>
                    </div>
                    <div
                      class="p-4 bg-white dark:bg-slate-800 rounded-lg border border-blue-200 dark:border-blue-700"
                    >
                      <div class="flex items-center gap-2 mb-2">
                        <Icon
                          icon="i-lucide-flag"
                          class="w-4 h-4 text-orange-600"
                        />
                        <span
                          class="text-sm font-semibold text-blue-800 dark:text-blue-200"
                        >
                          {{ $t("TICKETS.DETAIL.JIRA_PRIORITY") }}
                        </span>
                      </div>
                      <span
                        class="text-lg font-bold text-orange-700 dark:text-orange-400"
                      >
                        {{ jiraIssueDetails.priority || "Not set" }}
                      </span>
                    </div>
                  </div>

                  <div
                    class="p-4 bg-white dark:bg-slate-800 rounded-lg border border-blue-200 dark:border-blue-700"
                  >
                    <div class="flex items-center gap-2 mb-3">
                      <Icon
                        icon="i-lucide-file-text"
                        class="w-4 h-4 text-purple-600"
                      />
                      <span
                        class="text-sm font-semibold text-blue-800 dark:text-blue-200"
                      >
                        {{ $t("TICKETS.DETAIL.JIRA_SUMMARY") }}
                      </span>
                    </div>
                    <p class="text-blue-900 dark:text-blue-100 font-medium">
                      {{ jiraIssueDetails.summary }}
                    </p>
                  </div>

                  <div
                    v-if="jiraIssueDetails.description"
                    class="p-4 bg-white dark:bg-slate-800 rounded-lg border border-blue-200 dark:border-blue-700"
                  >
                    <div class="flex items-center gap-2 mb-3">
                      <Icon
                        icon="i-lucide-align-left"
                        class="w-4 h-4 text-indigo-600"
                      />
                      <span
                        class="text-sm font-semibold text-blue-800 dark:text-blue-200"
                      >
                        {{ $t("TICKETS.DETAIL.JIRA_DESCRIPTION") }}
                      </span>
                    </div>
                    <p
                      class="text-blue-900 dark:text-blue-100 whitespace-pre-wrap"
                    >
                      {{ jiraIssueDetails.description }}
                    </p>
                  </div>

                  <div
                    v-if="jiraIssueDetails.assignee"
                    class="p-4 bg-white dark:bg-slate-800 rounded-lg border border-blue-200 dark:border-blue-700"
                  >
                    <div class="flex items-center gap-2 mb-3">
                      <Icon
                        icon="i-lucide-user-check"
                        class="w-4 h-4 text-emerald-600"
                      />
                      <span
                        class="text-sm font-semibold text-blue-800 dark:text-blue-200"
                      >
                        {{ $t("TICKETS.DETAIL.JIRA_ASSIGNEE") }}
                      </span>
                    </div>
                    <div class="flex items-center gap-3">
                      <div
                        class="w-8 h-8 bg-gradient-to-br from-emerald-500 to-teal-600 rounded-full flex items-center justify-center text-white text-sm font-bold"
                      >
                        {{ getInitials(jiraIssueDetails.assignee.displayName) }}
                      </div>
                      <span
                        class="text-blue-900 dark:text-blue-100 font-medium"
                      >
                        {{ jiraIssueDetails.assignee.displayName }}
                      </span>
                    </div>
                  </div>
                </div>

                <!-- Loading state for JIRA details -->
                <div
                  v-else-if="isLoadingJira"
                  class="flex items-center gap-2 text-blue-600"
                >
                  <Icon icon="i-lucide-loader-2" class="w-4 h-4 animate-spin" />
                  <span class="text-sm">{{
                    $t("TICKETS.DETAIL.LOADING_JIRA")
                  }}</span>
                </div>
              </div>

              <!-- Escalate to JIRA -->
              <div
                v-else-if="canEscalateToJira"
                class="p-6 bg-gradient-to-br from-orange-50 to-amber-50 dark:from-orange-900/30 dark:to-amber-900/30 rounded-xl border-2 border-orange-200 dark:border-orange-700 shadow-lg"
              >
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-4">
                    <div
                      class="w-12 h-12 bg-gradient-to-br from-orange-500 to-amber-600 rounded-xl flex items-center justify-center shadow-md"
                    >
                      <Icon
                        icon="i-lucide-trending-up"
                        class="w-6 h-6 text-white"
                      />
                    </div>
                    <div>
                      <h3
                        class="text-xl font-bold text-orange-900 dark:text-orange-100 flex items-center gap-2"
                      >
                        {{ $t("TICKETS.DETAIL.ESCALATE_TO_JIRA") }}
                        <span
                          class="px-2 py-1 bg-orange-100 dark:bg-orange-800 text-orange-800 dark:text-orange-200 rounded-full text-xs font-medium"
                        >
                          AVAILABLE
                        </span>
                      </h3>
                      <p
                        class="text-sm text-orange-800 dark:text-orange-200 flex items-center gap-1"
                      >
                        <Icon icon="i-lucide-arrow-up-right" class="w-4 h-4" />
                        {{ $t("TICKETS.DETAIL.ESCALATE_DESCRIPTION") }}
                      </p>
                    </div>
                  </div>
                  <Button
                    variant="solid"
                    color="orange"
                    size="lg"
                    :loading="isEscalating"
                    @click="showEscalateModal"
                    class="shadow-md hover:shadow-lg transition-shadow"
                  >
                    <Icon icon="i-lucide-trending-up" class="w-4 h-4 mr-2" />
                    {{ $t("TICKETS.DETAIL.ESCALATE") }}
                  </Button>
                </div>
              </div>
            </div>

            <div v-else class="text-center py-12">
              <Icon
                icon="i-lucide-external-link"
                class="w-12 h-12 text-slate-400 mx-auto mb-4"
              />
              <p class="text-slate-600 dark:text-slate-400">
                {{ $t("TICKETS.DETAIL.JIRA_NOT_AVAILABLE") }}
              </p>
            </div>
          </div>

          <!-- Plane Integration Tab -->
          <div v-show="activeTab === 'plane'" class="h-full overflow-y-auto p-6">
            <div
              v-if="ticket.plane_issue_id || canEscalateToPlane"
              class="max-w-2xl"
            >
              <!-- Existing Plane Issue -->
              <div
                v-if="ticket.plane_issue_id"
                class="p-6 bg-gradient-to-br from-indigo-50 to-violet-50 dark:from-indigo-900/30 dark:to-violet-900/30 rounded-xl border-2 border-indigo-200 dark:border-indigo-700 shadow-lg"
              >
                <div class="flex items-center justify-between mb-6">
                  <div class="flex items-center gap-4">
                    <div
                      class="w-12 h-12 bg-gradient-to-br from-indigo-500 to-violet-600 rounded-xl flex items-center justify-center shadow-md"
                    >
                      <Icon
                        icon="i-lucide-plane"
                        class="w-6 h-6 text-white"
                      />
                    </div>
                    <div>
                      <h3
                        class="text-xl font-bold text-indigo-900 dark:text-indigo-100 flex items-center gap-2"
                      >
                        {{ $t('TICKETS.PLANE_LINKED') }}
                        <span
                          class="px-2 py-1 bg-indigo-100 dark:bg-indigo-800 text-indigo-800 dark:text-indigo-200 rounded-full text-xs font-medium"
                        >
                          LINKED
                        </span>
                      </h3>
                      <p
                        class="text-sm text-indigo-700 dark:text-indigo-300 flex items-center gap-1"
                      >
                        <Icon icon="i-lucide-link" class="w-4 h-4" />
                        {{ $t("TICKETS.DETAIL.LINKED_PLANE_ISSUE") }}
                      </p>
                    </div>
                  </div>
                </div>
              </div>

              <!-- Escalate to Plane CTA -->
              <div
                v-else
                class="p-6 bg-gradient-to-br from-indigo-50 to-violet-50 dark:from-indigo-900/30 dark:to-violet-900/30 rounded-xl border-2 border-dashed border-indigo-300 dark:border-indigo-600"
              >
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-4">
                    <div
                      class="w-12 h-12 bg-gradient-to-br from-indigo-400 to-violet-500 rounded-xl flex items-center justify-center shadow-md"
                    >
                      <Icon
                        icon="i-lucide-plane"
                        class="w-6 h-6 text-white"
                      />
                    </div>
                    <div>
                      <h3
                        class="text-lg font-bold text-indigo-900 dark:text-indigo-100"
                      >
                        {{ $t("TICKETS.DETAIL.ESCALATE_TO_PLANE") }}
                      </h3>
                      <p
                        class="text-sm text-indigo-800 dark:text-indigo-200 flex items-center gap-1"
                      >
                        <Icon icon="i-lucide-arrow-up-right" class="w-4 h-4" />
                        {{ $t("TICKETS.DETAIL.ESCALATE_TO_PLANE_DESCRIPTION") }}
                      </p>
                    </div>
                  </div>
                  <Button
                    variant="solid"
                    color="indigo"
                    size="lg"
                    @click="showEscalateToPlaneModal = true"
                    class="shadow-md hover:shadow-lg transition-shadow"
                  >
                    <Icon icon="i-lucide-trending-up" class="w-4 h-4 mr-2" />
                    {{ $t("TICKETS.DETAIL.ESCALATE") }}
                  </Button>
                </div>
              </div>
            </div>

            <div v-else class="text-center py-12">
              <Icon
                icon="i-lucide-plane"
                class="w-12 h-12 text-slate-400 mx-auto mb-4"
              />
              <p class="text-slate-600 dark:text-slate-400">
                {{ $t("TICKETS.DETAIL.PLANE_NOT_AVAILABLE") }}
              </p>
            </div>
          </div>

          <!-- Conversation Tab -->
          <div
            v-show="activeTab === 'conversation'"
            class="h-full overflow-y-auto p-6"
          >
            <div class="max-w-2xl">
              <div class="p-6 bg-n-slate-2 rounded-lg border border-n-weak">
                <div class="flex items-center justify-between">
                  <div class="flex items-center gap-4">
                    <div
                      class="w-12 h-12 bg-gradient-to-br from-blue-500 to-indigo-600 rounded-lg flex items-center justify-center"
                    >
                      <Icon
                        icon="i-lucide-message-circle"
                        class="w-6 h-6 text-white"
                      />
                    </div>
                    <div>
                      <h3 class="text-lg font-medium text-n-slate-12">
                        {{
                          $t("TICKETS.DETAIL.CONVERSATION_ID", {
                            id: ticket.conversation?.id || "N/A",
                          })
                        }}
                      </h3>
                      <p class="text-sm text-n-slate-10">
                        {{ $t("TICKETS.DETAIL.STATUS") }}:
                        {{ ticket.conversation?.status || "N/A" }}
                      </p>
                    </div>
                  </div>
                  <Button
                    blue
                    :disabled="!ticket.conversation?.id"
                    @click="openConversation"
                  >
                    {{ $t("TICKETS.DETAIL.OPEN_CONVERSATION") }}
                  </Button>
                </div>
              </div>
            </div>
          </div>

          <!-- Messages Tab -->
          <div v-show="activeTab === 'messages'" class="h-full flex flex-col">
            <div class="p-6 border-b border-slate-200 dark:border-slate-600">
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-medium text-n-slate-12">
                  {{ $t("TICKETS.LINKED_MESSAGES.TITLE") }}
                </h3>
                <span class="text-sm text-n-slate-10">
                  {{ messages.length }} {{ $t("TICKETS.DETAIL.MESSAGES") }}
                </span>
              </div>
            </div>

            <div class="flex-1 overflow-y-auto p-6">
              <div v-if="isLoadingMessages" class="space-y-4">
                <div
                  v-for="n in 3"
                  :key="n"
                  class="animate-pulse bg-n-slate-3 rounded-lg p-4 h-24"
                />
              </div>

              <div v-else-if="messages.length === 0" class="text-center py-12">
                <Icon
                  icon="i-lucide-message-circle"
                  class="w-12 h-12 text-slate-400 mx-auto mb-4"
                />
                <p class="text-n-slate-10">
                  {{ $t("TICKETS.NO_MESSAGES_IN_TICKET") }}
                </p>
              </div>

              <div v-else class="space-y-4">
                <MessageItem
                  v-for="message in messages"
                  :key="message.id"
                  :message="message"
                  :compact="false"
                />
              </div>
            </div>
          </div>
        </div>

        <!-- Footer with Save/Cancel -->
        <div
          v-if="hasChanges"
          class="p-6 border-t border-slate-200 dark:border-slate-600 bg-n-slate-2"
        >
          <div class="flex items-center justify-between">
            <p class="text-sm text-n-slate-10">
              {{ $t("TICKETS.DETAIL.UNSAVED_CHANGES") }}
            </p>
            <div class="flex items-center gap-3">
              <Button
                ghost
                slate
                @click="discardChanges"
                :disabled="isUpdating"
              >
                {{ $t("TICKETS.DETAIL.DISCARD_CHANGES") }}
              </Button>
              <Button blue :loading="isUpdating" @click="saveChanges">
                {{ $t("TICKETS.DETAIL.SAVE_CHANGES") }}
              </Button>
            </div>
          </div>
        </div>

        <!-- Footer Actions -->
        <div v-else class="p-6 border-t border-slate-200 dark:border-slate-600">
          <div class="flex items-center justify-between">
            <div class="text-sm text-n-slate-10">
              {{ $t("TICKETS.DETAIL.LAST_UPDATED") }}:
              {{ formatDate(ticket.updated_at) }}
            </div>
            <div class="flex items-center gap-3">
              <Button
                v-if="
                  ticket.status !== 'resolved' && ticket.status !== 'closed'
                "
                variant="solid"
                color="blue"
                @click="resolveTicket"
                :loading="isUpdating"
              >
                {{ $t("TICKETS.DETAIL.RESOLVE") }}
              </Button>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- Escalate Modal -->
    <EscalateToJiraModal
      v-if="showEscalateToJiraModal"
      :ticket="ticket"
      @close="showEscalateToJiraModal = false"
      @escalated="handleEscalated"
    />

    <!-- Escalate to Plane Modal -->
    <EscalateToPlaneModal
      v-if="showEscalateToPlaneModal"
      :ticket="ticket"
      @close="showEscalateToPlaneModal = false"
      @escalated="handlePlaneEscalated"
    />
  </Modal>
</template>

<script>
import { ref, computed, onMounted, reactive, watch } from "vue";
import { useStore } from "vuex";
import { useI18n } from "vue-i18n";
import { useRouter } from "vue-router";
import { format } from "date-fns";

import Modal from "dashboard/components/Modal.vue";
import Button from "dashboard/components-next/button/Button.vue";
import Icon from "dashboard/components-next/icon/Icon.vue";
import MessageItem from "./MessageItem.vue";
import EscalateToJiraModal from "dashboard/components/tickets/EscalateToJiraModal.vue";
import EscalateToPlaneModal from "dashboard/components/tickets/EscalateToPlaneModal.vue";

import { useAlert } from "dashboard/composables";
import { useFunctionGetter, useMapGetter } from "dashboard/composables/store";
import { FEATURE_FLAGS } from "dashboard/featureFlags";
import TicketsAPI from "dashboard/api/tickets";

export default {
  name: "TicketDetailModal",
  components: {
    Modal,
    Button,
    Icon,
    MessageItem,
    EscalateToJiraModal,
    EscalateToPlaneModal,
  },
  props: {
    ticket: {
      type: Object,
      required: true,
    },
    currentUser: {
      type: Object,
      required: true,
    },
  },
  emits: ["close", "updated", "refresh"],
  setup(props, { emit }) {
    const store = useStore();
    const { t } = useI18n();
    const router = useRouter();

    // Integration availability detection
    const currentAccountId = useMapGetter('getCurrentAccountId');
    const isFeatureEnabledonAccount = useMapGetter('accounts/isFeatureEnabledonAccount');

    const jiraIntegration = useFunctionGetter('integrations/getIntegration', 'jira');
    const isJiraIntegrationEnabled = computed(() => jiraIntegration.value?.enabled || false);
    const isJiraFeatureEnabled = computed(() => {
      const fn = isFeatureEnabledonAccount.value;
      return fn ? fn(currentAccountId.value, FEATURE_FLAGS.JIRA) : false;
    });
    const isJiraAvailable = computed(() => isJiraIntegrationEnabled.value || isJiraFeatureEnabled.value);

    const planeIntegration = useFunctionGetter('integrations/getIntegration', 'plane');
    const isPlaneIntegrationEnabled = computed(() => planeIntegration.value?.enabled || false);
    const isPlaneFeatureEnabled = computed(() => {
      const fn = isFeatureEnabledonAccount.value;
      return fn ? fn(currentAccountId.value, FEATURE_FLAGS.PLANE) : false;
    });
    const isPlaneAvailable = computed(() => isPlaneIntegrationEnabled.value || isPlaneFeatureEnabled.value);
    const showAlert = useAlert();

    // State
    const isUpdating = ref(false);
    const isRefreshing = ref(false);
    const isLoadingMessages = ref(false);
    const isLoadingJira = ref(false);
    const isEscalating = ref(false);
    const messages = ref([]);
    const jiraIssueDetails = ref(null);
    const showModal = ref(true);
    const activeTab = ref("basic");
    const hasChanges = ref(false);
    const showEscalateToJiraModal = ref(false);
    const showEscalateToPlaneModal = ref(false);
    const errors = ref({});

    // Tabs configuration
    const tabs = computed(() => [
      {
        id: "basic",
        label: t("TICKETS.DETAIL.BASIC_INFO"),
        icon: "i-lucide-info",
      },
      {
        id: "conversation",
        label: t("TICKETS.DETAIL.CONVERSATION"),
        icon: "i-lucide-message-circle",
      },
      {
        id: "messages",
        label: t("TICKETS.DETAIL.LINKED_MESSAGES"),
        icon: "i-lucide-messages-square",
      },
      ...(props.ticket.jira_issue_key || canEscalateToJira.value
        ? [
            {
              id: "jira",
              label: t("TICKETS.DETAIL.JIRA_INTEGRATION"),
              icon: "i-lucide-external-link",
            },
          ]
        : []),
      ...(props.ticket.plane_issue_id || canEscalateToPlane.value
        ? [
            {
              id: "plane",
              label: t("TICKETS.DETAIL.PLANE_INTEGRATION"),
              icon: "i-lucide-plane",
            },
          ]
        : []),
    ]);

    // Original form data for comparison
    const originalForm = reactive({
      title: props.ticket.title || "",
      description: props.ticket.description || "",
      status: props.ticket.status || "open",
      priority: props.ticket.priority || "medium",
      category: props.ticket.category || "",
      assigned_agent_id: props.ticket.assigned_agent?.id || "",
    });

    // Edit form
    const editForm = reactive({
      title: props.ticket.title || "",
      description: props.ticket.description || "",
      status: props.ticket.status || "open",
      priority: props.ticket.priority || "medium",
      category: props.ticket.category || "",
      assigned_agent_id: props.ticket.assigned_agent?.id || "",
    });

    // Computed
    const agents = computed(() => store.getters["agents/getAgents"] || []);

    const currentAccount = computed(() => {
      const accountId = store.getters.getCurrentAccountId;
      const accountFromAccountsStore =
        store.getters["accounts/getAccount"](accountId);
      if (
        accountFromAccountsStore &&
        Object.keys(accountFromAccountsStore).length > 0
      ) {
        return accountFromAccountsStore;
      }
    });

    // Get available categories from account settings
    const availableCategories = computed(() => {
      return currentAccount.value?.settings?.ticket_categories || [];
    });

    const assignedAgent = computed(() => {
      if (!editForm.assigned_agent_id) return null;
      return agents.value.find(
        (agent) => agent.id === editForm.assigned_agent_id
      );
    });

    const canEscalateToJira = computed(() => {
      return (
        isJiraIntegrationEnabled.value &&
        !props.ticket.jira_issue_key &&
        (props.ticket.status === "open" ||
          props.ticket.status === "in_progress")
      );
    });

    const canEscalateToPlane = computed(() => {
      return (
        isPlaneIntegrationEnabled.value &&
        !props.ticket.plane_issue_id &&
        (props.ticket.status === "open" ||
          props.ticket.status === "in_progress")
      );
    });

    // Compute the effective status - prioritize in_progress
    const effectiveStatus = computed(() => {
      // If ticket status is in_progress, show it
      if (props.ticket.status === "in_progress") {
        return "in_progress";
      }

      // If ticket is actively being worked on in JIRA, show in_progress
      if (
        props.ticket.jira_in_progress &&
        props.ticket.status !== "resolved" &&
        props.ticket.status !== "closed"
      ) {
        return "in_progress";
      }

      // Otherwise, show the actual status
      return props.ticket.status;
    });

    // Badge color functions
    const getStatusBadgeColor = (status) => {
      const colors = {
        open: "bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-900/20 dark:text-blue-300 dark:border-blue-800",
        in_progress:
          "bg-yellow-50 text-yellow-700 border-yellow-200 dark:bg-yellow-900/20 dark:text-yellow-300 dark:border-yellow-800",
        escalated:
          "bg-orange-50 text-orange-700 border-orange-200 dark:bg-orange-900/20 dark:text-orange-300 dark:border-orange-800",
        resolved:
          "bg-green-50 text-green-700 border-green-200 dark:bg-green-900/20 dark:text-green-300 dark:border-green-800",
        closed:
          "bg-gray-50 text-gray-700 border-gray-200 dark:bg-gray-900/20 dark:text-gray-300 dark:border-gray-800",
      };
      return colors[status] || colors.open;
    };

    const getPriorityBadgeColor = (priority) => {
      const colors = {
        low: "bg-green-50 text-green-700 border-green-200 dark:bg-green-900/20 dark:text-green-300 dark:border-green-800",
        medium:
          "bg-yellow-50 text-yellow-700 border-yellow-200 dark:bg-yellow-900/20 dark:text-yellow-300 dark:border-yellow-800",
        high: "bg-orange-50 text-orange-700 border-orange-200 dark:bg-orange-900/20 dark:text-orange-300 dark:border-orange-800",
        urgent:
          "bg-red-50 text-red-700 border-red-200 dark:bg-red-900/20 dark:text-red-300 dark:border-red-800",
      };
      return colors[priority] || colors.medium;
    };

    const getInitials = (name) => {
      return (
        name
          ?.split(" ")
          .map((word) => word[0])
          .join("")
          .toUpperCase()
          .slice(0, 2) || "??"
      );
    };

    // Methods
    const markAsChanged = () => {
      hasChanges.value = true;
    };

    const checkForChanges = () => {
      hasChanges.value =
        editForm.title !== originalForm.title ||
        editForm.description !== originalForm.description ||
        editForm.status !== originalForm.status ||
        editForm.priority !== originalForm.priority ||
        editForm.category !== originalForm.category ||
        editForm.assigned_agent_id !== originalForm.assigned_agent_id;
    };

    const saveChanges = async () => {
      isUpdating.value = true;
      errors.value = {};

      try {
        const updates = {};

        if (editForm.title !== originalForm.title)
          updates.title = editForm.title;
        if (editForm.description !== originalForm.description)
          updates.description = editForm.description;
        if (editForm.status !== originalForm.status)
          updates.status = editForm.status;
        if (editForm.priority !== originalForm.priority)
          updates.priority = editForm.priority;
        if (editForm.category !== originalForm.category)
          updates.category = editForm.category;
        if (editForm.assigned_agent_id !== originalForm.assigned_agent_id)
          updates.assigned_agent_id = editForm.assigned_agent_id;

        if (Object.keys(updates).length > 0) {
          await store.dispatch("tickets/update", {
            ticketId: props.ticket.id,
            ...updates,
          });

          // Update original form with new values
          Object.assign(originalForm, editForm);
          hasChanges.value = false;

          emit("updated");
          showAlert(t("TICKETS.DETAIL.UPDATE_SUCCESS"));
        }
      } catch (error) {
        console.error("Failed to update ticket:", error);
        if (error.response?.data?.errors) {
          errors.value = error.response.data.errors;
        }
        showAlert(t("TICKETS.DETAIL.UPDATE_ERROR"));
      } finally {
        isUpdating.value = false;
      }
    };

    const discardChanges = () => {
      Object.assign(editForm, originalForm);
      hasChanges.value = false;
      errors.value = {};
    };

    const loadMessages = async () => {
      isLoadingMessages.value = true;
      try {
        const response = await TicketsAPI.getMessages(props.ticket.id);
        messages.value = response.data.messages || [];
      } catch (error) {
        console.error("Failed to load messages:", error);
        // Don't show alert on modal open to avoid dark popup
      } finally {
        isLoadingMessages.value = false;
      }
    };

    const loadJiraDetails = async () => {
      if (!props.ticket.jira_issue_key) return;

      isLoadingJira.value = true;
      try {
        const JiraAPI = await import("dashboard/api/integrations/jira");
        const response = await JiraAPI.default.getIssue(
          props.ticket.jira_issue_key
        );
        jiraIssueDetails.value = response.data;
      } catch (error) {
        console.error("Failed to load JIRA details:", error);
        // Don't show alert on modal open to avoid dark popup
      } finally {
        isLoadingJira.value = false;
      }
    };

    const refreshTicket = async () => {
      isRefreshing.value = true;
      try {
        // Fetch the latest ticket data from the store
        const updatedTicket = await store.dispatch(
          "tickets/fetchTicket",
          props.ticket.id
        );

        // Update the local edit form with fresh data
        editForm.title = updatedTicket.title || props.ticket.title;
        editForm.description =
          updatedTicket.description || props.ticket.description;
        editForm.status = updatedTicket.status || props.ticket.status;
        editForm.priority = updatedTicket.priority || props.ticket.priority;
        editForm.assignee_id =
          updatedTicket.assigned_agent?.id || props.ticket.assigned_agent?.id;

        // Reload related data
        await loadMessages();
        if (updatedTicket.jira_issue_key || props.ticket.jira_issue_key) {
          await loadJiraDetails();
        }

        // Reset change tracking
        hasChanges.value = false;

        emit("refresh");
        // No alert shown on successful refresh
      } catch (error) {
        console.error("Failed to refresh ticket:", error);
        showAlert(t("TICKETS.DETAIL.REFRESH_ERROR"));
      } finally {
        isRefreshing.value = false;
      }
    };

    const openCustomerProfile = () => {
      if (props.ticket.contact?.id) {
        const accountId = store.getters.getCurrentAccountId;
        const contactUrl = `/app/accounts/${accountId}/contacts/${props.ticket.contact.id}`;
        router.push(contactUrl);
        emit("close");
      }
    };

    const openConversation = () => {
      if (props.ticket.conversation?.id) {
        router.push(
          `/app/accounts/${store.getters.getCurrentAccountId}/conversations/${props.ticket.conversation.id}`
        );
        emit("close");
      }
    };

    const openJiraIssue = () => {
      if (props.ticket.jira_url) {
        window.open(props.ticket.jira_url, "_blank");
      } else if (props.ticket.jira_issue_key) {
        // Fallback to constructed JIRA URL
        const baseUrl = store.getters["integrations/getJiraBaseUrl"];
        if (baseUrl) {
          window.open(
            `${baseUrl}/browse/${props.ticket.jira_issue_key}`,
            "_blank"
          );
        }
      }
    };

    const showEscalateModal = () => {
      showEscalateToJiraModal.value = true;
    };

    const handleEscalated = async (escalationData) => {
      try {
        // Close the escalation modal first
        showEscalateToJiraModal.value = false;

        // Wait a moment for the escalation to be processed
        await new Promise((resolve) => setTimeout(resolve, 1000));

        // Refresh ticket data to show JIRA info
        await refreshTicket();

        // Switch to JIRA tab to show the escalated ticket
        activeTab.value = "jira";

        // Emit updated event to parent
        emit("updated", escalationData);
        emit("refresh"); // Also emit refresh to ensure parent updates

        // Show success message without triggering alert
        console.log("Ticket successfully escalated to JIRA");
      } catch (error) {
        console.error("Error handling escalation:", error);
      }
    };

    const handlePlaneEscalated = async (escalationData) => {
      try {
        showEscalateToPlaneModal.value = false;

        await new Promise((resolve) => setTimeout(resolve, 1000));

        await refreshTicket();

        activeTab.value = "plane";

        emit("updated", escalationData);
        emit("refresh");

        console.log("Ticket successfully escalated to Plane");
      } catch (error) {
        console.error("Error handling Plane escalation:", error);
      }
    };

    const resolveTicket = async () => {
      isUpdating.value = true;
      try {
        await store.dispatch("tickets/resolve", props.ticket.id);
        emit("updated");
        showAlert(t("TICKETS.DETAIL.RESOLVE_SUCCESS"));
      } catch (error) {
        console.error("Failed to resolve ticket:", error);
        showAlert(t("TICKETS.DETAIL.RESOLVE_ERROR"));
      } finally {
        isUpdating.value = false;
      }
    };

    const formatDate = (dateString) => {
      if (!dateString) return "";
      try {
        return format(new Date(dateString), "MMM dd, yyyy HH:mm");
      } catch (error) {
        return dateString;
      }
    };

    // Watch for changes in edit form
    watch(
      [
        () => editForm.title,
        () => editForm.description,
        () => editForm.status,
        () => editForm.priority,
        () => editForm.category,
        () => editForm.assigned_agent_id,
      ],
      () => checkForChanges(),
      { deep: true }
    );

    // Watch for ticket changes (like after escalation)
    watch(
      () => props.ticket,
      (newTicket, oldTicket) => {
        if (newTicket && newTicket.id === oldTicket?.id) {
          // Update form with new ticket data
          editForm.title = newTicket.title || "";
          editForm.description = newTicket.description || "";
          editForm.status = newTicket.status || "open";
          editForm.priority = newTicket.priority || "medium";
          editForm.category = newTicket.category || "";
          editForm.assigned_agent_id = newTicket.assigned_agent?.id || "";

          // Reset change tracking
          hasChanges.value = false;

          // Reload JIRA details if escalated
          if (newTicket.jira_issue_key && !oldTicket?.jira_issue_key) {
            loadJiraDetails();
          }
        }
      },
      { deep: true }
    );

    // Load data on mount
    onMounted(() => {
      loadMessages();
      if (props.ticket.jira_issue_key) {
        loadJiraDetails();
      }
    });

    return {
      // State
      isUpdating,
      isRefreshing,
      isLoadingMessages,
      isLoadingJira,
      isEscalating,
      messages,
      jiraIssueDetails,
      showModal,
      activeTab,
      hasChanges,
      showEscalateToJiraModal,
      showEscalateToPlaneModal,
      errors,

      // Data
      tabs,
      editForm,
      agents,
      availableCategories,
      assignedAgent,

      // Computed
      canEscalateToJira,
      canEscalateToPlane,
      effectiveStatus,

      // Methods
      getStatusBadgeColor,
      getPriorityBadgeColor,
      getInitials,
      markAsChanged,
      saveChanges,
      discardChanges,
      refreshTicket,
      openCustomerProfile,
      openConversation,
      openJiraIssue,
      showEscalateModal,
      handleEscalated,
      handlePlaneEscalated,
      resolveTicket,
      formatDate,
    };
  },
};
</script>
<style scoped>
/* Custom scrollbar for messages */
.overflow-y-auto::-webkit-scrollbar {
  width: 4px;
}

.overflow-y-auto::-webkit-scrollbar-track {
  background: transparent;
}

.overflow-y-auto::-webkit-scrollbar-thumb {
  background: rgba(156, 163, 175, 0.5);
  border-radius: 2px;
}

.overflow-y-auto::-webkit-scrollbar-thumb:hover {
  background: rgba(156, 163, 175, 0.7);
}
</style>