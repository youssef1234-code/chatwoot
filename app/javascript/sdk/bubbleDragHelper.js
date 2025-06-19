// Enhanced drag functionality for the SDK chat bubble
// Allows 360-degree movement while maintaining proper click-vs-drag detection

export class BubbleDragHelper {
  constructor(bubbleElement, options = {}) {
    this.bubble = bubbleElement;
    this.isDragging = false;
    this.dragStarted = false;
    this.startX = 0;
    this.startY = 0;
    this.initialX = 0;
    this.initialY = 0;
    this.currentX = 0;
    this.currentY = 0;
    this.lastDragDistance = 0;
    
    // Configuration options
    this.options = {
      dragThreshold: 5, // Reduced threshold for more responsive drag
      clickTimeThreshold: 150, // Reduced time for quicker drag detection
      persistPosition: true, // Remember position across sessions
      onPositionChange: null, // Callback to sync close button position
      onDragStart: null, // Callback when drag starts
      onDragEnd: null, // Callback when drag ends
      ...options,
    };
    
    this.clickStartTime = 0;
    this.boundaryPadding = 20; // Minimum distance from viewport edges
    this.dragCooldown = false; // Prevent immediate clicks after drag
    
    this.initializeDragEvents();
    this.restoreSavedPosition();
    this.setupWindowHandlers();
  }
  
  initializeDragEvents() {
    // Touch events for mobile
    this.bubble.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false });
    this.bubble.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: false });
    this.bubble.addEventListener('touchend', this.handleTouchEnd.bind(this), { passive: false });
    
    // Mouse events for desktop
    this.bubble.addEventListener('mousedown', this.handleMouseDown.bind(this), { passive: false });
    document.addEventListener('mousemove', this.handleMouseMove.bind(this), { passive: false });
    document.addEventListener('mouseup', this.handleMouseUp.bind(this), { passive: false });
    
    // Prevent default drag behavior
    this.bubble.addEventListener('dragstart', (e) => e.preventDefault());
  }
  
  handleTouchStart(e) {
    this.startDrag(e.touches[0].clientX, e.touches[0].clientY);
  }
  
  handleMouseDown(e) {
    this.startDrag(e.clientX, e.clientY);
  }
  
  startDrag(clientX, clientY) {
    this.isDragging = true;
    this.dragStarted = false;
    this.clickStartTime = Date.now();
    
    this.startX = clientX;
    this.startY = clientY;
    
    // Get current position
    const rect = this.bubble.getBoundingClientRect();
    this.initialX = rect.left;
    this.initialY = rect.top;
    this.currentX = this.initialX;
    this.currentY = this.initialY;
    
    // Add dragging class for visual feedback
    this.bubble.classList.add('woot-widget-bubble--dragging');
    
    // Prevent text selection while dragging
    document.body.style.userSelect = 'none';
  }
  
  handleTouchMove(e) {
    if (!this.isDragging) return;
    e.preventDefault();
    this.updateDrag(e.touches[0].clientX, e.touches[0].clientY);
  }
  
  handleMouseMove(e) {
    if (!this.isDragging) return;
    e.preventDefault();
    this.updateDrag(e.clientX, e.clientY);
  }
  
  updateDrag(clientX, clientY) {
    const deltaX = clientX - this.startX;
    const deltaY = clientY - this.startY;
    this.lastDragDistance = Math.sqrt(deltaX * deltaX + deltaY * deltaY);
    
    // Check if we've moved enough to consider this a drag
    if (!this.dragStarted && this.lastDragDistance > this.options.dragThreshold) {
      this.dragStarted = true;
      this.bubble.classList.add('woot-widget-bubble--drag-active');
      
      // Add haptic-like visual feedback directly to the bubble
      this.bubble.style.transition = 'none';
      
      // Brief scale pulse to indicate drag start
      this.bubble.style.transform = 'scale(1.12)';
      setTimeout(() => {
        this.bubble.style.transform = 'scale(1.08) rotate(2deg)';
      }, 50);
      
      // Notify drag start
      if (typeof this.options.onDragStart === 'function') {
        this.options.onDragStart();
      }
    }
    
    if (this.dragStarted) {
      // Calculate new position
      this.currentX = this.initialX + deltaX;
      this.currentY = this.initialY + deltaY;
      
      // Constrain to viewport boundaries
      this.constrainToViewport();
      
      // Apply the new position
      this.applyPosition();
      
      // Notify position change (for close button sync)
      if (typeof this.options.onPositionChange === 'function') {
        this.options.onPositionChange(this.currentX, this.currentY);
      }
    }
  }
  
  handleTouchEnd(e) {
    this.endDrag();
  }
  
  handleMouseUp(e) {
    this.endDrag();
  }
  
  endDrag() {
    if (!this.isDragging) return;
    
    // Clean up dragging state
    this.bubble.classList.remove('woot-widget-bubble--dragging', 'woot-widget-bubble--drag-active');
    document.body.style.userSelect = '';
    
    if (this.dragStarted) {
      this.saveBubblePosition();
      
      // Smooth return animation directly on the bubble
      this.bubble.style.transition = 'transform 0.4s cubic-bezier(0.4, 0.0, 0.2, 1)';
      this.bubble.style.transform = 'scale(1) rotate(0deg)';
      
      // Reset transition after animation
      setTimeout(() => {
        this.bubble.style.transition = 'transform 0.3s cubic-bezier(0.4, 0.0, 0.2, 1), box-shadow 0.3s ease';
      }, 400);
      
      // Set cooldown to prevent immediate clicks after drag
      this.dragCooldown = true;
      setTimeout(() => {
        this.dragCooldown = false;
      }, 250); // 250ms cooldown after drag ends
    }
    
    // Notify drag end
    if (typeof this.options.onDragEnd === 'function') {
      this.options.onDragEnd();
    }
    
    // The drag handle should NEVER trigger clicks - only drag!
    
    this.isDragging = false;
    this.dragStarted = false;
    this.lastDragDistance = 0;
  }
  
  constrainToViewport() {
    const viewport = {
      width: window.innerWidth || document.documentElement.clientWidth,
      height: window.innerHeight || document.documentElement.clientHeight
    };
    
    const bubbleRect = this.bubble.getBoundingClientRect();
    const bubbleWidth = bubbleRect.width;
    const bubbleHeight = bubbleRect.height;
    
    // Constrain X position
    this.currentX = Math.max(
      this.boundaryPadding,
      Math.min(viewport.width - bubbleWidth - this.boundaryPadding, this.currentX)
    );
    
    // Constrain Y position
    this.currentY = Math.max(
      this.boundaryPadding,
      Math.min(viewport.height - bubbleHeight - this.boundaryPadding, this.currentY)
    );
  }
  
  applyPosition() {
    // When dragging the bubble itself, we move the bubble directly
    this.bubble.style.left = `${this.currentX}px`;
    this.bubble.style.top = `${this.currentY}px`;
    this.bubble.style.right = 'auto';
    this.bubble.style.bottom = 'auto';
    
    // Also trigger position change callback for syncing
    if (typeof this.options.onPositionChange === 'function') {
      this.options.onPositionChange(this.currentX, this.currentY);
    }
  }
  
  handleBubbleClick() {
    // Don't trigger click if this is a drag handle - let the parent handle it
    const isDragHandle = this.bubble.classList.contains(
      'woot-widget-drag-handle'
    );
    if (isDragHandle) {
      return; // Prevent any action for drag handles
    }
    
    // Trigger the original bubble click functionality
    if (window.$chatwoot && typeof window.$chatwoot.toggle === 'function') {
      window.$chatwoot.toggle();
    }
    
    // Also trigger the legacy click handler if it exists
    if (this.options.onBubbleClick) {
      this.options.onBubbleClick();
    }
  }
  
  // Public method to save bubble position
  saveBubblePosition() {
    if (!this.options.persistPosition) return;
    
    try {
      const position = {
        x: this.currentX,
        y: this.currentY,
        timestamp: Date.now(),
      };
      localStorage.setItem('chatwoot_bubble_position', JSON.stringify(position));
    } catch (e) {
      // Silently fail if localStorage is not available
      console.warn('Could not save bubble position:', e);
    }
  }
  
  restoreSavedPosition() {
    if (!this.options.persistPosition) {
      this.setDefaultPosition();
      return;
    }
    
    try {
      const savedPosition = localStorage.getItem('chatwoot_bubble_position');
      if (savedPosition) {
        const position = JSON.parse(savedPosition);
        
        // Only restore if the position was saved recently (within 7 days)
        const maxAge = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds
        if (Date.now() - position.timestamp < maxAge) {
          this.currentX = position.x;
          this.currentY = position.y;
          
          // Apply constraints to handle viewport size changes
          this.constrainToViewport();
          this.applyPosition();
          return;
        }
      }
    } catch (e) {
      // Silently fail if localStorage is not available or data is corrupted
      console.warn('Could not restore bubble position:', e);
    }
    
    // If no valid saved position, use default
    this.setDefaultPosition();
  }
  
  setDefaultPosition() {
    // Set default position based on the original Chatwoot position setting
    const viewport = {
      width: window.innerWidth || document.documentElement.clientWidth,
      height: window.innerHeight || document.documentElement.clientHeight,
    };
    
    const bubbleRect = this.bubble.getBoundingClientRect();
    const position = window.$chatwoot?.position || 'right';
    
    if (position === 'left') {
      this.currentX = this.boundaryPadding;
    } else {
      this.currentX = viewport.width - bubbleRect.width - this.boundaryPadding;
    }
    
    this.currentY = viewport.height - bubbleRect.height - this.boundaryPadding;
    
    this.applyPosition();
  }
  
  // Public method to programmatically set position
  setPosition(x, y) {
    this.currentX = x;
    this.currentY = y;
    this.constrainToViewport();
    this.applyPosition();
    this.saveBubblePosition();
  }
  
  // Public method to reset to default position
  resetPosition() {
    // Reset to bottom-right corner (default)
    const viewport = {
      width: window.innerWidth || document.documentElement.clientWidth,
      height: window.innerHeight || document.documentElement.clientHeight
    };
    
    const bubbleRect = this.bubble.getBoundingClientRect();
    this.currentX = viewport.width - bubbleRect.width - this.boundaryPadding;
    this.currentY = viewport.height - bubbleRect.height - this.boundaryPadding;
    
    this.applyPosition();
    this.saveBubblePosition();
  }
  
  setupWindowHandlers() {
    // Handle window resize to keep bubble in bounds
    this.handleResize = () => {
      this.constrainToViewport();
      this.applyPosition();
    };
    
    window.addEventListener('resize', this.handleResize);
  }
  
  // Clean up event listeners
  destroy() {
    this.bubble.removeEventListener('touchstart', this.handleTouchStart);
    this.bubble.removeEventListener('touchmove', this.handleTouchMove);
    this.bubble.removeEventListener('touchend', this.handleTouchEnd);
    this.bubble.removeEventListener('mousedown', this.handleMouseDown);
    document.removeEventListener('mousemove', this.handleMouseMove);
    document.removeEventListener('mouseup', this.handleMouseUp);
    window.removeEventListener('resize', this.handleResize);
  }
}
