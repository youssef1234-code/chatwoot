// Audio Notification Test Utility for Chatwoot
// Add this script to browser console to test audio notifications

window.ChatwootAudioTestUtil = {
  // Test if audio notifications are working
  testAudioNotification: async function() {
    console.log('🔊 Testing Chatwoot Audio Notifications...');
    
    try {
      // Try multiple ways to find the helper
      let helper = window.DashboardAudioNotificationHelper;
      
      if (!helper) {
        // Try to import it dynamically
        try {
          const module = await import('./DashboardAudioNotificationHelper.js');
          helper = module.default;
        } catch (importError) {
          console.warn('Could not import helper:', importError);
        }
      }
      
      if (!helper) {
        console.error('❌ Audio notification helper not found');
        console.log('💡 Try refreshing the page or check if you are on the dashboard');
        return false;
      }

      console.log('✅ Audio helper found');
      
      // Check current settings
      const settings = {
        audioAlertType: helper.notificationConfig?.audioAlertType || ['none'],
        tone: helper.audioConfig?.tone || 'unknown',
        isAudioReady: helper.audioConfig?.isAudioReady || false,
        hasAudio: !!(helper.audioConfig?.audio),
        currentUser: helper.currentUser?.name || 'Unknown'
      };
      
      console.log('📋 Current settings:', settings);
      
      if (settings.audioAlertType.includes('none')) {
        console.warn('⚠️ Audio alerts are disabled (set to "none")');
        console.log('💡 Go to Profile Settings → Audio Notifications to enable them');
        return false;
      }
      
      if (!settings.hasAudio) {
        console.warn('⚠️ Audio element not initialized');
        if (helper.intializeAudio) {
          await helper.intializeAudio();
          console.log('✅ Audio initialized');
        }
      }
      
      if (!settings.isAudioReady && helper.prepareAudioForPlayback) {
        console.warn('⚠️ Audio not ready, preparing...');
        await helper.prepareAudioForPlayback();
        helper.audioConfig.isAudioReady = true;
        console.log('✅ Audio prepared');
      }
      
      // Test audio playback
      console.log('🎵 Testing audio playback...');
      if (helper.playAudioAlert) {
        await helper.playAudioAlert();
        console.log('✅ Audio test completed successfully');
      } else {
        console.error('❌ playAudioAlert method not found');
        return false;
      }
      
      return true;
    } catch (error) {
      console.error('❌ Audio test failed:', error);
      return false;
    }
  },

  // Check browser audio permissions
  checkAudioPermissions: function() {
    console.log('🔍 Checking audio permissions...');
    
    // Check autoplay policy (note: 'autoplay' is not a standard permission name)
    if (typeof navigator.permissions !== 'undefined') {
      // Try checking camera permission as a proxy for media permissions
      navigator.permissions.query({ name: 'camera' }).then(permission => {
        console.log('� Camera permission (media proxy):', permission.state);
      }).catch(err => {
        console.log('⚠️ Cannot check camera permission:', err.message);
      });
    } else {
      console.log('⚠️ Permissions API not supported');
    }
    
    // Check document interaction state
    console.log('👆 User has interacted with document:', document.hasStorageAccess ? 'Unknown' : 'Check manually');
    
    // Check if AudioContext is available
    if (window.AudioContext || window.webkitAudioContext) {
      try {
        const audioCtx = new (window.AudioContext || window.webkitAudioContext)();
        console.log('🎵 AudioContext state:', audioCtx.state);
        if (audioCtx.state === 'suspended') {
          console.warn('⚠️ AudioContext is suspended - user interaction needed');
          console.log('💡 Click anywhere on the page to activate audio');
        }
        audioCtx.close(); // Clean up
      } catch (audioError) {
        console.error('❌ AudioContext error:', audioError);
      }
    } else {
      console.error('❌ AudioContext not supported');
    }
    
    // Check if we can create Audio elements
    try {
      const testAudio = new Audio();
      console.log('🔊 Audio element creation:', testAudio ? 'Success' : 'Failed');
    } catch (audioElementError) {
      console.error('❌ Audio element creation failed:', audioElementError);
    }
  },

  // Simulate a message for testing
  simulateMessage: async function(options = {}) {
    const defaultMessage = {
      id: 'test-' + Date.now(),
      conversation_id: 1,
      message_type: 0, // INCOMING
      private: false,
      sender: { id: 999, name: 'Test User' },
      content: 'Test message for audio notification',
      ...options
    };
    
    console.log('📨 Simulating message:', defaultMessage);
    
    // Try multiple ways to find the helper
    let helper = window.DashboardAudioNotificationHelper;
    
    if (!helper) {
      try {
        const module = await import('./DashboardAudioNotificationHelper.js');
        helper = module.default;
      } catch (importError) {
        console.warn('Could not import helper for simulation:', importError);
      }
    }
                  
    if (helper && helper.onNewMessage) {
      helper.onNewMessage(defaultMessage);
      console.log('✅ Message simulation sent to audio handler');
    } else {
      console.error('❌ Could not simulate message - handler not found');
      console.log('💡 Make sure you are on the dashboard page');
      console.log('💡 Try refreshing the page and running the test again');
    }
  },

  // Enable debug mode
  enableDebugMode: function() {
    if (!window.location.search.includes('debug=audio')) {
      const newUrl = window.location.href + (window.location.search ? '&' : '?') + 'debug=audio';
      console.log('🐛 Enabling debug mode. Reload page with: ' + newUrl);
      console.log('Or add ?debug=audio to URL manually');
    } else {
      console.log('✅ Debug mode already enabled');
    }
  },

  // Full diagnostic
  runDiagnostic: async function() {
    console.log('🔧 Running full audio notification diagnostic...');
    console.log('====================================================');
    
    this.checkAudioPermissions();
    console.log('');
    
    await this.testAudioNotification();
    console.log('');
    
    this.enableDebugMode();
    console.log('');
    
    console.log('💡 Troubleshooting tips:');
    console.log('1. Ensure audio alerts are enabled in profile settings');
    console.log('2. Check browser autoplay policy in site settings');
    console.log('3. Try clicking anywhere on the page first (user interaction)');
    console.log('4. Check browser console for errors');
    console.log('5. Test with different browsers');
    console.log('6. Use simulateMessage() to test with fake messages');
    console.log('7. Make sure you are on the dashboard page (not settings)');
    console.log('8. Try refreshing the page if helper is not found');
    
    console.log('====================================================');
    
    // Additional system information
    console.log('🔍 System Information:');
    console.log('- Browser:', navigator.userAgent.split(' ').pop());
    console.log('- Current URL:', window.location.href);
    console.log('- Dashboard helper available:', !!window.DashboardAudioNotificationHelper);
    console.log('- Audio test util available:', !!window.ChatwootAudioTestUtil);
  },

  // Get current audio settings
  getCurrentSettings: function() {
    const helper = window.DashboardAudioNotificationHelper;
    if (!helper) {
      console.error('❌ Audio helper not found');
      return null;
    }

    const settings = {
      audioAlertType: helper.notificationConfig?.audioAlertType || ['none'],
      tone: helper.audioConfig?.tone || 'unknown',
      isAudioReady: helper.audioConfig?.isAudioReady || false,
      hasAudio: !!(helper.audioConfig?.audio),
      playAlertOnlyWhenHidden: helper.notificationConfig?.playAlertOnlyWhenHidden,
      alertIfUnreadConversationExist: helper.notificationConfig?.alertIfUnreadConversationExist,
      currentUser: helper.currentUser?.name || 'Unknown',
      lastPlayTime: helper.audioConfig?.lastPlayTime || 0
    };

    console.log('⚙️ Current Audio Settings:', settings);
    return settings;
  }
};

// Auto-run basic check if in debug mode
if (window.location.search.includes('debug=audio')) {
  console.log('🔊 Chatwoot Audio Debug Mode Enabled');
  console.log('Run ChatwootAudioTestUtil.runDiagnostic() for full test');
}

export default window.ChatwootAudioTestUtil;
