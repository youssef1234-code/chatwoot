/**
 * Centralized Plane issues composable.
 *
 * SINGLE SOURCE OF TRUTH for Plane issue data per conversation.
 * All components MUST use this instead of independently fetching / listening.
 *
 * Architecture:
 * - Module-level global event listeners (registered ONCE on import)
 * - Per-conversation shared reactive state (Map keyed by conversationId)
 * - Debounced API refresh per conversation
 * - Optimistic local updates from websocket before API confirms
 * - Never clears data during re-fetch (no grey flash)
 */
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { emitter } from 'shared/helpers/mitt';
import PlaneAPI from 'dashboard/api/integrations/plane';

// ─── Canonical color map ────────────────────────────────────────────────────
const PLANE_STATE_COLORS = {
  backlog: '#94a3b8',
  unstarted: '#64748b',
  todo: '#64748b',
  started: '#3B82F6',
  in_progress: '#8B5CF6',
  in_review: '#D97706',
  review: '#D97706',
  done: '#16a34a',
  completed: '#16a34a',
  cancelled: '#dc2626',
  blocked: '#dc2626',
};

const DEFAULT_COLOR = '#6366f1';

export const getPlaneStateColor = (stateName, stateColor = null) => {
  if (stateColor && stateColor !== '#94a3b8') return stateColor;
  if (!stateName) return DEFAULT_COLOR;
  const key = stateName.toLowerCase().replace(/\s+/g, '_');
  return PLANE_STATE_COLORS[key] || DEFAULT_COLOR;
};

export const getPlaneStateBgColor = (stateName, stateColor = null) => {
  return `${getPlaneStateColor(stateName, stateColor)}20`;
};

// ─── Shared state registry ──────────────────────────────────────────────────
const _store = new Map(); // conversationId → { issues: ref([]), loading: ref(false), timer, refCount }

function _getState(conversationId) {
  const id = String(conversationId);
  if (!_store.has(id)) {
    _store.set(id, {
      issues: ref([]),
      loading: ref(false),
      timer: null,
      refCount: 0,
    });
  }
  return _store.get(id);
}

// ─── Debounced fetch for a specific conversation ────────────────────────────
function _fetchForConversation(conversationId) {
  const id = String(conversationId);
  const s = _getState(id);
  if (s.timer) clearTimeout(s.timer);
  s.timer = setTimeout(async () => {
    s.loading.value = true;
    try {
      const response = await PlaneAPI.getLinkedIssues(id);
      s.issues.value = response.data || [];
    } catch (err) {
      console.error('[usePlaneIssues] fetch failed, keeping stale data:', err);
    } finally {
      s.loading.value = false;
    }
  }, 80);
}

// ─── Optimistic update for a specific conversation ──────────────────────────
function _applyOptimistic(conversationId, data) {
  const s = _getState(conversationId);
  const arr = s.issues.value;
  const idx = arr.findIndex(
    (i) => i.id === data.issue_id || i.key === data.issue_key || i.issue_key === data.issue_key
  );
  if (idx !== -1) {
    const updated = { ...arr[idx] };
    if (data.state_name || data.new_state) updated.state_name = data.state_name || data.new_state;
    if (data.state_color) updated.state_color = data.state_color;
    if (data.name) updated.name = data.name;
    arr[idx] = updated;
    s.issues.value = [...arr];
  }
}

// ─── Global event listeners (registered ONCE at module load) ────────────────
// These fire for ALL conversations. They figure out which conversation(s) to
// update by checking event data and the active state map.

function _handleStateUpdate(data) {
  const convId = data.conversation_id ? String(data.conversation_id) : null;

  // If we know the conversation, update it directly
  if (convId && _store.has(convId)) {
    _applyOptimistic(convId, data);
    _fetchForConversation(convId);
    return;
  }

  // Otherwise, check all tracked conversations for matching issue
  for (const [cid, s] of _store.entries()) {
    const hasIssue = s.issues.value.some(
      (i) => i.id === data.issue_id || i.key === data.issue_key || i.issue_key === data.issue_key
    );
    if (hasIssue) {
      _applyOptimistic(cid, data);
      _fetchForConversation(cid);
    }
  }
}

function _handleIssuesChanged() {
  // Refresh ALL tracked conversations (link/unlink doesn't tell us which one)
  for (const cid of _store.keys()) {
    _fetchForConversation(cid);
  }
}

// Register once — these persist for the entire app lifetime
emitter.on('plane:issue-status-updated', _handleStateUpdate);
emitter.on('plane:issue-completed', _handleStateUpdate);
window.addEventListener('plane:issues-updated', _handleIssuesChanged);

// ─── Composable ─────────────────────────────────────────────────────────────
export function usePlaneIssues(conversationId) {
  // Resolve conversationId from ref/computed/raw value
  const cid = computed(() => {
    const raw = typeof conversationId === 'function' ? conversationId() : conversationId?.value ?? conversationId;
    return String(raw);
  });

  const state = computed(() => _getState(cid.value));
  const issues = computed(() => state.value.issues.value);
  const isLoading = computed(() => state.value.loading.value);

  const refresh = () => _fetchForConversation(cid.value);

  const removeIssue = (issueId) => {
    const s = state.value;
    s.issues.value = s.issues.value.filter((i) => i.id !== issueId);
  };

  // Lifecycle: just track refCount and do initial fetch
  onMounted(() => {
    const s = state.value;
    s.refCount++;
    refresh();
  });

  onUnmounted(() => {
    const s = state.value;
    s.refCount--;
    if (s.refCount <= 0) {
      if (s.timer) clearTimeout(s.timer);
      _store.delete(cid.value);
    }
  });

  return { issues, isLoading, refresh, removeIssue };
}
