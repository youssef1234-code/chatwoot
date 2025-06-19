import{a as E}from"./js.cookie-Cz0CWeBA.js";import{C as ot,a as it,p as nt,S as st,b as rt,c as at,d as lt,e as dt,f as ht}from"./sharedFrameEvents-0qZ2yOho.js";import{i as ut}from"./colorHelper-DkkSNPxc.js";import{g as ct}from"./_commonjsHelpers-BosuxZz1.js";import"./index-DN3rM4CW.js";const wt=`
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

/* Enhanced bubble drag states - Direct bubble dragging */
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
  cursor: grab !important; /* Show grab cursor on hover to indicate draggability */
  box-shadow: 0 12px 32px rgba(0, 0, 0, .2) !important;
}
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
`,bt=()=>{const t=document.createElement("style");t.innerHTML=`${wt}`,t.id="cw-widget-styles",t.dataset.turboPermanent=!0,document.body.appendChild(t)},$=(t,e)=>{const o=document.getElementById(t),h=e.querySelector(`#${t}`);o&&!h&&e.appendChild(o)},M=t=>{$("cw-bubble-holder",t),$("cw-widget-holder",t),$("cw-widget-styles",t)},C=(t,e)=>{t.classList.add(...e.split(" "))},_=(t,e)=>{t.classList.toggle(e)},B=(t,e)=>{t.classList.remove(...e.split(" "))},F=({referrerURL:t,referrerHost:e})=>{c.events.onLocationChange({referrerURL:t,referrerHost:e})},gt=()=>{let t=document.location.href;const e=document.location.host,o={childList:!0,subtree:!0};F({referrerURL:t,referrerHost:e});const h=document.querySelector("body");new MutationObserver(i=>{i.forEach(()=>{t!==document.location.href&&(t=document.location.href,F({referrerURL:t,referrerHost:e}))})}).observe(h,o)},L=["standard","expanded_bubble"],H=["standard","flat"],U=["light","auto","dark"],z=t=>L.includes(t)?t:L[0],V=t=>z(t)===L[1],pt=t=>H.includes(t)?t:H[0],O=t=>t==="flat",X=t=>U.includes(t)?t:U[0],mt=({eventName:t,data:e=null})=>{let o;return typeof window.CustomEvent=="function"?o=new CustomEvent(t,{detail:e}):(o=document.createEvent("CustomEvent"),o.initCustomEvent(t,!1,!1,e)),o},T=({eventName:t,data:e})=>{const o=mt({eventName:t,data:e});window.dispatchEvent(o)};class N{constructor(e,o={}){this.bubble=e,this.isDragging=!1,this.dragStarted=!1,this.startX=0,this.startY=0,this.initialX=0,this.initialY=0,this.currentX=0,this.currentY=0,this.lastDragDistance=0,this.options={dragThreshold:5,clickTimeThreshold:150,persistPosition:!0,onPositionChange:null,onDragStart:null,onDragEnd:null,...o},this.clickStartTime=0,this.boundaryPadding=20,this.dragCooldown=!1,this.initializeDragEvents(),this.restoreSavedPosition(),this.setupWindowHandlers()}initializeDragEvents(){this.bubble.addEventListener("touchstart",this.handleTouchStart.bind(this),{passive:!1}),this.bubble.addEventListener("touchmove",this.handleTouchMove.bind(this),{passive:!1}),this.bubble.addEventListener("touchend",this.handleTouchEnd.bind(this),{passive:!1}),this.bubble.addEventListener("mousedown",this.handleMouseDown.bind(this),{passive:!1}),document.addEventListener("mousemove",this.handleMouseMove.bind(this),{passive:!1}),document.addEventListener("mouseup",this.handleMouseUp.bind(this),{passive:!1}),this.bubble.addEventListener("dragstart",e=>e.preventDefault())}handleTouchStart(e){this.startDrag(e.touches[0].clientX,e.touches[0].clientY)}handleMouseDown(e){this.startDrag(e.clientX,e.clientY)}startDrag(e,o){this.isDragging=!0,this.dragStarted=!1,this.clickStartTime=Date.now(),this.startX=e,this.startY=o;const h=this.bubble.getBoundingClientRect();this.initialX=h.left,this.initialY=h.top,this.currentX=this.initialX,this.currentY=this.initialY,this.bubble.classList.add("woot-widget-bubble--dragging"),document.body.style.userSelect="none"}handleTouchMove(e){this.isDragging&&(e.preventDefault(),this.updateDrag(e.touches[0].clientX,e.touches[0].clientY))}handleMouseMove(e){this.isDragging&&(e.preventDefault(),this.updateDrag(e.clientX,e.clientY))}updateDrag(e,o){const h=e-this.startX,d=o-this.startY;this.lastDragDistance=Math.sqrt(h*h+d*d),!this.dragStarted&&this.lastDragDistance>this.options.dragThreshold&&(this.dragStarted=!0,this.bubble.classList.add("woot-widget-bubble--drag-active"),this.bubble.style.transition="none",this.bubble.style.transform="scale(1.12)",setTimeout(()=>{this.bubble.style.transform="scale(1.08) rotate(2deg)"},50),typeof this.options.onDragStart=="function"&&this.options.onDragStart()),this.dragStarted&&(this.currentX=this.initialX+h,this.currentY=this.initialY+d,this.constrainToViewport(),this.applyPosition(),typeof this.options.onPositionChange=="function"&&this.options.onPositionChange(this.currentX,this.currentY))}handleTouchEnd(e){this.endDrag()}handleMouseUp(e){this.endDrag()}endDrag(){this.isDragging&&(this.bubble.classList.remove("woot-widget-bubble--dragging","woot-widget-bubble--drag-active"),document.body.style.userSelect="",this.dragStarted&&(this.saveBubblePosition(),this.bubble.style.transition="transform 0.4s cubic-bezier(0.4, 0.0, 0.2, 1)",this.bubble.style.transform="scale(1) rotate(0deg)",setTimeout(()=>{this.bubble.style.transition="transform 0.3s cubic-bezier(0.4, 0.0, 0.2, 1), box-shadow 0.3s ease"},400),this.dragCooldown=!0,setTimeout(()=>{this.dragCooldown=!1},250)),typeof this.options.onDragEnd=="function"&&this.options.onDragEnd(),this.isDragging=!1,this.dragStarted=!1,this.lastDragDistance=0)}constrainToViewport(){const e={width:window.innerWidth||document.documentElement.clientWidth,height:window.innerHeight||document.documentElement.clientHeight},o=this.bubble.getBoundingClientRect(),h=o.width,d=o.height;this.currentX=Math.max(this.boundaryPadding,Math.min(e.width-h-this.boundaryPadding,this.currentX)),this.currentY=Math.max(this.boundaryPadding,Math.min(e.height-d-this.boundaryPadding,this.currentY))}applyPosition(){this.bubble.style.left=`${this.currentX}px`,this.bubble.style.top=`${this.currentY}px`,this.bubble.style.right="auto",this.bubble.style.bottom="auto",typeof this.options.onPositionChange=="function"&&this.options.onPositionChange(this.currentX,this.currentY)}handleBubbleClick(){this.bubble.classList.contains("woot-widget-drag-handle")||(window.$chatwoot&&typeof window.$chatwoot.toggle=="function"&&window.$chatwoot.toggle(),this.options.onBubbleClick&&this.options.onBubbleClick())}saveBubblePosition(){if(this.options.persistPosition)try{const e={x:this.currentX,y:this.currentY,timestamp:Date.now()};localStorage.setItem("chatwoot_bubble_position",JSON.stringify(e))}catch(e){console.warn("Could not save bubble position:",e)}}restoreSavedPosition(){if(!this.options.persistPosition){this.setDefaultPosition();return}try{const e=localStorage.getItem("chatwoot_bubble_position");if(e){const o=JSON.parse(e),h=7*24*60*60*1e3;if(Date.now()-o.timestamp<h){this.currentX=o.x,this.currentY=o.y,this.constrainToViewport(),this.applyPosition();return}}}catch(e){console.warn("Could not restore bubble position:",e)}this.setDefaultPosition()}setDefaultPosition(){var d;const e={width:window.innerWidth||document.documentElement.clientWidth,height:window.innerHeight||document.documentElement.clientHeight},o=this.bubble.getBoundingClientRect();(((d=window.$chatwoot)==null?void 0:d.position)||"right")==="left"?this.currentX=this.boundaryPadding:this.currentX=e.width-o.width-this.boundaryPadding,this.currentY=e.height-o.height-this.boundaryPadding,this.applyPosition()}setPosition(e,o){this.currentX=e,this.currentY=o,this.constrainToViewport(),this.applyPosition(),this.saveBubblePosition()}resetPosition(){const e={width:window.innerWidth||document.documentElement.clientWidth,height:window.innerHeight||document.documentElement.clientHeight},o=this.bubble.getBoundingClientRect();this.currentX=e.width-o.width-this.boundaryPadding,this.currentY=e.height-o.height-this.boundaryPadding,this.applyPosition(),this.saveBubblePosition()}setupWindowHandlers(){this.handleResize=()=>{this.constrainToViewport(),this.applyPosition()},window.addEventListener("resize",this.handleResize)}destroy(){this.bubble.removeEventListener("touchstart",this.handleTouchStart),this.bubble.removeEventListener("touchmove",this.handleTouchMove),this.bubble.removeEventListener("touchend",this.handleTouchEnd),this.bubble.removeEventListener("mousedown",this.handleMouseDown),document.removeEventListener("mousemove",this.handleMouseMove),document.removeEventListener("mouseup",this.handleMouseUp),window.removeEventListener("resize",this.handleResize)}}const ft="M240.808 240.808H122.123C56.6994 240.808 3.45695 187.562 3.45695 122.122C3.45695 56.7031 56.6994 3.45697 122.124 3.45697C187.566 3.45697 240.808 56.7031 240.808 122.122V240.808Z",q=document.getElementsByTagName("body")[0],x=document.createElement("div"),S=document.createElement("div"),y=document.createElement("button"),v=document.createElement("button");document.createElement("span");const vt=t=>{if(V(window.$chatwoot.type)){const e=document.getElementById("woot-widget--expanded__text");e.innerText=t}},yt=({className:t,path:e,target:o})=>{let h=`${t} woot-elements--${window.$chatwoot.position}`;const d=document.createElementNS("http://www.w3.org/2000/svg","svg");d.setAttributeNS(null,"id","woot-widget-bubble-icon"),d.setAttributeNS(null,"width","24"),d.setAttributeNS(null,"height","24"),d.setAttributeNS(null,"viewBox","0 0 240 240"),d.setAttributeNS(null,"fill","none"),d.setAttribute("xmlns","http://www.w3.org/2000/svg");const i=document.createElementNS("http://www.w3.org/2000/svg","path");if(i.setAttributeNS(null,"d",e),i.setAttributeNS(null,"fill","#FFFFFF"),d.appendChild(i),o.appendChild(d),V(window.$chatwoot.type)){const w=document.createElement("div");w.id="woot-widget--expanded__text",w.innerText="",o.appendChild(w),h+=" woot-widget--expanded"}return o.className=h,o.title="Open chat window",o},xt=t=>{t&&C(S,"woot-hidden"),C(S,"woot--bubble-holder"),S.id="cw-bubble-holder",S.dataset.turboPermanent=!0,q.appendChild(S)},Et=t=>{c.events.onBubbleToggle(t),t?T({eventName:ot}):(T({eventName:it}),y.focus())},D=(t={})=>{const{toggleValue:e}=t,{isOpen:o}=window.$chatwoot;if(o===e)return;const h=e===void 0?!o:e;window.$chatwoot.isOpen=h,_(y,"woot--hide"),_(v,"woot--hide"),_(x,"woot--hide"),Et(h)},Ct=()=>{let t=!1;y&&!y.dragHelper&&(y.dragHelper=new N(y,{dragThreshold:5,clickTimeThreshold:150,persistPosition:!0,onDragStart:()=>{t=!0},onDragEnd:()=>{t=!1},onPositionChange:(e,o)=>{v.style.left=`${e}px`,v.style.top=`${o}px`,v.style.right="auto",v.style.bottom="auto"}})),v&&!v.dragHelper&&(v.dragHelper=new N(v,{dragThreshold:5,clickTimeThreshold:150,persistPosition:!0,onDragStart:()=>{t=!0},onDragEnd:()=>{t=!1},onPositionChange:(e,o)=>{y.style.left=`${e}px`,y.style.top=`${o}px`,y.style.right="auto",y.style.bottom="auto"}})),y.addEventListener("click",e=>{if(t){e.preventDefault(),e.stopPropagation();return}if(y.dragHelper&&y.dragHelper.dragCooldown){e.preventDefault(),e.stopPropagation();return}D()}),v.addEventListener("click",e=>{if(t){e.preventDefault(),e.stopPropagation();return}if(v.dragHelper&&v.dragHelper.dragCooldown){e.preventDefault(),e.stopPropagation();return}D({toggleValue:!1})})},St=()=>{const t=document.querySelector(".woot-widget-holder");C(t,"has-unread-view")},R=()=>{const t=document.querySelector(".woot-widget-holder");B(t,"has-unread-view")};var K={exports:{}},G={exports:{}};(function(){var t="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",e={rotl:function(o,h){return o<<h|o>>>32-h},rotr:function(o,h){return o<<32-h|o>>>h},endian:function(o){if(o.constructor==Number)return e.rotl(o,8)&16711935|e.rotl(o,24)&4278255360;for(var h=0;h<o.length;h++)o[h]=e.endian(o[h]);return o},randomBytes:function(o){for(var h=[];o>0;o--)h.push(Math.floor(Math.random()*256));return h},bytesToWords:function(o){for(var h=[],d=0,i=0;d<o.length;d++,i+=8)h[i>>>5]|=o[d]<<24-i%32;return h},wordsToBytes:function(o){for(var h=[],d=0;d<o.length*32;d+=8)h.push(o[d>>>5]>>>24-d%32&255);return h},bytesToHex:function(o){for(var h=[],d=0;d<o.length;d++)h.push((o[d]>>>4).toString(16)),h.push((o[d]&15).toString(16));return h.join("")},hexToBytes:function(o){for(var h=[],d=0;d<o.length;d+=2)h.push(parseInt(o.substr(d,2),16));return h},bytesToBase64:function(o){for(var h=[],d=0;d<o.length;d+=3)for(var i=o[d]<<16|o[d+1]<<8|o[d+2],w=0;w<4;w++)d*8+w*6<=o.length*8?h.push(t.charAt(i>>>6*(3-w)&63)):h.push("=");return h.join("")},base64ToBytes:function(o){o=o.replace(/[^A-Z0-9+\/]/ig,"");for(var h=[],d=0,i=0;d<o.length;i=++d%4)i!=0&&h.push((t.indexOf(o.charAt(d-1))&Math.pow(2,-2*i+8)-1)<<i*2|t.indexOf(o.charAt(d))>>>6-i*2);return h}};G.exports=e})();var Tt=G.exports,P={utf8:{stringToBytes:function(t){return P.bin.stringToBytes(unescape(encodeURIComponent(t)))},bytesToString:function(t){return decodeURIComponent(escape(P.bin.bytesToString(t)))}},bin:{stringToBytes:function(t){for(var e=[],o=0;o<t.length;o++)e.push(t.charCodeAt(o)&255);return e},bytesToString:function(t){for(var e=[],o=0;o<t.length;o++)e.push(String.fromCharCode(t[o]));return e.join("")}}},W=P;/*!
 * Determine if an object is a Buffer
 *
 * @author   Feross Aboukhadijeh <https://feross.org>
 * @license  MIT
 */var Dt=function(t){return t!=null&&(J(t)||Bt(t)||!!t._isBuffer)};function J(t){return!!t.constructor&&typeof t.constructor.isBuffer=="function"&&t.constructor.isBuffer(t)}function Bt(t){return typeof t.readFloatLE=="function"&&typeof t.slice=="function"&&J(t.slice(0,0))}(function(){var t=Tt,e=W.utf8,o=Dt,h=W.bin,d=function(i,w){i.constructor==String?w&&w.encoding==="binary"?i=h.stringToBytes(i):i=e.stringToBytes(i):o(i)?i=Array.prototype.slice.call(i,0):!Array.isArray(i)&&i.constructor!==Uint8Array&&(i=i.toString());for(var a=t.bytesToWords(i),b=i.length*8,n=1732584193,s=-271733879,l=-1732584194,r=271733878,u=0;u<a.length;u++)a[u]=(a[u]<<8|a[u]>>>24)&16711935|(a[u]<<24|a[u]>>>8)&4278255360;a[b>>>5]|=128<<b%32,a[(b+64>>>9<<4)+14]=b;for(var g=d._ff,p=d._gg,m=d._hh,f=d._ii,u=0;u<a.length;u+=16){var Q=n,j=s,tt=l,et=r;n=g(n,s,l,r,a[u+0],7,-680876936),r=g(r,n,s,l,a[u+1],12,-389564586),l=g(l,r,n,s,a[u+2],17,606105819),s=g(s,l,r,n,a[u+3],22,-1044525330),n=g(n,s,l,r,a[u+4],7,-176418897),r=g(r,n,s,l,a[u+5],12,1200080426),l=g(l,r,n,s,a[u+6],17,-1473231341),s=g(s,l,r,n,a[u+7],22,-45705983),n=g(n,s,l,r,a[u+8],7,1770035416),r=g(r,n,s,l,a[u+9],12,-1958414417),l=g(l,r,n,s,a[u+10],17,-42063),s=g(s,l,r,n,a[u+11],22,-1990404162),n=g(n,s,l,r,a[u+12],7,1804603682),r=g(r,n,s,l,a[u+13],12,-40341101),l=g(l,r,n,s,a[u+14],17,-1502002290),s=g(s,l,r,n,a[u+15],22,1236535329),n=p(n,s,l,r,a[u+1],5,-165796510),r=p(r,n,s,l,a[u+6],9,-1069501632),l=p(l,r,n,s,a[u+11],14,643717713),s=p(s,l,r,n,a[u+0],20,-373897302),n=p(n,s,l,r,a[u+5],5,-701558691),r=p(r,n,s,l,a[u+10],9,38016083),l=p(l,r,n,s,a[u+15],14,-660478335),s=p(s,l,r,n,a[u+4],20,-405537848),n=p(n,s,l,r,a[u+9],5,568446438),r=p(r,n,s,l,a[u+14],9,-1019803690),l=p(l,r,n,s,a[u+3],14,-187363961),s=p(s,l,r,n,a[u+8],20,1163531501),n=p(n,s,l,r,a[u+13],5,-1444681467),r=p(r,n,s,l,a[u+2],9,-51403784),l=p(l,r,n,s,a[u+7],14,1735328473),s=p(s,l,r,n,a[u+12],20,-1926607734),n=m(n,s,l,r,a[u+5],4,-378558),r=m(r,n,s,l,a[u+8],11,-2022574463),l=m(l,r,n,s,a[u+11],16,1839030562),s=m(s,l,r,n,a[u+14],23,-35309556),n=m(n,s,l,r,a[u+1],4,-1530992060),r=m(r,n,s,l,a[u+4],11,1272893353),l=m(l,r,n,s,a[u+7],16,-155497632),s=m(s,l,r,n,a[u+10],23,-1094730640),n=m(n,s,l,r,a[u+13],4,681279174),r=m(r,n,s,l,a[u+0],11,-358537222),l=m(l,r,n,s,a[u+3],16,-722521979),s=m(s,l,r,n,a[u+6],23,76029189),n=m(n,s,l,r,a[u+9],4,-640364487),r=m(r,n,s,l,a[u+12],11,-421815835),l=m(l,r,n,s,a[u+15],16,530742520),s=m(s,l,r,n,a[u+2],23,-995338651),n=f(n,s,l,r,a[u+0],6,-198630844),r=f(r,n,s,l,a[u+7],10,1126891415),l=f(l,r,n,s,a[u+14],15,-1416354905),s=f(s,l,r,n,a[u+5],21,-57434055),n=f(n,s,l,r,a[u+12],6,1700485571),r=f(r,n,s,l,a[u+3],10,-1894986606),l=f(l,r,n,s,a[u+10],15,-1051523),s=f(s,l,r,n,a[u+1],21,-2054922799),n=f(n,s,l,r,a[u+8],6,1873313359),r=f(r,n,s,l,a[u+15],10,-30611744),l=f(l,r,n,s,a[u+6],15,-1560198380),s=f(s,l,r,n,a[u+13],21,1309151649),n=f(n,s,l,r,a[u+4],6,-145523070),r=f(r,n,s,l,a[u+11],10,-1120210379),l=f(l,r,n,s,a[u+2],15,718787259),s=f(s,l,r,n,a[u+9],21,-343485551),n=n+Q>>>0,s=s+j>>>0,l=l+tt>>>0,r=r+et>>>0}return t.endian([n,s,l,r])};d._ff=function(i,w,a,b,n,s,l){var r=i+(w&a|~w&b)+(n>>>0)+l;return(r<<s|r>>>32-s)+w},d._gg=function(i,w,a,b,n,s,l){var r=i+(w&b|a&~b)+(n>>>0)+l;return(r<<s|r>>>32-s)+w},d._hh=function(i,w,a,b,n,s,l){var r=i+(w^a^b)+(n>>>0)+l;return(r<<s|r>>>32-s)+w},d._ii=function(i,w,a,b,n,s,l){var r=i+(a^(w|~b))+(n>>>0)+l;return(r<<s|r>>>32-s)+w},d._blocksize=16,d._digestsize=16,K.exports=function(i,w){if(i==null)throw new Error("Illegal argument "+i);var a=t.wordsToBytes(d(i,w));return w&&w.asBytes?a:w&&w.asString?h.bytesToString(a):t.bytesToHex(a)}})();var $t=K.exports;const Mt=ct($t),Z=["avatar_url","email","name"],_t=[...Z,"identifier_hash"],A=()=>{const t="cw_user_",{websiteToken:e}=window.$chatwoot;return`${t}${e}`},Lt=({identifier:t="",user:e})=>`${_t.reduce((h,d)=>`${h}${d}${e[d]||""}`,"")}identifier${t}`,Pt=(...t)=>Mt(Lt(...t)),At=t=>Z.reduce((e,o)=>e||!!t[o],!1),k=(t,e,{expires:o=365,baseDomain:h=void 0}={})=>{const d={expires:o,sameSite:"Lax",domain:h};typeof e=="object"&&(e=JSON.stringify(e)),E.set(t,e,d)},I=["click","touchstart","keypress","keydown"],kt=()=>{let t;try{t=new(window.AudioContext||window.webkitAudioContext)}catch{}return t},Ft=async(t="",e)=>{const o=kt(),h=d=>{window.playAudioAlert=()=>{if(o){const i=o.createBufferSource();i.buffer=d,i.connect(o.destination),i.loop=!1,i.start()}}};if(o){const{type:d="dashboard",alertTone:i="ding"}=e||{},w=`${t}/audio/${d}/${i}.mp3`,a=new Request(w);fetch(a).then(b=>b.arrayBuffer()).then(b=>(o.decodeAudioData(b).then(h),new Promise(n=>n()))).catch(()=>{})}},Y=(t,e="")=>k("cw_conversation",t,{baseDomain:e}),Ht=t=>{const e=rt(new Date,1);k("cw_snooze_campaigns_till",Number(e),{expires:e,baseDomain:t})},c={getUrl({baseUrl:t,websiteToken:e}){return`${t}/widget?website_token=${e}`},createFrame:({baseUrl:t,websiteToken:e})=>{if(c.getAppFrame())return;bt();const o=document.createElement("iframe"),h=E.get("cw_conversation");let d=c.getUrl({baseUrl:t,websiteToken:e});h&&(d=`${d}&cw_conversation=${h}`),o.src=d,o.allow="camera;microphone;fullscreen;display-capture;picture-in-picture;clipboard-write;",o.id="chatwoot_live_chat_widget",o.style.visibility="hidden";let i=`woot-widget-holder woot--hide woot-elements--${window.$chatwoot.position}`;window.$chatwoot.hideMessageBubble&&(i+=" woot-widget--without-bubble"),O(window.$chatwoot.widgetStyle)&&(i+=" woot-widget-holder--flat"),C(x,i),x.id="cw-widget-holder",x.dataset.turboPermanent=!0,x.appendChild(o),q.appendChild(x),c.initPostMessageCommunication(),c.initWindowSizeListener(),c.preventDefaultScroll()},getAppFrame:()=>document.getElementById("chatwoot_live_chat_widget"),getBubbleHolder:()=>document.getElementsByClassName("woot--bubble-holder"),sendMessage:(t,e)=>{c.getAppFrame().contentWindow.postMessage(`chatwoot-widget:${JSON.stringify({event:t,...e})}`,"*")},initPostMessageCommunication:()=>{window.onmessage=t=>{if(typeof t.data!="string"||t.data.indexOf("chatwoot-widget:")!==0)return;const e=JSON.parse(t.data.replace("chatwoot-widget:",""));typeof c.events[e.event]=="function"&&c.events[e.event](e)}},initWindowSizeListener:()=>{window.addEventListener("resize",()=>c.toggleCloseButton())},preventDefaultScroll:()=>{x.addEventListener("wheel",t=>{const e=t.deltaY,o=x.scrollHeight,h=x.offsetHeight,d=x.scrollTop;(d===0&&e<0||h+d===o&&e>0)&&t.preventDefault()})},setFrameHeightToFitContent:(t,e)=>{const o=c.getAppFrame(),h=e?`${t}px`:"100%";o&&o.setAttribute("style",`height: ${h} !important`)},setupAudioListeners:()=>{const{baseUrl:t=""}=window.$chatwoot;Ft(t,{type:"widget",alertTone:"ding"}).then(()=>I.forEach(e=>{document.removeEventListener(e,c.setupAudioListeners,!1)}))},events:{loaded:t=>{Y(t.config.authToken,window.$chatwoot.baseDomain),window.$chatwoot.hasLoaded=!0;const e=E.get("cw_snooze_campaigns_till");c.sendMessage("config-set",{locale:window.$chatwoot.locale,position:window.$chatwoot.position,hideMessageBubble:window.$chatwoot.hideMessageBubble,showPopoutButton:window.$chatwoot.showPopoutButton,widgetStyle:window.$chatwoot.widgetStyle,darkMode:window.$chatwoot.darkMode,showUnreadMessagesDialog:window.$chatwoot.showUnreadMessagesDialog,campaignsSnoozedTill:e}),c.onLoad({widgetColor:t.config.channelConfig.widgetColor}),c.toggleCloseButton(),window.$chatwoot.user&&c.sendMessage("set-user",window.$chatwoot.user),window.playAudioAlert=()=>{},I.forEach(o=>{document.addEventListener(o,c.setupAudioListeners,!1)}),window.$chatwoot.resetTriggered||T({eventName:dt})},error:({errorType:t,data:e})=>{T({eventName:lt,data:e}),t===st&&E.remove(A())},onEvent({eventIdentifier:t,data:e}){T({eventName:t,data:e})},setBubbleLabel(t){vt(window.$chatwoot.launcherTitle||t.label)},setAuthCookie({data:{widgetAuthToken:t}}){Y(t,window.$chatwoot.baseDomain)},setCampaignReadOn(){Ht(window.$chatwoot.baseDomain)},postback(t){T({eventName:at,data:t})},toggleBubble:t=>{let e={};t==="open"?e.toggleValue=!0:t==="close"&&(e.toggleValue=!1),D(e)},popoutChatWindow:({baseUrl:t,websiteToken:e,locale:o})=>{const h=E.get("cw_conversation");window.$chatwoot.toggle("close"),nt(t,e,o,h)},closeWindow:()=>{D({toggleValue:!1}),R()},onBubbleToggle:t=>{c.sendMessage("toggle-open",{isOpen:t}),t&&c.pushEvent("webwidget.triggered")},onLocationChange:({referrerURL:t,referrerHost:e})=>{c.sendMessage("change-url",{referrerURL:t,referrerHost:e})},updateIframeHeight:t=>{const{extraHeight:e=0,isFixedHeight:o}=t;c.setFrameHeightToFitContent(e,o)},setUnreadMode:()=>{St(),D({toggleValue:!0})},resetUnreadMode:()=>R(),handleNotificationDot:t=>{if(window.$chatwoot.hideMessageBubble)return;const e=document.querySelector(".woot-widget-bubble");t.unreadMessageCount>0&&!e.classList.contains("unread-notification")?C(e,"unread-notification"):t.unreadMessageCount===0&&B(e,"unread-notification")},closeChat:()=>{D({toggleValue:!1})},playAudio:()=>{window.playAudioAlert()}},pushEvent:t=>{c.sendMessage("push-event",{eventName:t})},onLoad:({widgetColor:t})=>{const e=c.getAppFrame();if(e.style.visibility="",e.setAttribute("id","chatwoot_live_chat_widget"),c.getBubbleHolder().length)return;xt(window.$chatwoot.hideMessageBubble),gt();let o="woot-widget-bubble",h=`woot-elements--${window.$chatwoot.position} woot-widget-bubble woot--close woot--hide`;O(window.$chatwoot.widgetStyle)&&(o+=" woot-widget-bubble--flat",h+=" woot-widget-bubble--flat"),ut(t)&&(o+=" woot-widget-bubble-color--lighter",h+=" woot-widget-bubble-color--lighter");const d=yt({className:o,path:ft,target:y});C(v,h),d.style.background=t,v.style.background=t,S.appendChild(d),S.appendChild(v),Ct()},toggleCloseButton:()=>{let t=!1;window.matchMedia("(max-width: 668px)").matches&&(t=!0),c.sendMessage("toggle-close-button",{isMobile:t})}},Ut=({baseUrl:t,websiteToken:e})=>{if(window.$chatwoot)return;document.addEventListener("turbo:before-render",i=>{i.detail.renderMethod!=="morph"&&M(i.detail.newBody)}),window.Turbolinks&&document.addEventListener("turbolinks:before-render",i=>{M(i.data.newBody)}),document.addEventListener("astro:before-swap",i=>M(i.newDocument.body));const o=window.chatwootSettings||{};let h=o.locale,d=o.baseDomain;o.useBrowserLanguage&&(h=window.navigator.language.replace("-","_")),window.$chatwoot={baseUrl:t,baseDomain:d,hasLoaded:!1,hideMessageBubble:o.hideMessageBubble||!1,isOpen:!1,position:o.position==="left"?"left":"right",websiteToken:e,locale:h,useBrowserLanguage:o.useBrowserLanguage||!1,type:z(o.type),launcherTitle:o.launcherTitle||"",showPopoutButton:o.showPopoutButton||!1,showUnreadMessagesDialog:o.showUnreadMessagesDialog??!0,widgetStyle:pt(o.widgetStyle)||"standard",resetTriggered:!1,darkMode:X(o.darkMode),toggle(i){c.events.toggleBubble(i)},toggleBubbleVisibility(i){let w=document.querySelector(".woot--bubble-holder"),a=document.querySelector(".woot-widget-holder");i==="hide"?(C(a,"woot-widget--without-bubble"),C(w,"woot-hidden"),window.$chatwoot.hideMessageBubble=!0):i==="show"&&(B(w,"woot-hidden"),B(a,"woot-widget--without-bubble"),window.$chatwoot.hideMessageBubble=!1),c.sendMessage(ht,{hideMessageBubble:window.$chatwoot.hideMessageBubble})},popoutChatWindow(){c.events.popoutChatWindow({baseUrl:window.$chatwoot.baseUrl,websiteToken:window.$chatwoot.websiteToken,locale:h})},setUser(i,w){if(typeof i!="string"&&typeof i!="number")throw new Error("Identifier should be a string or a number");if(!At(w))throw new Error("User object should have one of the keys [avatar_url, email, name]");const a=A(),b=E.get(a),n=Pt({identifier:i,user:w});n!==b&&(window.$chatwoot.identifier=i,window.$chatwoot.user=w,c.sendMessage("set-user",{identifier:i,user:w}),k(a,n,{baseDomain:d}))},setCustomAttributes(i={}){if(!i||!Object.keys(i).length)throw new Error("Custom attributes should have atleast one key");c.sendMessage("set-custom-attributes",{customAttributes:i})},deleteCustomAttribute(i=""){if(i)c.sendMessage("delete-custom-attribute",{customAttribute:i});else throw new Error("Custom attribute is required")},setConversationCustomAttributes(i={}){if(!i||!Object.keys(i).length)throw new Error("Custom attributes should have atleast one key");c.sendMessage("set-conversation-custom-attributes",{customAttributes:i})},deleteConversationCustomAttribute(i=""){if(i)c.sendMessage("delete-conversation-custom-attribute",{customAttribute:i});else throw new Error("Custom attribute is required")},setLabel(i=""){c.sendMessage("set-label",{label:i})},removeLabel(i=""){c.sendMessage("remove-label",{label:i})},setLocale(i="en"){c.sendMessage("set-locale",{locale:i})},setColorScheme(i="light"){c.sendMessage("set-color-scheme",{darkMode:X(i)})},reset(){window.$chatwoot.isOpen&&c.events.toggleBubble(),E.remove("cw_conversation"),E.remove(A());const i=c.getAppFrame();i.src=c.getUrl({baseUrl:window.$chatwoot.baseUrl,websiteToken:window.$chatwoot.websiteToken}),window.$chatwoot.resetTriggered=!0}},c.createFrame({baseUrl:t,websiteToken:e})};window.chatwootSDK={run:Ut};
