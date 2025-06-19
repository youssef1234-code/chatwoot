import { addClasses, removeClasses, toggleClass } from './DOMHelpers';
import { IFrameHelper } from './IFrameHelper';
import { isExpandedView } from './settingsHelper';
import {
  CHATWOOT_CLOSED,
  CHATWOOT_OPENED,
} from '../widget/constants/sdkEvents';
import { dispatchWindowEvent } from 'shared/helpers/CustomEventHelper';
import { BubbleDragHelper } from './bubbleDragHelper';

export const bubbleSVG =
  'M240.808 240.808H122.123C56.6994 240.808 3.45695 187.562 3.45695 122.122C3.45695 56.7031 56.6994 3.45697 122.124 3.45697C187.566 3.45697 240.808 56.7031 240.808 122.122V240.808Z';

export const body = document.getElementsByTagName('body')[0];
export const widgetHolder = document.createElement('div');

export const bubbleHolder = document.createElement('div');
export const chatBubble = document.createElement('button');
export const closeBubble = document.createElement('button');
export const notificationBubble = document.createElement('span');

export const setBubbleText = bubbleText => {
  if (isExpandedView(window.$chatwoot.type)) {
    const textNode = document.getElementById('woot-widget--expanded__text');
    textNode.innerText = bubbleText;
  }
};

export const createBubbleIcon = ({ className, path, target }) => {
  let bubbleClassName = `${className} woot-elements--${window.$chatwoot.position}`;
  const bubbleIcon = document.createElementNS(
    'http://www.w3.org/2000/svg',
    'svg'
  );
  bubbleIcon.setAttributeNS(null, 'id', 'woot-widget-bubble-icon');
  bubbleIcon.setAttributeNS(null, 'width', '24');
  bubbleIcon.setAttributeNS(null, 'height', '24');
  bubbleIcon.setAttributeNS(null, 'viewBox', '0 0 240 240');
  bubbleIcon.setAttributeNS(null, 'fill', 'none');
  bubbleIcon.setAttribute('xmlns', 'http://www.w3.org/2000/svg');

  const bubblePath = document.createElementNS(
    'http://www.w3.org/2000/svg',
    'path'
  );
  bubblePath.setAttributeNS(null, 'd', path);
  bubblePath.setAttributeNS(null, 'fill', '#FFFFFF');

  bubbleIcon.appendChild(bubblePath);
  target.appendChild(bubbleIcon);

  if (isExpandedView(window.$chatwoot.type)) {
    const textNode = document.createElement('div');
    textNode.id = 'woot-widget--expanded__text';
    textNode.innerText = '';
    target.appendChild(textNode);
    bubbleClassName += ' woot-widget--expanded';
  }

  target.className = bubbleClassName;
  target.title = 'Open chat window';
  return target;
};

export const createBubbleHolder = hideMessageBubble => {
  if (hideMessageBubble) {
    addClasses(bubbleHolder, 'woot-hidden');
  }
  addClasses(bubbleHolder, 'woot--bubble-holder');
  bubbleHolder.id = 'cw-bubble-holder';
  bubbleHolder.dataset.turboPermanent = true;
  body.appendChild(bubbleHolder);
};

const handleBubbleToggle = newIsOpen => {
  IFrameHelper.events.onBubbleToggle(newIsOpen);

  if (newIsOpen) {
    dispatchWindowEvent({ eventName: CHATWOOT_OPENED });
  } else {
    dispatchWindowEvent({ eventName: CHATWOOT_CLOSED });
    chatBubble.focus();
  }
};

export const onBubbleClick = (props = {}) => {
  const { toggleValue } = props;
  const { isOpen } = window.$chatwoot;
  if (isOpen === toggleValue) return;

  const newIsOpen = toggleValue === undefined ? !isOpen : toggleValue;
  window.$chatwoot.isOpen = newIsOpen;

  toggleClass(chatBubble, 'woot--hide');
  toggleClass(closeBubble, 'woot--hide');
  toggleClass(widgetHolder, 'woot--hide');

  handleBubbleToggle(newIsOpen);
};

export const onClickChatBubble = () => {
  // Global flag to prevent bubble clicks during dragging
  let isDraggingAnyBubble = false;

  // Make the bubbles themselves draggable - no separate drag handles needed
  if (chatBubble && !chatBubble.dragHelper) {
    chatBubble.dragHelper = new BubbleDragHelper(chatBubble, {
      dragThreshold: 5,
      clickTimeThreshold: 150,
      persistPosition: true,
      onDragStart: () => {
        isDraggingAnyBubble = true;
      },
      onDragEnd: () => {
        isDraggingAnyBubble = false;
      },
      onPositionChange: (x, y) => {
        // Sync both bubbles to the same position
        closeBubble.style.left = `${x}px`;
        closeBubble.style.top = `${y}px`;
        closeBubble.style.right = 'auto';
        closeBubble.style.bottom = 'auto';
      },
    });
  }

  if (closeBubble && !closeBubble.dragHelper) {
    closeBubble.dragHelper = new BubbleDragHelper(closeBubble, {
      dragThreshold: 5,
      clickTimeThreshold: 150,
      persistPosition: true,
      onDragStart: () => {
        isDraggingAnyBubble = true;
      },
      onDragEnd: () => {
        isDraggingAnyBubble = false;
      },
      onPositionChange: (x, y) => {
        // Sync both bubbles to the same position
        chatBubble.style.left = `${x}px`;
        chatBubble.style.top = `${y}px`;
        chatBubble.style.right = 'auto';
        chatBubble.style.bottom = 'auto';
      },
    });
  }

  // Enhanced click handlers - bubble protection during drag
  chatBubble.addEventListener('click', e => {
    // If currently dragging, ignore all clicks completely
    if (isDraggingAnyBubble) {
      e.preventDefault();
      e.stopPropagation();
      return;
    }
    
    // Check if we're in drag cooldown period
    if (chatBubble.dragHelper && chatBubble.dragHelper.dragCooldown) {
      e.preventDefault();
      e.stopPropagation();
      return;
    }
    
    // Otherwise, toggle the chat
    onBubbleClick();
  });

  closeBubble.addEventListener('click', e => {
    // If currently dragging, ignore all clicks completely
    if (isDraggingAnyBubble) {
      e.preventDefault();
      e.stopPropagation();
      return;
    }
    
    // Check if we're in drag cooldown period
    if (closeBubble.dragHelper && closeBubble.dragHelper.dragCooldown) {
      e.preventDefault();
      e.stopPropagation();
      return;
    }
    
    // Otherwise, close the chat
    onBubbleClick({ toggleValue: false });
  });
};

export const addUnreadClass = () => {
  const holderEl = document.querySelector('.woot-widget-holder');
  addClasses(holderEl, 'has-unread-view');
};

export const removeUnreadClass = () => {
  const holderEl = document.querySelector('.woot-widget-holder');
  removeClasses(holderEl, 'has-unread-view');
};
