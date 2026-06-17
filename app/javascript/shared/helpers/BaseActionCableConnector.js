import { createConsumer } from '@rails/actioncable';

const PRESENCE_INTERVAL = 20000;
const RECONNECT_POLL_INTERVAL = 1000;
// `connected` and the isOpen poll can both signal the same reconnect; collapse
// them so we only re-sync once.
const RECONNECT_DEDUP_INTERVAL = 3000;
// ActionCable pings every ~3s. No ping in this long => the socket is almost
// certainly half-open; force a reconnect. ~4 missed pings stays clear of
// healthy connections.
const STALE_CONNECTION_THRESHOLD = 12000;
const LIVENESS_CHECK_INTERVAL = 10000;

class BaseActionCableConnector {
  static isDisconnected = false;

  constructor(app, pubsubToken, websocketHost = '') {
    const websocketURL = websocketHost ? `${websocketHost}/cable` : undefined;

    this.consumer = createConsumer(websocketURL);
    this.hasConnectedOnce = false;
    this.lastReconnectAt = null;
    this.reconnectTimer = null;
    this.subscription = this.consumer.subscriptions.create(
      {
        channel: 'RoomChannel',
        pubsub_token: pubsubToken,
        account_id: app.$store.getters.getCurrentAccountId,
        user_id: app.$store.getters.getCurrentUserID,
      },
      {
        updatePresence() {
          this.perform('update_presence');
        },
        received: this.onReceived,
        connected: this.handleConnected,
        disconnected: this.handleDisconnected,
      }
    );
    this.app = app;
    this.events = {};
    this.isAValidEvent = () => true;
    this.triggerPresenceInterval = () => {
      setTimeout(() => {
        this.subscription.updatePresence();
        this.triggerPresenceInterval();
      }, PRESENCE_INTERVAL);
    };
    this.triggerPresenceInterval();
    this.setupConnectionWatchdog();
  }

  // Re-sync the data we missed while disconnected (ActionCable has no replay).
  // Driven from TWO signals because neither alone is sufficient:
  //   - handleConnected: the server re-confirmed our subscription. Catches
  //     reopen-from-closed reconnects, where ActionCable does not re-fire the
  //     `disconnected` callback.
  //   - checkConnection (isOpen poll): the socket is open again but ActionCable
  //     sometimes does NOT re-send the subscription confirmation on reconnect
  //     (a known race, rails/rails#38668), so `connected` never fires even
  //     though message delivery has already resumed. Without this poll the gap
  //     messages are silently lost until a manual page reload.
  // The time-based dedup keeps the two paths from double-fetching.
  triggerReconnect = () => {
    const now = Date.now();
    if (
      this.lastReconnectAt &&
      now - this.lastReconnectAt < RECONNECT_DEDUP_INTERVAL
    ) {
      return;
    }
    this.lastReconnectAt = now;
    BaseActionCableConnector.isDisconnected = false;
    this.clearReconnectTimer();
    this.onReconnect();
  };

  handleConnected = () => {
    // Skip the very first confirmation (initial page load already has data).
    if (this.hasConnectedOnce) {
      this.triggerReconnect();
    }
    this.hasConnectedOnce = true;
  };

  handleDisconnected = () => {
    BaseActionCableConnector.isDisconnected = true;
    this.onDisconnected();
    this.initReconnectTimer();
  };

  checkConnection = () => {
    if (!BaseActionCableConnector.isDisconnected) {
      this.clearReconnectTimer();
      return;
    }
    if (this.consumer.connection.isOpen()) {
      this.triggerReconnect();
    } else {
      this.initReconnectTimer();
    }
  };

  clearReconnectTimer = () => {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  };

  initReconnectTimer = () => {
    this.clearReconnectTimer();
    this.reconnectTimer = setTimeout(() => {
      this.checkConnection();
    }, RECONNECT_POLL_INTERVAL);
  };

  // Liveness watchdog: ActionCable's own monitor can be slow (its staleness
  // poll backs off up to 30s), frozen in a backgrounded tab, and never reacts
  // to `online`. Force a reopen when no ping has arrived within the threshold,
  // re-checked on tab refocus, network restore, and a short timer. The reopen
  // flows through the disconnected/connected callbacks and the poll above, so
  // the re-sync still fires. The isOpen() guard avoids piling a reopen onto an
  // in-progress reconnect.
  setupConnectionWatchdog = () => {
    this.reopenIfStale = () => {
      const { connection } = this.consumer;
      if (!connection || !connection.monitor || !connection.isOpen()) return;
      const { pingedAt } = connection.monitor;
      if (pingedAt && Date.now() - pingedAt > STALE_CONNECTION_THRESHOLD) {
        connection.reopen();
      }
    };
    this.handleVisibilityChange = () => {
      if (document.visibilityState === 'visible') this.reopenIfStale();
    };
    document.addEventListener('visibilitychange', this.handleVisibilityChange);
    window.addEventListener('online', this.reopenIfStale);
    this.livenessInterval = setInterval(
      this.reopenIfStale,
      LIVENESS_CHECK_INTERVAL
    );
  };

  // eslint-disable-next-line class-methods-use-this
  onReconnect = () => {};

  // eslint-disable-next-line class-methods-use-this
  onDisconnected = () => {};

  disconnect() {
    this.clearReconnectTimer();
    if (this.livenessInterval) clearInterval(this.livenessInterval);
    document.removeEventListener('visibilitychange', this.handleVisibilityChange);
    window.removeEventListener('online', this.reopenIfStale);
    this.consumer.disconnect();
  }

  onReceived = ({ event, data } = {}) => {
    if (this.isAValidEvent(data)) {
      if (this.events[event] && typeof this.events[event] === 'function') {
        this.events[event](data);
      }
    }
  };
}

export default BaseActionCableConnector;
