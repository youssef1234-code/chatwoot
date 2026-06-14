import { createConsumer } from '@rails/actioncable';

const PRESENCE_INTERVAL = 20000;

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

  // eslint-disable-next-line class-methods-use-this
  onReconnect = () => {};

  // eslint-disable-next-line class-methods-use-this
  onDisconnected = () => {};

  disconnect() {
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
