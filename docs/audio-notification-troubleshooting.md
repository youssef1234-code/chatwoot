# Audio Notification Troubleshooting Guide

This guide helps diagnose and fix issues with audio notifications not playing consistently in Chatwoot.

## Common Issues and Solutions

### 1. Browser Autoplay Policies
**Problem**: Modern browsers block audio from playing automatically without user interaction.

**Solution**: 
- The system now automatically prepares audio after the first user interaction (click, tap, or keypress)
- Audio is "unlocked" by playing and immediately pausing on first interaction

### 2. Audio Context Suspended
**Problem**: Browser's AudioContext can be in a suspended state.

**Solution**: 
- The system now checks and resumes AudioContext when needed
- This is handled automatically in the background

### 3. Audio Loading Issues
**Problem**: Audio files might not load properly or take time to load.

**Solution**:
- Audio is now preloaded with `preload='auto'`
- Better error handling for loading failures
- Audio element is reset to beginning on each play

### 4. Configuration Issues
**Problem**: Audio notification settings might not be properly applied.

**Solution**:
- Added debug logging to trace configuration issues
- Better synchronization of settings changes

## Debug Mode

Add `?debug=audio` to your URL to enable detailed logging of audio notifications.

Example: `https://your-chatwoot.com/app/accounts/1/dashboard?debug=audio`

## Testing Audio Notifications

### Browser Console Testing

Open browser console and run:

```javascript
// Full diagnostic
ChatwootAudioTestUtil.runDiagnostic()

// Test just audio playback
ChatwootAudioTestUtil.testAudioNotification()

// Check permissions
ChatwootAudioTestUtil.checkAudioPermissions()

// Simulate a message
ChatwootAudioTestUtil.simulateMessage()
```

### Manual Testing Steps

1. **Enable Debug Mode**: Add `?debug=audio` to URL
2. **Check Settings**: Go to Profile → Audio Notifications
3. **User Interaction**: Click anywhere on the page
4. **Test Message**: Send a test message or use simulator
5. **Check Console**: Look for debug logs

## Troubleshooting Checklist

### User Settings
- [ ] Audio alerts are enabled (not set to "none")
- [ ] Correct alert type is selected (assigned/unassigned/all)
- [ ] Audio tone is selected
- [ ] Notification conditions are properly configured

### Browser Settings
- [ ] Site has permission to play audio
- [ ] Browser autoplay is not blocked for the site
- [ ] Audio/sound is not muted in browser
- [ ] No browser extensions blocking audio

### Environment
- [ ] Audio file exists at `/audio/dashboard/{tone}.mp3`
- [ ] Network connection is stable
- [ ] No errors in browser console

### User Interaction
- [ ] User has interacted with the page (clicked, typed, etc.)
- [ ] Page is not in a suspended/hidden state
- [ ] AudioContext is in "running" state

## Technical Details

### Audio Notification Flow

1. **Message Received**: ActionCable receives new message
2. **Permission Check**: Verify user has conversation permissions
3. **Filter Check**: Check if message should trigger notification
4. **Visibility Check**: Check window visibility and settings
5. **Audio Preparation**: Ensure audio is ready to play
6. **Playback**: Attempt to play audio with error handling

### Key Components

- `DashboardAudioNotificationHelper`: Main audio notification handler
- `AudioNotificationStore`: Manages conversation state checks
- `WindowVisibilityHelper`: Tracks window focus/visibility
- `scriptHelpers.js`: Initializes audio settings

### Audio Settings Storage

Audio settings are stored in user's `ui_settings`:
- `enable_audio_alerts`: Type of alerts (none/assigned/unassigned/all)
- `notification_tone`: Audio tone (ding/pop/etc.)
- `always_play_audio_alert`: Play even when window is visible
- `alert_if_unread_assigned_conversation_exist`: Recurring alerts

## Browser-Specific Issues

### Chrome/Chromium
- Very strict autoplay policies
- Requires user gesture for audio
- Check chrome://settings/content/sound

### Firefox
- More permissive autoplay policies
- May work without user interaction
- Check about:preferences#privacy

### Safari
- Strictest autoplay policies
- Requires user interaction per session
- Check Safari → Preferences → Websites → Auto-Play

## Support Information

When reporting audio notification issues, please provide:

1. Browser and version
2. Operating system
3. Console debug logs (with `?debug=audio`)
4. Audio notification settings
5. Steps to reproduce
6. Results of `ChatwootAudioTestUtil.runDiagnostic()`

## Recent Improvements

- Added user interaction handlers for autoplay compliance
- Improved audio context management
- Better error handling and logging
- Audio preparation after first user interaction
- Debug mode for troubleshooting
- Comprehensive test utilities
