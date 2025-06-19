import{a as E}from"./js.cookie-Cz0CWeBA.js";import{C as ot,a as it,p as nt,S as st,b as rt,c as at,d as lt,e as dt,f as ct}from"./sharedFrameEvents-0qZ2yOho.js";import{i as ut}from"./colorHelper-DkkSNPxc.js";import{g as ht}from"./_commonjsHelpers-BosuxZz1.js";import"./index-DN3rM4CW.js";const wt=`
:root {
  --b-100: #F2F3F7;
  --s-700: #37546D;
}

.woot-widget-holder {
  box-shadow: 0 5px 40px rgba(0, 0, 0, .16);
  opacity: 1;
  will-change: transform, opacity;
  transform: translateY(0);
  overflow: hidden !important;
  position: fixed !important;
  transition: opacity 0.2s linear, transform 0.25s linear;
  z-index: 2147483000 !important;
}

.woot-widget-holder.woot-widget-holder--flat {
  box-shadow: none;
  border-radius: 0;
  border: 1px solid var(--b-100);
}

.woot-widget-holder iframe {
  border: 0;
  color-scheme: normal;
  height: 100% !important;
  width: 100% !important;
  max-height: 100vh !important;
}

.woot-widget-holder.has-unread-view {
  border-radius: 0 !important;
  min-height: 80px !important;
  height: auto;
  bottom: 94px;
  box-shadow: none !important;
  border: 0;
}

.woot-widget-bubble {
  background: #1f93ff;
  border-radius: 100px;
  border-width: 0px;
  bottom: 20px;
  box-shadow: 0 8px 24px rgba(0, 0, 0, .16) !important;
  cursor: pointer;
  height: 64px;
  padding: 0px;
  position: fixed;
  user-select: none;
  width: 64px;
  z-index: 2147483000 !important;
  overflow: visible; /* Allow drag handle to show */
  transition: transform 0.3s cubic-bezier(0.4, 0.0, 0.2, 1), box-shadow 0.3s ease;
}

/* Hover area for better drag handle accessibility */
.woot-widget-hover-area {
  position: absolute !important;
  width: 120px !important;
  height: 120px !important;
  left: -28px !important;
  top: -28px !important;
  pointer-events: none !important;
  z-index: 2147483000 !important;
  border-radius: 50% !important;
}

/* Subtle pulse animation for clean drag handle */
@keyframes dragHandlePulse {
  0%, 100% {
    transform: scale(0.8);
    opacity: 0.6;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.1);
  }
  50% {
    transform: scale(0.9);
    opacity: 0.8;
    box-shadow: 0 6px 25px rgba(0, 0, 0, 0.15);
  }
}

.woot-widget-drag-handle--pulse {
  animation: dragHandlePulse 2.5s ease-in-out infinite !important;
}

/* Enhanced drag handle styling - Clean minimal design without SVG */
.woot-widget-drag-handle {
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  position: absolute !important;
  width: 24px !important;
  height: 24px !important;
  background: rgba(255, 255, 255, 0.9) !important;
  backdrop-filter: blur(10px) !important;
  -webkit-backdrop-filter: blur(10px) !important;
  border-radius: 50% !important;
  transition: all 0.3s cubic-bezier(0.4, 0.0, 0.2, 1) !important;
  transform: scale(0.8) !important;
  box-shadow: 0 4px 20px rgba(0, 0, 0, 0.2), 0 0 0 1px rgba(0, 0, 0, 0.1) inset !important;
  border: 2px solid rgba(0, 0, 0, 0.1) !important;
}

.woot-widget-drag-handle::before {
  content: '' !important;
  width: 8px !important;
  height: 8px !important;
  background: rgba(0, 0, 0, 0.4) !important;
  border-radius: 50% !important;
  transition: all 0.2s ease !important;
}

.woot-widget-drag-handle:hover {
  transform: scale(1) !important;
  cursor: grab !important;
  background: rgba(255, 255, 255, 0.95) !important;
  box-shadow: 0 6px 25px rgba(0, 0, 0, 0.25), 0 0 0 1px rgba(0, 0, 0, 0.15) inset !important;
  border: 2px solid rgba(0, 0, 0, 0.2) !important;
}

.woot-widget-drag-handle:hover::before {
  background: rgba(0, 0, 0, 0.6) !important;
  transform: scale(1.2) !important;
}

.woot-widget-drag-handle:active {
  cursor: grabbing !important;
  transform: scale(1.05) !important;
  background: rgba(255, 255, 255, 1) !important;
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.3), 0 0 0 1px rgba(0, 0, 0, 0.2) inset !important;
  border: 2px solid rgba(0, 0, 0, 0.3) !important;
}

.woot-widget-drag-handle:active::before {
  background: rgba(0, 0, 0, 0.8) !important;
  transform: scale(1.4) !important;
}

/* Enhanced drag states for premium UX */
.woot-widget-bubble--dragging {
  cursor: grabbing !important;
  transition: none !important;
  z-index: 2147483001 !important;
  transform: rotate(2deg) !important; /* Subtle tilt during drag */
}

.woot-widget-bubble--drag-active {
  transform: scale(1.08) rotate(2deg) !important;
  box-shadow: 0 16px 40px rgba(0, 0, 0, 0.3) !important;
  filter: brightness(1.1) !important;
}

.woot-widget-bubble:not(.woot-widget-bubble--dragging):hover {
  transform: scale(1.02) !important;
  box-shadow: 0 12px 32px rgba(0, 0, 0, .2) !important;
}

.woot-widget-bubble.woot-widget-bubble--flat {
  border-radius: 0;
}

.woot-widget-holder.woot-widget-holder--flat {
  bottom: 90px;
}

.woot-widget-bubble.woot-widget-bubble--flat {
  height: 56px;
  width: 56px;
}

.woot-widget-bubble.woot-widget-bubble--flat svg {
  margin: 16px;
}

.woot-widget-bubble.woot-widget-bubble--flat.woot--close::before,
.woot-widget-bubble.woot-widget-bubble--flat.woot--close::after {
  left: 28px;
  top: 16px;
}

.woot-widget-bubble.unread-notification::after {
  content: '';
  position: absolute;
  width: 12px;
  height: 12px;
  background: #ff4040;
  border-radius: 100%;
  top: 0px;
  right: 0px;
  border: 2px solid #ffffff;
  transition: background 0.2s ease;
}

.woot-widget-bubble.woot-widget--expanded {
  bottom: 24px;
  display: flex;
  height: 48px !important;
  width: auto !important;
  align-items: center;
}

.woot-widget-bubble.woot-widget--expanded div {
  align-items: center;
  color: #fff;
  display: flex;
  font-family: system-ui, -apple-system, BlinkMacSystemFont, Segoe UI, Roboto, Oxygen-Sans, Ubuntu, Cantarell, Helvetica Neue, Arial, sans-serif;
  font-size: 16px;
  font-weight: 500;
  justify-content: center;
  padding-right: 20px;
  width: auto !important;
}

.woot-widget-bubble.woot-widget--expanded.woot-widget-bubble-color--lighter div{
  color: var(--s-700);
}

.woot-widget-bubble.woot-widget--expanded svg {
  height: 20px;
  margin: 14px 8px 14px 16px;
  width: 20px;
}

.woot-widget-bubble.woot-elements--left {
  /* Position will be handled by drag helper */
}

.woot-widget-bubble.woot-elements--right {
  /* Position will be handled by drag helper */
}

.woot-widget-bubble:hover {
  /* This will be overridden by our enhanced drag styles */
}

.woot-widget-bubble svg {
  all: revert;
  height: 24px;
  margin: 20px;
  width: 24px;
}

.woot-widget-bubble.woot-widget-bubble-color--lighter path{
  fill: var(--s-700);
}

@media only screen and (min-width: 667px) {
  .woot-widget-holder.woot-elements--left {
    left: 20px;
 }
  .woot-widget-holder.woot-elements--right {
    right: 20px;
 }
}

.woot--close:hover {
  opacity: 1;
}

.woot--close::before, .woot--close::after {
  background-color: #fff;
  content: ' ';
  display: inline;
  height: 24px;
  left: 32px;
  position: absolute;
  top: 20px;
  width: 2px;
}

.woot-widget-bubble-color--lighter.woot--close::before, .woot-widget-bubble-color--lighter.woot--close::after {
  background-color: var(--s-700);
}

.woot--close::before {
  transform: rotate(45deg);
}

.woot--close::after {
  transform: rotate(-45deg);
}

.woot--hide {
  bottom: -100vh !important;
  top: unset !important;
  opacity: 0;
  visibility: hidden !important;
  z-index: -1 !important;
}

.woot-widget--without-bubble {
  bottom: 20px !important;
}
.woot-widget-holder.woot--hide{
  transform: translateY(40px);
}
.woot-widget-bubble.woot--close {
  transform: translateX(0px) scale(1) rotate(0deg);
  transition: transform 300ms ease, opacity 100ms ease, visibility 0ms linear 0ms, bottom 0ms linear 0ms;
}
.woot-widget-bubble.woot--close.woot--hide {
  transform: translateX(8px) scale(.75) rotate(45deg);
  transition: transform 300ms ease, opacity 200ms ease, visibility 0ms linear 500ms, bottom 0ms ease 200ms;
}

.woot-widget-bubble {
  transform-origin: center;
  will-change: transform, opacity;
  transform: translateX(0) scale(1) rotate(0deg);
  transition: transform 300ms ease, opacity 100ms ease, visibility 0ms linear 0ms, bottom 0ms linear 0ms;
}
.woot-widget-bubble.woot--hide {
  transform: translateX(8px) scale(.75) rotate(-30deg);
  transition: transform 300ms ease, opacity 200ms ease, visibility 0ms linear 500ms, bottom 0ms ease 200ms;
}

.woot-widget-bubble.woot-widget--expanded {
  transform: translateX(0px);
  transition: transform 300ms ease, opacity 100ms ease, visibility 0ms linear 0ms, bottom 0ms linear 0ms;
}
.woot-widget-bubble.woot-widget--expanded.woot--hide {
  transform: translateX(8px);
  transition: transform 300ms ease, opacity 200ms ease, visibility 0ms linear 500ms, bottom 0ms ease 200ms;
}
.woot-widget-bubble.woot-widget-bubble--flat.woot--close {
  transform: translateX(0px);
  transition: transform 300ms ease, opacity 10ms ease, visibility 0ms linear 0ms, bottom 0ms linear 0ms;
}
.woot-widget-bubble.woot-widget-bubble--flat.woot--close.woot--hide {
  transform: translateX(8px);
  transition: transform 300ms ease, opacity 200ms ease, visibility 0ms linear 500ms, bottom 0ms ease 200ms;
}
.woot-widget-bubble.woot-widget--expanded.woot-widget-bubble--flat {
  transform: translateX(0px);
  transition: transform 300ms ease, opacity 200ms ease, visibility 0ms linear 0ms, bottom 0ms linear 0ms;
}
.woot-widget-bubble.woot-widget--expanded.woot-widget-bubble--flat.woot--hide {
  transform: translateX(8px);
  transition: transform 300ms ease, opacity 200ms ease, visibility 0ms linear 500ms, bottom 0ms ease 200ms;
}

@media only screen and (max-width: 667px) {
  .woot-widget-holder {
    height: 100%;
    right: 0;
    top: 0;
    width: 100%;
 }

 .woot-widget-holder iframe {
    min-height: 100% !important;
  }


 .woot-widget-holder.has-unread-view {
    height: auto;
    right: 0;
    width: auto;
    bottom: 0;
    top: auto;
    max-height: 100vh;
    padding: 0 8px;
  }

  .woot-widget-holder.has-unread-view iframe {
    min-height: unset !important;
  }

 .woot-widget-holder.has-unread-view.woot-elements--left {
    left: 0;
  }

  .woot-widget-bubble.woot--close {
    bottom: 60px;
    opacity: 0;
    visibility: hidden !important;
    z-index: -1 !important;
  }
}

@media only screen and (min-width: 667px) {
  .woot-widget-holder {
    border-radius: 16px;
    bottom: 104px;
    height: calc(90% - 64px - 20px);
    max-height: 640px !important;
    min-height: 250px !important;
    width: 400px !important;
 }
}

.woot-hidden {
  display: none !important;
}
`,gt=()=>{const t=document.createElement("style");t.innerHTML=`${wt}`,t.id="cw-widget-styles",t.dataset.turboPermanent=!0,document.body.appendChild(t)},$=(t,e)=>{const i=document.getElementById(t),c=e.querySelector(`#${t}`);i&&!c&&e.appendChild(i)},L=t=>{$("cw-bubble-holder",t),$("cw-widget-holder",t),$("cw-widget-styles",t)},C=(t,e)=>{t.classList.add(...e.split(" "))},M=(t,e)=>{t.classList.toggle(e)},B=(t,e)=>{t.classList.remove(...e.split(" "))},A=({referrerURL:t,referrerHost:e})=>{w.events.onLocationChange({referrerURL:t,referrerHost:e})},bt=()=>{let t=document.location.href;const e=document.location.host,i={childList:!0,subtree:!0};A({referrerURL:t,referrerHost:e});const c=document.querySelector("body");new MutationObserver(s=>{s.forEach(()=>{t!==document.location.href&&(t=document.location.href,A({referrerURL:t,referrerHost:e}))})}).observe(c,i)},P=["standard","expanded_bubble"],F=["standard","flat"],U=["light","auto","dark"],z=t=>P.includes(t)?t:P[0],V=t=>z(t)===P[1],pt=t=>F.includes(t)?t:F[0],O=t=>t==="flat",N=t=>U.includes(t)?t:U[0],mt=({eventName:t,data:e=null})=>{let i;return typeof window.CustomEvent=="function"?i=new CustomEvent(t,{detail:e}):(i=document.createEvent("CustomEvent"),i.initCustomEvent(t,!1,!1,e)),i},T=({eventName:t,data:e})=>{const i=mt({eventName:t,data:e});window.dispatchEvent(i)};class X{constructor(e,i={}){this.bubble=e,this.isDragging=!1,this.dragStarted=!1,this.startX=0,this.startY=0,this.initialX=0,this.initialY=0,this.currentX=0,this.currentY=0,this.lastDragDistance=0,this.options={dragThreshold:5,clickTimeThreshold:150,persistPosition:!0,onPositionChange:null,onDragStart:null,onDragEnd:null,...i},this.clickStartTime=0,this.boundaryPadding=20,this.dragCooldown=!1,this.initializeDragEvents(),this.restoreSavedPosition(),this.setupWindowHandlers()}initializeDragEvents(){this.bubble.addEventListener("touchstart",this.handleTouchStart.bind(this),{passive:!1}),this.bubble.addEventListener("touchmove",this.handleTouchMove.bind(this),{passive:!1}),this.bubble.addEventListener("touchend",this.handleTouchEnd.bind(this),{passive:!1}),this.bubble.addEventListener("mousedown",this.handleMouseDown.bind(this),{passive:!1}),document.addEventListener("mousemove",this.handleMouseMove.bind(this),{passive:!1}),document.addEventListener("mouseup",this.handleMouseUp.bind(this),{passive:!1}),this.bubble.addEventListener("dragstart",e=>e.preventDefault())}handleTouchStart(e){this.startDrag(e.touches[0].clientX,e.touches[0].clientY)}handleMouseDown(e){this.startDrag(e.clientX,e.clientY)}startDrag(e,i){this.isDragging=!0,this.dragStarted=!1,this.clickStartTime=Date.now(),this.startX=e,this.startY=i;const c=this.bubble.getBoundingClientRect();this.initialX=c.left,this.initialY=c.top,this.currentX=this.initialX,this.currentY=this.initialY,this.bubble.classList.add("woot-widget-bubble--dragging"),document.body.style.userSelect="none"}handleTouchMove(e){this.isDragging&&(e.preventDefault(),this.updateDrag(e.touches[0].clientX,e.touches[0].clientY))}handleMouseMove(e){this.isDragging&&(e.preventDefault(),this.updateDrag(e.clientX,e.clientY))}updateDrag(e,i){const c=e-this.startX,d=i-this.startY;if(this.lastDragDistance=Math.sqrt(c*c+d*d),!this.dragStarted&&this.lastDragDistance>this.options.dragThreshold){this.dragStarted=!0,this.bubble.classList.add("woot-widget-bubble--drag-active");const s=this.bubble.closest(".woot-widget-bubble")||this.bubble.parentElement||this.bubble;s.style.transition="none",s.style.transform="scale(1.12)",setTimeout(()=>{s.style.transform="scale(1.08) rotate(2deg)"},50),typeof this.options.onDragStart=="function"&&this.options.onDragStart()}this.dragStarted&&(this.currentX=this.initialX+c,this.currentY=this.initialY+d,this.constrainToViewport(),this.applyPosition(),typeof this.options.onPositionChange=="function"&&this.options.onPositionChange(this.currentX,this.currentY))}handleTouchEnd(e){this.endDrag()}handleMouseUp(e){this.endDrag()}endDrag(){if(this.isDragging){if(this.bubble.classList.remove("woot-widget-bubble--dragging","woot-widget-bubble--drag-active"),document.body.style.userSelect="",this.dragStarted){this.saveBubblePosition();const e=this.bubble.closest(".woot-widget-bubble")||this.bubble.parentElement||this.bubble;e.style.transition="transform 0.4s cubic-bezier(0.4, 0.0, 0.2, 1)",e.style.transform="scale(1) rotate(0deg)",setTimeout(()=>{e.style.transition="transform 0.3s cubic-bezier(0.4, 0.0, 0.2, 1), box-shadow 0.3s ease"},400),this.dragCooldown=!0,setTimeout(()=>{this.dragCooldown=!1},250)}typeof this.options.onDragEnd=="function"&&this.options.onDragEnd(),this.isDragging=!1,this.dragStarted=!1,this.lastDragDistance=0}}constrainToViewport(){const e={width:window.innerWidth||document.documentElement.clientWidth,height:window.innerHeight||document.documentElement.clientHeight},i=this.bubble.getBoundingClientRect(),c=i.width,d=i.height;this.currentX=Math.max(this.boundaryPadding,Math.min(e.width-c-this.boundaryPadding,this.currentX)),this.currentY=Math.max(this.boundaryPadding,Math.min(e.height-d-this.boundaryPadding,this.currentY))}applyPosition(){const e=this.bubble.closest(".woot-widget-bubble")||this.bubble.parentElement||this.bubble;e.style.left=`${this.currentX}px`,e.style.top=`${this.currentY}px`,e.style.right="auto",e.style.bottom="auto",typeof this.options.onPositionChange=="function"&&this.options.onPositionChange(this.currentX,this.currentY)}handleBubbleClick(){this.bubble.classList.contains("woot-widget-drag-handle")||(window.$chatwoot&&typeof window.$chatwoot.toggle=="function"&&window.$chatwoot.toggle(),this.options.onBubbleClick&&this.options.onBubbleClick())}saveBubblePosition(){if(this.options.persistPosition)try{const e={x:this.currentX,y:this.currentY,timestamp:Date.now()};localStorage.setItem("chatwoot_bubble_position",JSON.stringify(e))}catch(e){console.warn("Could not save bubble position:",e)}}restoreSavedPosition(){if(!this.options.persistPosition){this.setDefaultPosition();return}try{const e=localStorage.getItem("chatwoot_bubble_position");if(e){const i=JSON.parse(e),c=7*24*60*60*1e3;if(Date.now()-i.timestamp<c){this.currentX=i.x,this.currentY=i.y,this.constrainToViewport(),this.applyPosition();return}}}catch(e){console.warn("Could not restore bubble position:",e)}this.setDefaultPosition()}setDefaultPosition(){var d;const e={width:window.innerWidth||document.documentElement.clientWidth,height:window.innerHeight||document.documentElement.clientHeight},i=this.bubble.getBoundingClientRect();(((d=window.$chatwoot)==null?void 0:d.position)||"right")==="left"?this.currentX=this.boundaryPadding:this.currentX=e.width-i.width-this.boundaryPadding,this.currentY=e.height-i.height-this.boundaryPadding,this.applyPosition()}setPosition(e,i){this.currentX=e,this.currentY=i,this.constrainToViewport(),this.applyPosition(),this.saveBubblePosition()}resetPosition(){const e={width:window.innerWidth||document.documentElement.clientWidth,height:window.innerHeight||document.documentElement.clientHeight},i=this.bubble.getBoundingClientRect();this.currentX=e.width-i.width-this.boundaryPadding,this.currentY=e.height-i.height-this.boundaryPadding,this.applyPosition(),this.saveBubblePosition()}setupWindowHandlers(){this.handleResize=()=>{this.constrainToViewport(),this.applyPosition()},window.addEventListener("resize",this.handleResize)}destroy(){this.bubble.removeEventListener("touchstart",this.handleTouchStart),this.bubble.removeEventListener("touchmove",this.handleTouchMove),this.bubble.removeEventListener("touchend",this.handleTouchEnd),this.bubble.removeEventListener("mousedown",this.handleMouseDown),document.removeEventListener("mousemove",this.handleMouseMove),document.removeEventListener("mouseup",this.handleMouseUp),window.removeEventListener("resize",this.handleResize)}}const ft="M240.808 240.808H122.123C56.6994 240.808 3.45695 187.562 3.45695 122.122C3.45695 56.7031 56.6994 3.45697 122.124 3.45697C187.566 3.45697 240.808 56.7031 240.808 122.122V240.808Z",q=document.getElementsByTagName("body")[0],x=document.createElement("div"),S=document.createElement("div"),p=document.createElement("button"),g=document.createElement("button");document.createElement("span");const vt=t=>{if(V(window.$chatwoot.type)){const e=document.getElementById("woot-widget--expanded__text");e.innerText=t}},yt=({className:t,path:e,target:i})=>{let c=`${t} woot-elements--${window.$chatwoot.position}`;const d=document.createElementNS("http://www.w3.org/2000/svg","svg");d.setAttributeNS(null,"id","woot-widget-bubble-icon"),d.setAttributeNS(null,"width","24"),d.setAttributeNS(null,"height","24"),d.setAttributeNS(null,"viewBox","0 0 240 240"),d.setAttributeNS(null,"fill","none"),d.setAttribute("xmlns","http://www.w3.org/2000/svg");const s=document.createElementNS("http://www.w3.org/2000/svg","path");if(s.setAttributeNS(null,"d",e),s.setAttributeNS(null,"fill","#FFFFFF"),d.appendChild(s),i.appendChild(d),V(window.$chatwoot.type)){const h=document.createElement("div");h.id="woot-widget--expanded__text",h.innerText="",i.appendChild(h),c+=" woot-widget--expanded"}return i.className=c,i.title="Open chat window",i},xt=t=>{t&&C(S,"woot-hidden"),C(S,"woot--bubble-holder"),S.id="cw-bubble-holder",S.dataset.turboPermanent=!0,q.appendChild(S)},Et=t=>{w.events.onBubbleToggle(t),t?T({eventName:ot}):(T({eventName:it}),p.focus())},D=(t={})=>{const{toggleValue:e}=t,{isOpen:i}=window.$chatwoot;if(i===e)return;const c=e===void 0?!i:e;window.$chatwoot.isOpen=c,M(p,"woot--hide"),M(g,"woot--hide"),M(x,"woot--hide"),Et(c)},Ct=()=>{let t=!1;const e=()=>{const o=document.createElement("div");return o.className="woot-widget-hover-area",o.style.position="absolute",o.style.width="240px",o.style.height="180px",o.style.left="-28px",o.style.top="-28px",o.style.pointerEvents="none",o.style.zIndex="2147483000",o},i=()=>{const o=document.createElement("div");return o.className="woot-widget-drag-handle",o.innerHTML="",o.title="Drag to move chat bubble",o.style.position="absolute",o.style.width="24px",o.style.height="24px",o.style.cursor="grab",o.style.opacity="0",o.style.transition="opacity 0.3s ease, transform 0.2s ease",o.style.zIndex="2147483002",o.style.userSelect="none",o.style.pointerEvents="none",o.addEventListener("click",n=>{n.preventDefault(),n.stopPropagation(),n.stopImmediatePropagation()}),o.addEventListener("mousedown",n=>{n.stopPropagation()}),o.addEventListener("mouseup",n=>{n.preventDefault(),n.stopPropagation(),n.stopImmediatePropagation()}),o},c=o=>{o.style.left="20px",o.style.right="auto",o.style.top="-32px",o.style.bottom="auto"},d=i(),s=i(),h=e(),a=e();p.appendChild(h),p.appendChild(d),g.appendChild(a),g.appendChild(s),p.style.position=p.style.position||"fixed",g.style.position=g.style.position||"fixed";const b=(o,n,l)=>{let r,u;const m=()=>{clearTimeout(r),clearTimeout(u),c(n),n.style.opacity="1",n.style.pointerEvents="auto",n.style.transform="scale(1)",n.classList.remove("woot-widget-drag-handle--pulse")},f=()=>{r=setTimeout(()=>{!n.matches(":hover")&&!o.matches(":hover")&&(n.style.opacity="0",n.style.pointerEvents="none",n.style.transform="scale(0.8)",u=setTimeout(()=>{n.style.opacity==="0"&&n.classList.add("woot-widget-drag-handle--pulse")},3e3))},200)};l.style.pointerEvents="auto",l.addEventListener("mouseenter",m),l.addEventListener("mouseleave",f),o.addEventListener("mouseenter",m),o.addEventListener("mouseleave",f),n.addEventListener("mouseenter",m),n.addEventListener("mouseleave",f)};b(p,d,h),b(g,s,a),p&&!p.dragHelper&&(p.dragHelper=new X(d,{dragThreshold:3,clickTimeThreshold:100,persistPosition:!0,onDragStart:()=>{t=!0},onDragEnd:()=>{t=!1},onPositionChange:(o,n)=>{p.style.left=`${o}px`,p.style.top=`${n}px`,p.style.right="auto",p.style.bottom="auto",g.style.left=`${o}px`,g.style.top=`${n}px`,g.style.right="auto",g.style.bottom="auto",setTimeout(()=>{c(d),c(s)},0)}})),g&&!g.dragHelper&&(g.dragHelper=new X(s,{dragThreshold:3,clickTimeThreshold:100,persistPosition:!0,onDragStart:()=>{t=!0},onDragEnd:()=>{t=!1},onPositionChange:(o,n)=>{g.style.left=`${o}px`,g.style.top=`${n}px`,g.style.right="auto",g.style.bottom="auto",p.style.left=`${o}px`,p.style.top=`${n}px`,p.style.right="auto",p.style.bottom="auto",setTimeout(()=>{c(d),c(s)},0)}})),p.addEventListener("click",o=>{if(t){o.preventDefault(),o.stopPropagation();return}if(o.target.closest(".woot-widget-drag-handle")){o.preventDefault(),o.stopPropagation();return}if(p.dragHelper&&p.dragHelper.dragCooldown){o.preventDefault(),o.stopPropagation();return}D()}),g.addEventListener("click",o=>{if(t){o.preventDefault(),o.stopPropagation();return}if(o.target.closest(".woot-widget-drag-handle")){o.preventDefault(),o.stopPropagation();return}if(g.dragHelper&&g.dragHelper.dragCooldown){o.preventDefault(),o.stopPropagation();return}D({toggleValue:!1})})},St=()=>{const t=document.querySelector(".woot-widget-holder");C(t,"has-unread-view")},I=()=>{const t=document.querySelector(".woot-widget-holder");B(t,"has-unread-view")};var K={exports:{}},G={exports:{}};(function(){var t="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",e={rotl:function(i,c){return i<<c|i>>>32-c},rotr:function(i,c){return i<<32-c|i>>>c},endian:function(i){if(i.constructor==Number)return e.rotl(i,8)&16711935|e.rotl(i,24)&4278255360;for(var c=0;c<i.length;c++)i[c]=e.endian(i[c]);return i},randomBytes:function(i){for(var c=[];i>0;i--)c.push(Math.floor(Math.random()*256));return c},bytesToWords:function(i){for(var c=[],d=0,s=0;d<i.length;d++,s+=8)c[s>>>5]|=i[d]<<24-s%32;return c},wordsToBytes:function(i){for(var c=[],d=0;d<i.length*32;d+=8)c.push(i[d>>>5]>>>24-d%32&255);return c},bytesToHex:function(i){for(var c=[],d=0;d<i.length;d++)c.push((i[d]>>>4).toString(16)),c.push((i[d]&15).toString(16));return c.join("")},hexToBytes:function(i){for(var c=[],d=0;d<i.length;d+=2)c.push(parseInt(i.substr(d,2),16));return c},bytesToBase64:function(i){for(var c=[],d=0;d<i.length;d+=3)for(var s=i[d]<<16|i[d+1]<<8|i[d+2],h=0;h<4;h++)d*8+h*6<=i.length*8?c.push(t.charAt(s>>>6*(3-h)&63)):c.push("=");return c.join("")},base64ToBytes:function(i){i=i.replace(/[^A-Z0-9+\/]/ig,"");for(var c=[],d=0,s=0;d<i.length;s=++d%4)s!=0&&c.push((t.indexOf(i.charAt(d-1))&Math.pow(2,-2*s+8)-1)<<s*2|t.indexOf(i.charAt(d))>>>6-s*2);return c}};G.exports=e})();var Tt=G.exports,_={utf8:{stringToBytes:function(t){return _.bin.stringToBytes(unescape(encodeURIComponent(t)))},bytesToString:function(t){return decodeURIComponent(escape(_.bin.bytesToString(t)))}},bin:{stringToBytes:function(t){for(var e=[],i=0;i<t.length;i++)e.push(t.charCodeAt(i)&255);return e},bytesToString:function(t){for(var e=[],i=0;i<t.length;i++)e.push(String.fromCharCode(t[i]));return e.join("")}}},R=_;/*!
 * Determine if an object is a Buffer
 *
 * @author   Feross Aboukhadijeh <https://feross.org>
 * @license  MIT
 */var Dt=function(t){return t!=null&&(J(t)||Bt(t)||!!t._isBuffer)};function J(t){return!!t.constructor&&typeof t.constructor.isBuffer=="function"&&t.constructor.isBuffer(t)}function Bt(t){return typeof t.readFloatLE=="function"&&typeof t.slice=="function"&&J(t.slice(0,0))}(function(){var t=Tt,e=R.utf8,i=Dt,c=R.bin,d=function(s,h){s.constructor==String?h&&h.encoding==="binary"?s=c.stringToBytes(s):s=e.stringToBytes(s):i(s)?s=Array.prototype.slice.call(s,0):!Array.isArray(s)&&s.constructor!==Uint8Array&&(s=s.toString());for(var a=t.bytesToWords(s),b=s.length*8,o=1732584193,n=-271733879,l=-1732584194,r=271733878,u=0;u<a.length;u++)a[u]=(a[u]<<8|a[u]>>>24)&16711935|(a[u]<<24|a[u]>>>8)&4278255360;a[b>>>5]|=128<<b%32,a[(b+64>>>9<<4)+14]=b;for(var m=d._ff,f=d._gg,v=d._hh,y=d._ii,u=0;u<a.length;u+=16){var Q=o,j=n,tt=l,et=r;o=m(o,n,l,r,a[u+0],7,-680876936),r=m(r,o,n,l,a[u+1],12,-389564586),l=m(l,r,o,n,a[u+2],17,606105819),n=m(n,l,r,o,a[u+3],22,-1044525330),o=m(o,n,l,r,a[u+4],7,-176418897),r=m(r,o,n,l,a[u+5],12,1200080426),l=m(l,r,o,n,a[u+6],17,-1473231341),n=m(n,l,r,o,a[u+7],22,-45705983),o=m(o,n,l,r,a[u+8],7,1770035416),r=m(r,o,n,l,a[u+9],12,-1958414417),l=m(l,r,o,n,a[u+10],17,-42063),n=m(n,l,r,o,a[u+11],22,-1990404162),o=m(o,n,l,r,a[u+12],7,1804603682),r=m(r,o,n,l,a[u+13],12,-40341101),l=m(l,r,o,n,a[u+14],17,-1502002290),n=m(n,l,r,o,a[u+15],22,1236535329),o=f(o,n,l,r,a[u+1],5,-165796510),r=f(r,o,n,l,a[u+6],9,-1069501632),l=f(l,r,o,n,a[u+11],14,643717713),n=f(n,l,r,o,a[u+0],20,-373897302),o=f(o,n,l,r,a[u+5],5,-701558691),r=f(r,o,n,l,a[u+10],9,38016083),l=f(l,r,o,n,a[u+15],14,-660478335),n=f(n,l,r,o,a[u+4],20,-405537848),o=f(o,n,l,r,a[u+9],5,568446438),r=f(r,o,n,l,a[u+14],9,-1019803690),l=f(l,r,o,n,a[u+3],14,-187363961),n=f(n,l,r,o,a[u+8],20,1163531501),o=f(o,n,l,r,a[u+13],5,-1444681467),r=f(r,o,n,l,a[u+2],9,-51403784),l=f(l,r,o,n,a[u+7],14,1735328473),n=f(n,l,r,o,a[u+12],20,-1926607734),o=v(o,n,l,r,a[u+5],4,-378558),r=v(r,o,n,l,a[u+8],11,-2022574463),l=v(l,r,o,n,a[u+11],16,1839030562),n=v(n,l,r,o,a[u+14],23,-35309556),o=v(o,n,l,r,a[u+1],4,-1530992060),r=v(r,o,n,l,a[u+4],11,1272893353),l=v(l,r,o,n,a[u+7],16,-155497632),n=v(n,l,r,o,a[u+10],23,-1094730640),o=v(o,n,l,r,a[u+13],4,681279174),r=v(r,o,n,l,a[u+0],11,-358537222),l=v(l,r,o,n,a[u+3],16,-722521979),n=v(n,l,r,o,a[u+6],23,76029189),o=v(o,n,l,r,a[u+9],4,-640364487),r=v(r,o,n,l,a[u+12],11,-421815835),l=v(l,r,o,n,a[u+15],16,530742520),n=v(n,l,r,o,a[u+2],23,-995338651),o=y(o,n,l,r,a[u+0],6,-198630844),r=y(r,o,n,l,a[u+7],10,1126891415),l=y(l,r,o,n,a[u+14],15,-1416354905),n=y(n,l,r,o,a[u+5],21,-57434055),o=y(o,n,l,r,a[u+12],6,1700485571),r=y(r,o,n,l,a[u+3],10,-1894986606),l=y(l,r,o,n,a[u+10],15,-1051523),n=y(n,l,r,o,a[u+1],21,-2054922799),o=y(o,n,l,r,a[u+8],6,1873313359),r=y(r,o,n,l,a[u+15],10,-30611744),l=y(l,r,o,n,a[u+6],15,-1560198380),n=y(n,l,r,o,a[u+13],21,1309151649),o=y(o,n,l,r,a[u+4],6,-145523070),r=y(r,o,n,l,a[u+11],10,-1120210379),l=y(l,r,o,n,a[u+2],15,718787259),n=y(n,l,r,o,a[u+9],21,-343485551),o=o+Q>>>0,n=n+j>>>0,l=l+tt>>>0,r=r+et>>>0}return t.endian([o,n,l,r])};d._ff=function(s,h,a,b,o,n,l){var r=s+(h&a|~h&b)+(o>>>0)+l;return(r<<n|r>>>32-n)+h},d._gg=function(s,h,a,b,o,n,l){var r=s+(h&b|a&~b)+(o>>>0)+l;return(r<<n|r>>>32-n)+h},d._hh=function(s,h,a,b,o,n,l){var r=s+(h^a^b)+(o>>>0)+l;return(r<<n|r>>>32-n)+h},d._ii=function(s,h,a,b,o,n,l){var r=s+(a^(h|~b))+(o>>>0)+l;return(r<<n|r>>>32-n)+h},d._blocksize=16,d._digestsize=16,K.exports=function(s,h){if(s==null)throw new Error("Illegal argument "+s);var a=t.wordsToBytes(d(s,h));return h&&h.asBytes?a:h&&h.asString?c.bytesToString(a):t.bytesToHex(a)}})();var $t=K.exports;const Lt=ht($t),Z=["avatar_url","email","name"],Mt=[...Z,"identifier_hash"],H=()=>{const t="cw_user_",{websiteToken:e}=window.$chatwoot;return`${t}${e}`},Pt=({identifier:t="",user:e})=>`${Mt.reduce((c,d)=>`${c}${d}${e[d]||""}`,"")}identifier${t}`,_t=(...t)=>Lt(Pt(...t)),Ht=t=>Z.reduce((e,i)=>e||!!t[i],!1),k=(t,e,{expires:i=365,baseDomain:c=void 0}={})=>{const d={expires:i,sameSite:"Lax",domain:c};typeof e=="object"&&(e=JSON.stringify(e)),E.set(t,e,d)},W=["click","touchstart","keypress","keydown"],kt=()=>{let t;try{t=new(window.AudioContext||window.webkitAudioContext)}catch{}return t},At=async(t="",e)=>{const i=kt(),c=d=>{window.playAudioAlert=()=>{if(i){const s=i.createBufferSource();s.buffer=d,s.connect(i.destination),s.loop=!1,s.start()}}};if(i){const{type:d="dashboard",alertTone:s="ding"}=e||{},h=`${t}/audio/${d}/${s}.mp3`,a=new Request(h);fetch(a).then(b=>b.arrayBuffer()).then(b=>(i.decodeAudioData(b).then(c),new Promise(o=>o()))).catch(()=>{})}},Y=(t,e="")=>k("cw_conversation",t,{baseDomain:e}),Ft=t=>{const e=rt(new Date,1);k("cw_snooze_campaigns_till",Number(e),{expires:e,baseDomain:t})},w={getUrl({baseUrl:t,websiteToken:e}){return`${t}/widget?website_token=${e}`},createFrame:({baseUrl:t,websiteToken:e})=>{if(w.getAppFrame())return;gt();const i=document.createElement("iframe"),c=E.get("cw_conversation");let d=w.getUrl({baseUrl:t,websiteToken:e});c&&(d=`${d}&cw_conversation=${c}`),i.src=d,i.allow="camera;microphone;fullscreen;display-capture;picture-in-picture;clipboard-write;",i.id="chatwoot_live_chat_widget",i.style.visibility="hidden";let s=`woot-widget-holder woot--hide woot-elements--${window.$chatwoot.position}`;window.$chatwoot.hideMessageBubble&&(s+=" woot-widget--without-bubble"),O(window.$chatwoot.widgetStyle)&&(s+=" woot-widget-holder--flat"),C(x,s),x.id="cw-widget-holder",x.dataset.turboPermanent=!0,x.appendChild(i),q.appendChild(x),w.initPostMessageCommunication(),w.initWindowSizeListener(),w.preventDefaultScroll()},getAppFrame:()=>document.getElementById("chatwoot_live_chat_widget"),getBubbleHolder:()=>document.getElementsByClassName("woot--bubble-holder"),sendMessage:(t,e)=>{w.getAppFrame().contentWindow.postMessage(`chatwoot-widget:${JSON.stringify({event:t,...e})}`,"*")},initPostMessageCommunication:()=>{window.onmessage=t=>{if(typeof t.data!="string"||t.data.indexOf("chatwoot-widget:")!==0)return;const e=JSON.parse(t.data.replace("chatwoot-widget:",""));typeof w.events[e.event]=="function"&&w.events[e.event](e)}},initWindowSizeListener:()=>{window.addEventListener("resize",()=>w.toggleCloseButton())},preventDefaultScroll:()=>{x.addEventListener("wheel",t=>{const e=t.deltaY,i=x.scrollHeight,c=x.offsetHeight,d=x.scrollTop;(d===0&&e<0||c+d===i&&e>0)&&t.preventDefault()})},setFrameHeightToFitContent:(t,e)=>{const i=w.getAppFrame(),c=e?`${t}px`:"100%";i&&i.setAttribute("style",`height: ${c} !important`)},setupAudioListeners:()=>{const{baseUrl:t=""}=window.$chatwoot;At(t,{type:"widget",alertTone:"ding"}).then(()=>W.forEach(e=>{document.removeEventListener(e,w.setupAudioListeners,!1)}))},events:{loaded:t=>{Y(t.config.authToken,window.$chatwoot.baseDomain),window.$chatwoot.hasLoaded=!0;const e=E.get("cw_snooze_campaigns_till");w.sendMessage("config-set",{locale:window.$chatwoot.locale,position:window.$chatwoot.position,hideMessageBubble:window.$chatwoot.hideMessageBubble,showPopoutButton:window.$chatwoot.showPopoutButton,widgetStyle:window.$chatwoot.widgetStyle,darkMode:window.$chatwoot.darkMode,showUnreadMessagesDialog:window.$chatwoot.showUnreadMessagesDialog,campaignsSnoozedTill:e}),w.onLoad({widgetColor:t.config.channelConfig.widgetColor}),w.toggleCloseButton(),window.$chatwoot.user&&w.sendMessage("set-user",window.$chatwoot.user),window.playAudioAlert=()=>{},W.forEach(i=>{document.addEventListener(i,w.setupAudioListeners,!1)}),window.$chatwoot.resetTriggered||T({eventName:dt})},error:({errorType:t,data:e})=>{T({eventName:lt,data:e}),t===st&&E.remove(H())},onEvent({eventIdentifier:t,data:e}){T({eventName:t,data:e})},setBubbleLabel(t){vt(window.$chatwoot.launcherTitle||t.label)},setAuthCookie({data:{widgetAuthToken:t}}){Y(t,window.$chatwoot.baseDomain)},setCampaignReadOn(){Ft(window.$chatwoot.baseDomain)},postback(t){T({eventName:at,data:t})},toggleBubble:t=>{let e={};t==="open"?e.toggleValue=!0:t==="close"&&(e.toggleValue=!1),D(e)},popoutChatWindow:({baseUrl:t,websiteToken:e,locale:i})=>{const c=E.get("cw_conversation");window.$chatwoot.toggle("close"),nt(t,e,i,c)},closeWindow:()=>{D({toggleValue:!1}),I()},onBubbleToggle:t=>{w.sendMessage("toggle-open",{isOpen:t}),t&&w.pushEvent("webwidget.triggered")},onLocationChange:({referrerURL:t,referrerHost:e})=>{w.sendMessage("change-url",{referrerURL:t,referrerHost:e})},updateIframeHeight:t=>{const{extraHeight:e=0,isFixedHeight:i}=t;w.setFrameHeightToFitContent(e,i)},setUnreadMode:()=>{St(),D({toggleValue:!0})},resetUnreadMode:()=>I(),handleNotificationDot:t=>{if(window.$chatwoot.hideMessageBubble)return;const e=document.querySelector(".woot-widget-bubble");t.unreadMessageCount>0&&!e.classList.contains("unread-notification")?C(e,"unread-notification"):t.unreadMessageCount===0&&B(e,"unread-notification")},closeChat:()=>{D({toggleValue:!1})},playAudio:()=>{window.playAudioAlert()}},pushEvent:t=>{w.sendMessage("push-event",{eventName:t})},onLoad:({widgetColor:t})=>{const e=w.getAppFrame();if(e.style.visibility="",e.setAttribute("id","chatwoot_live_chat_widget"),w.getBubbleHolder().length)return;xt(window.$chatwoot.hideMessageBubble),bt();let i="woot-widget-bubble",c=`woot-elements--${window.$chatwoot.position} woot-widget-bubble woot--close woot--hide`;O(window.$chatwoot.widgetStyle)&&(i+=" woot-widget-bubble--flat",c+=" woot-widget-bubble--flat"),ut(t)&&(i+=" woot-widget-bubble-color--lighter",c+=" woot-widget-bubble-color--lighter");const d=yt({className:i,path:ft,target:p});C(g,c),d.style.background=t,g.style.background=t,S.appendChild(d),S.appendChild(g),Ct()},toggleCloseButton:()=>{let t=!1;window.matchMedia("(max-width: 668px)").matches&&(t=!0),w.sendMessage("toggle-close-button",{isMobile:t})}},Ut=({baseUrl:t,websiteToken:e})=>{if(window.$chatwoot)return;document.addEventListener("turbo:before-render",s=>{s.detail.renderMethod!=="morph"&&L(s.detail.newBody)}),window.Turbolinks&&document.addEventListener("turbolinks:before-render",s=>{L(s.data.newBody)}),document.addEventListener("astro:before-swap",s=>L(s.newDocument.body));const i=window.chatwootSettings||{};let c=i.locale,d=i.baseDomain;i.useBrowserLanguage&&(c=window.navigator.language.replace("-","_")),window.$chatwoot={baseUrl:t,baseDomain:d,hasLoaded:!1,hideMessageBubble:i.hideMessageBubble||!1,isOpen:!1,position:i.position==="left"?"left":"right",websiteToken:e,locale:c,useBrowserLanguage:i.useBrowserLanguage||!1,type:z(i.type),launcherTitle:i.launcherTitle||"",showPopoutButton:i.showPopoutButton||!1,showUnreadMessagesDialog:i.showUnreadMessagesDialog??!0,widgetStyle:pt(i.widgetStyle)||"standard",resetTriggered:!1,darkMode:N(i.darkMode),toggle(s){w.events.toggleBubble(s)},toggleBubbleVisibility(s){let h=document.querySelector(".woot--bubble-holder"),a=document.querySelector(".woot-widget-holder");s==="hide"?(C(a,"woot-widget--without-bubble"),C(h,"woot-hidden"),window.$chatwoot.hideMessageBubble=!0):s==="show"&&(B(h,"woot-hidden"),B(a,"woot-widget--without-bubble"),window.$chatwoot.hideMessageBubble=!1),w.sendMessage(ct,{hideMessageBubble:window.$chatwoot.hideMessageBubble})},popoutChatWindow(){w.events.popoutChatWindow({baseUrl:window.$chatwoot.baseUrl,websiteToken:window.$chatwoot.websiteToken,locale:c})},setUser(s,h){if(typeof s!="string"&&typeof s!="number")throw new Error("Identifier should be a string or a number");if(!Ht(h))throw new Error("User object should have one of the keys [avatar_url, email, name]");const a=H(),b=E.get(a),o=_t({identifier:s,user:h});o!==b&&(window.$chatwoot.identifier=s,window.$chatwoot.user=h,w.sendMessage("set-user",{identifier:s,user:h}),k(a,o,{baseDomain:d}))},setCustomAttributes(s={}){if(!s||!Object.keys(s).length)throw new Error("Custom attributes should have atleast one key");w.sendMessage("set-custom-attributes",{customAttributes:s})},deleteCustomAttribute(s=""){if(s)w.sendMessage("delete-custom-attribute",{customAttribute:s});else throw new Error("Custom attribute is required")},setConversationCustomAttributes(s={}){if(!s||!Object.keys(s).length)throw new Error("Custom attributes should have atleast one key");w.sendMessage("set-conversation-custom-attributes",{customAttributes:s})},deleteConversationCustomAttribute(s=""){if(s)w.sendMessage("delete-conversation-custom-attribute",{customAttribute:s});else throw new Error("Custom attribute is required")},setLabel(s=""){w.sendMessage("set-label",{label:s})},removeLabel(s=""){w.sendMessage("remove-label",{label:s})},setLocale(s="en"){w.sendMessage("set-locale",{locale:s})},setColorScheme(s="light"){w.sendMessage("set-color-scheme",{darkMode:N(s)})},reset(){window.$chatwoot.isOpen&&w.events.toggleBubble(),E.remove("cw_conversation"),E.remove(H());const s=w.getAppFrame();s.src=w.getUrl({baseUrl:window.$chatwoot.baseUrl,websiteToken:window.$chatwoot.websiteToken}),window.$chatwoot.resetTriggered=!0}},w.createFrame({baseUrl:t,websiteToken:e})};window.chatwootSDK={run:Ut};
