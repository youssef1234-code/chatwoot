import { createConsumer } from '@rails/actioncable';

const PRESENCE_INTERVAL = 20000;
// ActionCable's server pings every ~3s. If we haven't seen a ping in this long
// the socket is almost certainly half-open (dead TCP path, still readyState
// OPEN), so force a reconnect. ~4 missed pings keeps it well clear of healthy
// connections and avoids false reopens.
const STALE_CONNECTION_THRESHOLD = 12000;
const LIVENESS_CHECK_INTERVAL = 10000;

class BaseActionCableConnector {
  constructor(app, pubsubToken, websocketHost = '') {
    const websocketURL = websocketHost ? `${websocketHost}/cable` : undefined;

    this.consumer = createConsumer(websocketURL);
    this.hasConnectedOnce = false;
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

  // ActionCable invokes this every time the server confirms our RoomChannel
  // subscription: once on the initial page-load connect, and again after every
  // reconnect (reopen -> welcome -> resubscribe -> confirmation). Messages
  // broadcast while we were disconnected are gone for good — ActionCable has no
  // replay — so on any reconnect we must re-fetch what we missed. Keying the
  // re-sync off this subscription confirmation, rather than the old "wait for a
  // `disconnected` event, then poll until isOpen()" heuristic, is what makes it
  // fire even on silent half-open reopens where no `disconnected` reaches us —
  // the case that left agents staring at a live-but-stale socket until they
  // manually refreshed.
  handleConnected = () => {
    if (this.hasConnectedOnce) {
      this.onReconnect();
    }
    this.hasConnectedOnce = true;
  };

  handleDisconnected = () => {
    this.onDisconnected();
  };

  // Belt-and-suspenders liveness watchdog. ActionCable's own ConnectionMonitor
  // can be slow or stalled at detecting a half-open socket: its poll backs off
  // up to 30s, browsers throttle/freeze its timers in backgrounded tabs, and it
  // never listens for the `online` event. We proactively force a reconnect the
  // moment the connection looks stale (no server ping within the threshold),
  // re-checking on the events that matter: tab refocus, network coming back,
  // and a short periodic timer. A forced reopen still flows through ActionCable's
  // disconnected/connected callbacks, so handleConnected's re-sync runs.
  setupConnectionWatchdog = () => {
    this.reopenIfStale = () => {
      const { connection } = this.consumer;
      if (!connection || !connection.monitor) return;
      const { pingedAt } = connection.monitor;
      // No pingedAt yet => never finished connecting; let the initial connect
      // (and ActionCable's own logic) run without interference.
      if (!pingedAt) return;
      if (Date.now() - pingedAt > STALE_CONNECTION_THRESHOLD) {
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
