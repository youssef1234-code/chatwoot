import { createConsumer } from '@rails/actioncable';

const PRESENCE_INTERVAL = 20000;
const RECONNECT_INTERVAL = 1000;

class BaseActionCableConnector {
  static isDisconnected = false;

  constructor(app, pubsubToken, websocketHost = '') {
    const websocketURL = websocketHost ? `${websocketHost}/cable` : undefined;

    this.consumer = createConsumer(websocketURL);
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
        disconnected: () => {
          BaseActionCableConnector.isDisconnected = true;
          this.onDisconnected();
          this.initReconnectTimer();
        },
      }
    );
    this.app = app;
    this.events = {};
    this.reconnectTimer = null;
    this.isAValidEvent = () => true;
    this.triggerPresenceInterval = () => {
      setTimeout(() => {
        this.subscription.updatePresence();
        this.triggerPresenceInterval();
      }, PRESENCE_INTERVAL);
    };
    this.triggerPresenceInterval();
  }

  checkConnection() {
    const isConnectionActive = this.consumer.connection.isOpen();
    const isReconnected =
      BaseActionCableConnector.isDisconnected && isConnectionActive;
    if (isReconnected) {
      this.clearReconnectTimer();
      this.onReconnect();
      BaseActionCableConnector.isDisconnected = false;
    } else {
      this.initReconnectTimer();
    }
  }

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
    }, RECONNECT_INTERVAL);
  };

  // eslint-disable-next-line class-methods-use-this
  onReconnect = () => {};

  // eslint-disable-next-line class-methods-use-this
  onDisconnected = () => {};

  disconnect() {
    this.consumer.disconnect();
  }

  onReceived = ({ event, data } = {}) => {
    // Log only ticket-related events to reduce noise
    if (event && event.includes('ticket')) {
      console.log('BaseActionCableConnector: Received ticket WebSocket event', { event, data });
      console.log('BaseActionCableConnector: isAValidEvent check:', this.isAValidEvent(data));
      console.log('BaseActionCableConnector: Available events:', Object.keys(this.events));
      console.log('BaseActionCableConnector: Handler exists:', this.events[event] && typeof this.events[event] === 'function');
      console.log('BaseActionCableConnector: Handler type:', typeof this.events[event]);
    }
    
    if (this.isAValidEvent(data)) {
      if (this.events[event] && typeof this.events[event] === 'function') {
        if (event && event.includes('ticket')) {
          console.log('BaseActionCableConnector: Calling handler for ticket event', event);
        }
        this.events[event](data);
      } else if (event && event.includes('ticket')) {
        console.log('BaseActionCableConnector: No handler found for ticket event', event);
      }
    } else if (event && event.includes('ticket')) {
      console.log('BaseActionCableConnector: Invalid event data for ticket event', data);
    }
  };
}

export default BaseActionCableConnector;
