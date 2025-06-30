import { MESSAGE_TYPE } from 'shared/constants/messages';
import { showBadgeOnFavicon } from './faviconHelper';
import { initFaviconSwitcher } from './faviconHelper';

import { EVENT_TYPES } from 'dashboard/routes/dashboard/settings/profile/constants.js';
import GlobalStore from 'dashboard/store';
import AudioNotificationStore from './AudioNotificationStore';
import {
  isConversationAssignedToMe,
  isConversationUnassigned,
  isMessageFromCurrentUser,
} from './AudioMessageHelper';
import WindowVisibilityHelper from './WindowVisibilityHelper';
import { useAlert } from 'dashboard/composables';

const NOTIFICATION_TIME = 30000;
const ALERT_DURATION = 10000;
const ALERT_PATH_PREFIX = '/audio/dashboard/';
const DEFAULT_TONE = 'ding';
const DEFAULT_ALERT_TYPE = ['none'];

export class DashboardAudioNotificationHelper {
  constructor(store) {
    if (!store) {
      throw new Error('store is required');
    }
    this.store = new AudioNotificationStore(store);

    this.notificationConfig = {
      audioAlertType: DEFAULT_ALERT_TYPE,
      playAlertOnlyWhenHidden: true,
      alertIfUnreadConversationExist: false,
    };

    this.recurringNotificationTimer = null;

    this.audioConfig = {
      audio: null,
      tone: DEFAULT_TONE,
      hasSentSoundPermissionsRequest: false,
      isAudioReady: false,
      lastPlayTime: 0, // Prevent rapid successive notifications
    };

    this.currentUser = null;
    
    // Initialize user interaction handlers for audio
    this.initializeUserInteractionHandlers();
  }

  // Initialize audio after user interaction to comply with browser autoplay policies
  initializeUserInteractionHandlers = () => {
    const userInteractionEvents = ['click', 'touchstart', 'keydown'];
    
    const handleUserInteraction = async () => {
      if (!this.audioConfig.isAudioReady) {
        await this.prepareAudioForPlayback();
        this.audioConfig.isAudioReady = true;
        
        // Remove listeners after first interaction
        userInteractionEvents.forEach(event => {
          document.removeEventListener(event, handleUserInteraction);
        });
      }
    };

    userInteractionEvents.forEach(event => {
      document.addEventListener(event, handleUserInteraction, { once: true });
    });
  };

  // Prepare audio for playback after user interaction
  prepareAudioForPlayback = async () => {
    try {
      if (this.audioConfig.audio) {
        // Try to play and immediately pause to "unlock" audio
        this.audioConfig.audio.volume = 0;
        const playPromise = this.audioConfig.audio.play();
        if (playPromise !== undefined) {
          await playPromise;
          this.audioConfig.audio.pause();
          this.audioConfig.audio.currentTime = 0;
          this.audioConfig.audio.volume = 1;
        }
      }
      await this.resumeAudioContextIfNeeded();
    } catch (error) {
      console.warn('Audio preparation failed:', error);
    }
  };

  intializeAudio = () => {
    const resourceUrl = `${ALERT_PATH_PREFIX}${this.audioConfig.tone}.mp3`;
    this.audioConfig.audio = new Audio(resourceUrl);
    
    // Preload the audio to avoid loading delays
    this.audioConfig.audio.preload = 'auto';
    
    // Add error handling for audio loading
    this.audioConfig.audio.addEventListener('error', (e) => {
      console.warn('Audio loading error:', e);
    });
    
    return this.audioConfig.audio.load();
  };

  // Resume audio context if suspended
  resumeAudioContextIfNeeded = async () => {
    try {
      if (window.AudioContext || window.webkitAudioContext) {
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        if (audioContext.state === 'suspended') {
          await audioContext.resume();
        }
      }
    } catch (error) {
      console.warn('Audio context resume failed:', error);
    }
  };

  playAudioAlert = async () => {
    try {
      // Prevent rapid successive notifications (minimum 1 second between plays)
      const now = Date.now();
      if (now - this.audioConfig.lastPlayTime < 1000) {
        console.log('Audio notification throttled - too soon after last play');
        return;
      }

      // Ensure audio is initialized
      if (!this.audioConfig.audio) {
        this.intializeAudio();
      }

      // Resume audio context if needed
      await this.resumeAudioContextIfNeeded();

      // Reset audio to beginning if it's already playing
      this.audioConfig.audio.currentTime = 0;
      
      // Try to play the audio
      const playPromise = this.audioConfig.audio.play();
      
      if (playPromise !== undefined) {
        await playPromise;
        this.audioConfig.lastPlayTime = now;
      }
    } catch (error) {
      console.warn('Audio playback failed:', error);
      
      if (error.name === 'NotAllowedError') {
        if (!this.audioConfig.hasSentSoundPermissionsRequest) {
          this.audioConfig.hasSentSoundPermissionsRequest = true;
          useAlert(
            'PROFILE_SETTINGS.FORM.AUDIO_NOTIFICATIONS_SECTION.SOUND_PERMISSION_ERROR',
            { usei18n: true, duration: ALERT_DURATION }
          );
        }
      } else if (error.name === 'NotSupportedError') {
        console.warn('Audio format not supported');
      } else if (error.name === 'AbortError') {
        console.warn('Audio playback was aborted');
      }
    }
  };

  set = ({
    currentUser,
    alwaysPlayAudioAlert,
    alertIfUnreadConversationExist,
    audioAlertType = DEFAULT_ALERT_TYPE,
    audioAlertTone = DEFAULT_TONE,
  }) => {
    this.notificationConfig = {
      ...this.notificationConfig,
      audioAlertType: audioAlertType.split('+').filter(Boolean),
      playAlertOnlyWhenHidden: !alwaysPlayAudioAlert,
      alertIfUnreadConversationExist: alertIfUnreadConversationExist,
    };

    this.currentUser = currentUser;

    const previousAudioTone = this.audioConfig.tone;
    this.audioConfig = {
      ...this.audioConfig,
      tone: audioAlertTone,
    };

    if (previousAudioTone !== audioAlertTone) {
      this.intializeAudio();
      // Reset audio readiness when tone changes
      this.audioConfig.isAudioReady = false;
    }

    initFaviconSwitcher();
    this.clearRecurringTimer();
    this.playAudioEvery30Seconds();
    
    // Log current audio notification settings for debugging
    this.debugAudioSettings();
  };

  // Debug method to help troubleshoot audio issues
  debugAudioSettings = () => {
    if (window.location.search.includes('debug=audio')) {
      console.log('Audio Notification Debug Info:', {
        audioAlertType: this.notificationConfig.audioAlertType,
        tone: this.audioConfig.tone,
        isAudioReady: this.audioConfig.isAudioReady,
        playAlertOnlyWhenHidden: this.notificationConfig.playAlertOnlyWhenHidden,
        alertIfUnreadConversationExist: this.notificationConfig.alertIfUnreadConversationExist,
        audioElement: this.audioConfig.audio,
        windowVisible: WindowVisibilityHelper.isWindowVisible(),
        currentUser: this.currentUser?.name || 'Unknown'
      });
    }
  };

  shouldPlayAlert = () => {
    if (this.notificationConfig.playAlertOnlyWhenHidden) {
      return !WindowVisibilityHelper.isWindowVisible();
    }
    return true;
  };

  executeRecurringNotification = () => {
    if (this.store.hasUnreadConversation() && this.shouldPlayAlert()) {
      this.playAudioAlert();
      showBadgeOnFavicon();
    }
    this.resetRecurringTimer();
  };

  clearRecurringTimer = () => {
    if (this.recurringNotificationTimer) {
      clearTimeout(this.recurringNotificationTimer);
    }
  };

  resetRecurringTimer = () => {
    this.clearRecurringTimer();
    this.recurringNotificationTimer = setTimeout(
      this.executeRecurringNotification,
      NOTIFICATION_TIME
    );
  };

  playAudioEvery30Seconds = () => {
    const { audioAlertType, alertIfUnreadConversationExist } =
      this.notificationConfig;

    //  Audio alert is disabled dismiss the timer
    if (audioAlertType.includes('none')) return;

    // If unread conversation flag is disabled, dismiss the timer
    if (!alertIfUnreadConversationExist) return;

    this.resetRecurringTimer();
  };

  shouldNotifyOnMessage = message => {
    const { audioAlertType } = this.notificationConfig;
    if (audioAlertType.includes('none')) return false;
    if (audioAlertType.includes('all')) return true;

    const assignedToMe = isConversationAssignedToMe(
      message,
      this.currentUser.id
    );
    const isUnassigned = isConversationUnassigned(message);

    const shouldPlayAudio = [];

    if (
      audioAlertType.includes(EVENT_TYPES.ASSIGNED) ||
      audioAlertType.includes('mine')
    ) {
      shouldPlayAudio.push(assignedToMe);
    }
    if (audioAlertType.includes(EVENT_TYPES.UNASSIGNED)) {
      shouldPlayAudio.push(isUnassigned);
    }
    if (audioAlertType.includes(EVENT_TYPES.NOTME)) {
      shouldPlayAudio.push(!isUnassigned && !assignedToMe);
    }

    return shouldPlayAudio.some(Boolean);
  };

  onNewMessage = message => {
    const debugMode = window.location.search.includes('debug=audio');
    
    if (debugMode) {
      console.log('New message received for audio notification:', message);
    }

    // If the user does not have the permission to view the conversation, then dismiss the alert
    // FIX ME: There shouldn't be a new message if the user has no access to the conversation.
    if (!this.store.hasConversationPermission(this.currentUser)) {
      if (debugMode) console.log('Audio notification dismissed: No conversation permission');
      return;
    }

    // If the conversation status is pending, then dismiss the alert
    // This case is common for all audio event types
    if (this.store.isMessageFromPendingConversation(message)) {
      if (debugMode) console.log('Audio notification dismissed: Message from pending conversation');
      return;
    }

    // If the message is sent by the current user then dismiss the alert
    if (isMessageFromCurrentUser(message, this.currentUser.id)) {
      if (debugMode) console.log('Audio notification dismissed: Message from current user');
      return;
    }

    if (!this.shouldNotifyOnMessage(message)) {
      if (debugMode) console.log('Audio notification dismissed: Should not notify on this message type');
      return;
    }

    // If the message type is not incoming or private, then dismiss the alert
    const { message_type: messageType, private: isPrivate } = message;
    if (messageType !== MESSAGE_TYPE.INCOMING && !isPrivate) {
      if (debugMode) console.log('Audio notification dismissed: Message type not incoming or private');
      return;
    }

    if (WindowVisibilityHelper.isWindowVisible()) {
      // If the user looking at the conversation, then dismiss the alert
      if (this.store.isMessageFromCurrentConversation(message)) {
        if (debugMode) console.log('Audio notification dismissed: Message from current conversation');
        return;
      }

      // If the user has disabled alerts when active on the dashboard, the dismiss the alert
      if (this.notificationConfig.playAlertOnlyWhenHidden) {
        if (debugMode) console.log('Audio notification dismissed: Play only when hidden is enabled and window is visible');
        return;
      }
    }

    if (debugMode) {
      console.log('Playing audio notification for message:', message);
      console.log('Audio settings:', {
        audioAlertType: this.notificationConfig.audioAlertType,
        isAudioReady: this.audioConfig.isAudioReady,
        hasAudio: !!this.audioConfig.audio
      });
    }

    this.playAudioAlert();
    showBadgeOnFavicon();
    this.playAudioEvery30Seconds();
  };
}

export default new DashboardAudioNotificationHelper(GlobalStore);

// Make it globally accessible for debugging
if (typeof window !== 'undefined') {
  window.DashboardAudioNotificationHelper = new DashboardAudioNotificationHelper(GlobalStore);
}
