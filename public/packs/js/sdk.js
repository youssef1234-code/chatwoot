(function(){"use strict";/*! js-cookie v3.0.5 | MIT */function B(t){for(var e=1;e<arguments.length;e++){var o=arguments[e];for(var d in o)t[d]=o[d]}return t}var ot={read:function(t){return t[0]==='"'&&(t=t.slice(1,-1)),t.replace(/(%[\dA-F]{2})+/gi,decodeURIComponent)},write:function(t){return encodeURIComponent(t).replace(/%(2[346BF]|3[AC-F]|40|5[BDE]|60|7[BCD])/g,decodeURIComponent)}};function M(t,e){function o(n,i,h){if(!(typeof document>"u")){h=B({},e,h),typeof h.expires=="number"&&(h.expires=new Date(Date.now()+h.expires*864e5)),h.expires&&(h.expires=h.expires.toUTCString()),n=encodeURIComponent(n).replace(/%(2[346B]|5E|60|7C)/g,decodeURIComponent).replace(/[()]/g,escape);var s="";for(var b in h)h[b]&&(s+="; "+b,h[b]!==!0&&(s+="="+h[b].split(";")[0]));return document.cookie=n+"="+t.write(i,n)+s}}function d(n){if(!(typeof document>"u"||arguments.length&&!n)){for(var i=document.cookie?document.cookie.split("; "):[],h={},s=0;s<i.length;s++){var b=i[s].split("="),a=b.slice(1).join("=");try{var r=decodeURIComponent(b[0]);if(h[r]=t.read(a,r),n===r)break}catch{}}return n?h[n]:h}}return Object.create({set:o,get:d,remove:function(n,i){o(n,"",B({},i,{expires:-1}))},withAttributes:function(n){return M(this.converter,B({},this.attributes,n))},withConverter:function(n){return M(B({},this.converter,n),this.attributes)}},{attributes:{value:Object.freeze(e)},converter:{value:Object.freeze(t)}})}var C=M(ot,{path:"/"});const nt=`
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
`,it=()=>{const t=document.createElement("style");t.innerHTML=`${nt}`,t.id="cw-widget-styles",t.dataset.turboPermanent=!0,document.body.appendChild(t)},$=(t,e)=>{const o=document.getElementById(t),d=e.querySelector(`#${t}`);o&&!d&&e.appendChild(o)},L=t=>{$("cw-bubble-holder",t),$("cw-widget-holder",t),$("cw-widget-styles",t)},E=(t,e)=>{t.classList.add(...e.split(" "))},P=(t,e)=>{t.classList.toggle(e)},_=(t,e)=>{t.classList.remove(...e.split(" "))},O=({referrerURL:t,referrerHost:e})=>{w.events.onLocationChange({referrerURL:t,referrerHost:e})},st=()=>{let t=document.location.href;const e=document.location.host,o={childList:!0,subtree:!0};O({referrerURL:t,referrerHost:e});const d=document.querySelector("body");new MutationObserver(i=>{i.forEach(()=>{t!==document.location.href&&(t=document.location.href,O({referrerURL:t,referrerHost:e}))})}).observe(d,o)},k=["standard","expanded_bubble"],R=["standard","flat"],I=["light","auto","dark"],N=t=>k.includes(t)?t:k[0],X=t=>N(t)===k[1],rt=t=>R.includes(t)?t:R[0],W=t=>t==="flat",Y=t=>I.includes(t)?t:I[0],at="chatwoot:error",lt="chatwoot:postback",dt="chatwoot:ready",ct="chatwoot:opened",ut="chatwoot:closed",ht=({eventName:t,data:e=null})=>{let o;return typeof window.CustomEvent=="function"?o=new CustomEvent(t,{detail:e}):(o=document.createEvent("CustomEvent"),o.initCustomEvent(t,!1,!1,e)),o},D=({eventName:t,data:e})=>{const o=ht({eventName:t,data:e});window.dispatchEvent(o)};class z{constructor(e,o={}){this.bubble=e,this.isDragging=!1,this.dragStarted=!1,this.startX=0,this.startY=0,this.initialX=0,this.initialY=0,this.currentX=0,this.currentY=0,this.lastDragDistance=0,this.options={dragThreshold:5,clickTimeThreshold:150,persistPosition:!0,onPositionChange:null,onDragStart:null,onDragEnd:null,...o},this.clickStartTime=0,this.boundaryPadding=20,this.dragCooldown=!1,this.initializeDragEvents(),this.restoreSavedPosition(),this.setupWindowHandlers()}initializeDragEvents(){this.bubble.addEventListener("touchstart",this.handleTouchStart.bind(this),{passive:!1}),this.bubble.addEventListener("touchmove",this.handleTouchMove.bind(this),{passive:!1}),this.bubble.addEventListener("touchend",this.handleTouchEnd.bind(this),{passive:!1}),this.bubble.addEventListener("mousedown",this.handleMouseDown.bind(this),{passive:!1}),document.addEventListener("mousemove",this.handleMouseMove.bind(this),{passive:!1}),document.addEventListener("mouseup",this.handleMouseUp.bind(this),{passive:!1}),this.bubble.addEventListener("dragstart",e=>e.preventDefault())}handleTouchStart(e){this.startDrag(e.touches[0].clientX,e.touches[0].clientY)}handleMouseDown(e){this.startDrag(e.clientX,e.clientY)}startDrag(e,o){this.isDragging=!0,this.dragStarted=!1,this.clickStartTime=Date.now(),this.startX=e,this.startY=o;const d=this.bubble.getBoundingClientRect();this.initialX=d.left,this.initialY=d.top,this.currentX=this.initialX,this.currentY=this.initialY,this.bubble.classList.add("woot-widget-bubble--dragging"),document.body.style.userSelect="none"}handleTouchMove(e){this.isDragging&&(e.preventDefault(),this.updateDrag(e.touches[0].clientX,e.touches[0].clientY))}handleMouseMove(e){this.isDragging&&(e.preventDefault(),this.updateDrag(e.clientX,e.clientY))}updateDrag(e,o){const d=e-this.startX,n=o-this.startY;this.lastDragDistance=Math.sqrt(d*d+n*n),!this.dragStarted&&this.lastDragDistance>this.options.dragThreshold&&(this.dragStarted=!0,this.bubble.classList.add("woot-widget-bubble--drag-active"),this.bubble.style.transition="none",this.bubble.style.transform="scale(1.12)",setTimeout(()=>{this.bubble.style.transform="scale(1.08) rotate(2deg)"},50),typeof this.options.onDragStart=="function"&&this.options.onDragStart()),this.dragStarted&&(this.currentX=this.initialX+d,this.currentY=this.initialY+n,this.constrainToViewport(),this.applyPosition(),typeof this.options.onPositionChange=="function"&&this.options.onPositionChange(this.currentX,this.currentY))}handleTouchEnd(e){this.endDrag()}handleMouseUp(e){this.endDrag()}endDrag(){this.isDragging&&(this.bubble.classList.remove("woot-widget-bubble--dragging","woot-widget-bubble--drag-active"),document.body.style.userSelect="",this.dragStarted&&(this.saveBubblePosition(),this.bubble.style.transition="transform 0.4s cubic-bezier(0.4, 0.0, 0.2, 1)",this.bubble.style.transform="scale(1) rotate(0deg)",setTimeout(()=>{this.bubble.style.transition="transform 0.3s cubic-bezier(0.4, 0.0, 0.2, 1), box-shadow 0.3s ease"},400),this.dragCooldown=!0,setTimeout(()=>{this.dragCooldown=!1},250)),typeof this.options.onDragEnd=="function"&&this.options.onDragEnd(),this.isDragging=!1,this.dragStarted=!1,this.lastDragDistance=0)}constrainToViewport(){const e={width:window.innerWidth||document.documentElement.clientWidth,height:window.innerHeight||document.documentElement.clientHeight},o=this.bubble.getBoundingClientRect(),d=o.width,n=o.height;this.currentX=Math.max(this.boundaryPadding,Math.min(e.width-d-this.boundaryPadding,this.currentX)),this.currentY=Math.max(this.boundaryPadding,Math.min(e.height-n-this.boundaryPadding,this.currentY))}applyPosition(){this.bubble.style.left=`${this.currentX}px`,this.bubble.style.top=`${this.currentY}px`,this.bubble.style.right="auto",this.bubble.style.bottom="auto",typeof this.options.onPositionChange=="function"&&this.options.onPositionChange(this.currentX,this.currentY)}handleBubbleClick(){this.bubble.classList.contains("woot-widget-drag-handle")||(window.$chatwoot&&typeof window.$chatwoot.toggle=="function"&&window.$chatwoot.toggle(),this.options.onBubbleClick&&this.options.onBubbleClick())}saveBubblePosition(){if(this.options.persistPosition)try{const e={x:this.currentX,y:this.currentY,timestamp:Date.now()};localStorage.setItem("chatwoot_bubble_position",JSON.stringify(e))}catch(e){console.warn("Could not save bubble position:",e)}}restoreSavedPosition(){if(!this.options.persistPosition){this.setDefaultPosition();return}try{const e=localStorage.getItem("chatwoot_bubble_position");if(e){const o=JSON.parse(e),d=7*24*60*60*1e3;if(Date.now()-o.timestamp<d){this.currentX=o.x,this.currentY=o.y,this.constrainToViewport(),this.applyPosition();return}}}catch(e){console.warn("Could not restore bubble position:",e)}this.setDefaultPosition()}setDefaultPosition(){var n;const e={width:window.innerWidth||document.documentElement.clientWidth,height:window.innerHeight||document.documentElement.clientHeight},o=this.bubble.getBoundingClientRect();(((n=window.$chatwoot)==null?void 0:n.position)||"right")==="left"?this.currentX=this.boundaryPadding:this.currentX=e.width-o.width-this.boundaryPadding,this.currentY=e.height-o.height-this.boundaryPadding,this.applyPosition()}setPosition(e,o){this.currentX=e,this.currentY=o,this.constrainToViewport(),this.applyPosition(),this.saveBubblePosition()}resetPosition(){const e={width:window.innerWidth||document.documentElement.clientWidth,height:window.innerHeight||document.documentElement.clientHeight},o=this.bubble.getBoundingClientRect();this.currentX=e.width-o.width-this.boundaryPadding,this.currentY=e.height-o.height-this.boundaryPadding,this.applyPosition(),this.saveBubblePosition()}setupWindowHandlers(){this.handleResize=()=>{this.constrainToViewport(),this.applyPosition()},window.addEventListener("resize",this.handleResize)}destroy(){this.bubble.removeEventListener("touchstart",this.handleTouchStart),this.bubble.removeEventListener("touchmove",this.handleTouchMove),this.bubble.removeEventListener("touchend",this.handleTouchEnd),this.bubble.removeEventListener("mousedown",this.handleMouseDown),document.removeEventListener("mousemove",this.handleMouseMove),document.removeEventListener("mouseup",this.handleMouseUp),window.removeEventListener("resize",this.handleResize)}}const wt="M240.808 240.808H122.123C56.6994 240.808 3.45695 187.562 3.45695 122.122C3.45695 56.7031 56.6994 3.45697 122.124 3.45697C187.566 3.45697 240.808 56.7031 240.808 122.122V240.808Z",V=document.getElementsByTagName("body")[0],x=document.createElement("div"),S=document.createElement("div"),y=document.createElement("button"),v=document.createElement("button");document.createElement("span");const bt=t=>{if(X(window.$chatwoot.type)){const e=document.getElementById("woot-widget--expanded__text");e.innerText=t}},gt=({className:t,path:e,target:o})=>{let d=`${t} woot-elements--${window.$chatwoot.position}`;const n=document.createElementNS("http://www.w3.org/2000/svg","svg");n.setAttributeNS(null,"id","woot-widget-bubble-icon"),n.setAttributeNS(null,"width","24"),n.setAttributeNS(null,"height","24"),n.setAttributeNS(null,"viewBox","0 0 240 240"),n.setAttributeNS(null,"fill","none"),n.setAttribute("xmlns","http://www.w3.org/2000/svg");const i=document.createElementNS("http://www.w3.org/2000/svg","path");if(i.setAttributeNS(null,"d",e),i.setAttributeNS(null,"fill","#FFFFFF"),n.appendChild(i),o.appendChild(n),X(window.$chatwoot.type)){const h=document.createElement("div");h.id="woot-widget--expanded__text",h.innerText="",o.appendChild(h),d+=" woot-widget--expanded"}return o.className=d,o.title="Open chat window",o},pt=t=>{t&&E(S,"woot-hidden"),E(S,"woot--bubble-holder"),S.id="cw-bubble-holder",S.dataset.turboPermanent=!0,V.appendChild(S)},ft=t=>{w.events.onBubbleToggle(t),t?D({eventName:ct}):(D({eventName:ut}),y.focus())},T=(t={})=>{const{toggleValue:e}=t,{isOpen:o}=window.$chatwoot;if(o===e)return;const d=e===void 0?!o:e;window.$chatwoot.isOpen=d,P(y,"woot--hide"),P(v,"woot--hide"),P(x,"woot--hide"),ft(d)},mt=()=>{let t=!1;y&&!y.dragHelper&&(y.dragHelper=new z(y,{dragThreshold:5,clickTimeThreshold:150,persistPosition:!0,onDragStart:()=>{t=!0},onDragEnd:()=>{t=!1},onPositionChange:(e,o)=>{v.style.left=`${e}px`,v.style.top=`${o}px`,v.style.right="auto",v.style.bottom="auto"}})),v&&!v.dragHelper&&(v.dragHelper=new z(v,{dragThreshold:5,clickTimeThreshold:150,persistPosition:!0,onDragStart:()=>{t=!0},onDragEnd:()=>{t=!1},onPositionChange:(e,o)=>{y.style.left=`${e}px`,y.style.top=`${o}px`,y.style.right="auto",y.style.bottom="auto"}})),y.addEventListener("click",e=>{if(t){e.preventDefault(),e.stopPropagation();return}if(y.dragHelper&&y.dragHelper.dragCooldown){e.preventDefault(),e.stopPropagation();return}T()}),v.addEventListener("click",e=>{if(t){e.preventDefault(),e.stopPropagation();return}if(v.dragHelper&&v.dragHelper.dragCooldown){e.preventDefault(),e.stopPropagation();return}T({toggleValue:!1})})},vt=()=>{const t=document.querySelector(".woot-widget-holder");E(t,"has-unread-view")},q=()=>{const t=document.querySelector(".woot-widget-holder");_(t,"has-unread-view")},yt=t=>{const e=t.replace("#",""),o=parseInt(e.substr(0,2),16),d=parseInt(e.substr(2,2),16),n=parseInt(e.substr(4,2),16);return(o*299+d*587+n*114)/1e3>225},xt="SET_USER_ERROR";function Ct(t){return t&&t.__esModule&&Object.prototype.hasOwnProperty.call(t,"default")?t.default:t}var K={exports:{}},j={exports:{}};(function(){var t="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/",e={rotl:function(o,d){return o<<d|o>>>32-d},rotr:function(o,d){return o<<32-d|o>>>d},endian:function(o){if(o.constructor==Number)return e.rotl(o,8)&16711935|e.rotl(o,24)&4278255360;for(var d=0;d<o.length;d++)o[d]=e.endian(o[d]);return o},randomBytes:function(o){for(var d=[];o>0;o--)d.push(Math.floor(Math.random()*256));return d},bytesToWords:function(o){for(var d=[],n=0,i=0;n<o.length;n++,i+=8)d[i>>>5]|=o[n]<<24-i%32;return d},wordsToBytes:function(o){for(var d=[],n=0;n<o.length*32;n+=8)d.push(o[n>>>5]>>>24-n%32&255);return d},bytesToHex:function(o){for(var d=[],n=0;n<o.length;n++)d.push((o[n]>>>4).toString(16)),d.push((o[n]&15).toString(16));return d.join("")},hexToBytes:function(o){for(var d=[],n=0;n<o.length;n+=2)d.push(parseInt(o.substr(n,2),16));return d},bytesToBase64:function(o){for(var d=[],n=0;n<o.length;n+=3)for(var i=o[n]<<16|o[n+1]<<8|o[n+2],h=0;h<4;h++)n*8+h*6<=o.length*8?d.push(t.charAt(i>>>6*(3-h)&63)):d.push("=");return d.join("")},base64ToBytes:function(o){o=o.replace(/[^A-Z0-9+\/]/ig,"");for(var d=[],n=0,i=0;n<o.length;i=++n%4)i!=0&&d.push((t.indexOf(o.charAt(n-1))&Math.pow(2,-2*i+8)-1)<<i*2|t.indexOf(o.charAt(n))>>>6-i*2);return d}};j.exports=e})();var Et=j.exports,A={utf8:{stringToBytes:function(t){return A.bin.stringToBytes(unescape(encodeURIComponent(t)))},bytesToString:function(t){return decodeURIComponent(escape(A.bin.bytesToString(t)))}},bin:{stringToBytes:function(t){for(var e=[],o=0;o<t.length;o++)e.push(t.charCodeAt(o)&255);return e},bytesToString:function(t){for(var e=[],o=0;o<t.length;o++)e.push(String.fromCharCode(t[o]));return e.join("")}}},G=A;/*!
 * Determine if an object is a Buffer
 *
 * @author   Feross Aboukhadijeh <https://feross.org>
 * @license  MIT
 */var St=function(t){return t!=null&&(J(t)||Dt(t)||!!t._isBuffer)};function J(t){return!!t.constructor&&typeof t.constructor.isBuffer=="function"&&t.constructor.isBuffer(t)}function Dt(t){return typeof t.readFloatLE=="function"&&typeof t.slice=="function"&&J(t.slice(0,0))}(function(){var t=Et,e=G.utf8,o=St,d=G.bin,n=function(i,h){i.constructor==String?h&&h.encoding==="binary"?i=d.stringToBytes(i):i=e.stringToBytes(i):o(i)?i=Array.prototype.slice.call(i,0):!Array.isArray(i)&&i.constructor!==Uint8Array&&(i=i.toString());for(var s=t.bytesToWords(i),b=i.length*8,a=1732584193,r=-271733879,c=-1732584194,l=271733878,u=0;u<s.length;u++)s[u]=(s[u]<<8|s[u]>>>24)&16711935|(s[u]<<24|s[u]>>>8)&4278255360;s[b>>>5]|=128<<b%32,s[(b+64>>>9<<4)+14]=b;for(var g=n._ff,p=n._gg,f=n._hh,m=n._ii,u=0;u<s.length;u+=16){var Wt=a,Yt=r,zt=c,Vt=l;a=g(a,r,c,l,s[u+0],7,-680876936),l=g(l,a,r,c,s[u+1],12,-389564586),c=g(c,l,a,r,s[u+2],17,606105819),r=g(r,c,l,a,s[u+3],22,-1044525330),a=g(a,r,c,l,s[u+4],7,-176418897),l=g(l,a,r,c,s[u+5],12,1200080426),c=g(c,l,a,r,s[u+6],17,-1473231341),r=g(r,c,l,a,s[u+7],22,-45705983),a=g(a,r,c,l,s[u+8],7,1770035416),l=g(l,a,r,c,s[u+9],12,-1958414417),c=g(c,l,a,r,s[u+10],17,-42063),r=g(r,c,l,a,s[u+11],22,-1990404162),a=g(a,r,c,l,s[u+12],7,1804603682),l=g(l,a,r,c,s[u+13],12,-40341101),c=g(c,l,a,r,s[u+14],17,-1502002290),r=g(r,c,l,a,s[u+15],22,1236535329),a=p(a,r,c,l,s[u+1],5,-165796510),l=p(l,a,r,c,s[u+6],9,-1069501632),c=p(c,l,a,r,s[u+11],14,643717713),r=p(r,c,l,a,s[u+0],20,-373897302),a=p(a,r,c,l,s[u+5],5,-701558691),l=p(l,a,r,c,s[u+10],9,38016083),c=p(c,l,a,r,s[u+15],14,-660478335),r=p(r,c,l,a,s[u+4],20,-405537848),a=p(a,r,c,l,s[u+9],5,568446438),l=p(l,a,r,c,s[u+14],9,-1019803690),c=p(c,l,a,r,s[u+3],14,-187363961),r=p(r,c,l,a,s[u+8],20,1163531501),a=p(a,r,c,l,s[u+13],5,-1444681467),l=p(l,a,r,c,s[u+2],9,-51403784),c=p(c,l,a,r,s[u+7],14,1735328473),r=p(r,c,l,a,s[u+12],20,-1926607734),a=f(a,r,c,l,s[u+5],4,-378558),l=f(l,a,r,c,s[u+8],11,-2022574463),c=f(c,l,a,r,s[u+11],16,1839030562),r=f(r,c,l,a,s[u+14],23,-35309556),a=f(a,r,c,l,s[u+1],4,-1530992060),l=f(l,a,r,c,s[u+4],11,1272893353),c=f(c,l,a,r,s[u+7],16,-155497632),r=f(r,c,l,a,s[u+10],23,-1094730640),a=f(a,r,c,l,s[u+13],4,681279174),l=f(l,a,r,c,s[u+0],11,-358537222),c=f(c,l,a,r,s[u+3],16,-722521979),r=f(r,c,l,a,s[u+6],23,76029189),a=f(a,r,c,l,s[u+9],4,-640364487),l=f(l,a,r,c,s[u+12],11,-421815835),c=f(c,l,a,r,s[u+15],16,530742520),r=f(r,c,l,a,s[u+2],23,-995338651),a=m(a,r,c,l,s[u+0],6,-198630844),l=m(l,a,r,c,s[u+7],10,1126891415),c=m(c,l,a,r,s[u+14],15,-1416354905),r=m(r,c,l,a,s[u+5],21,-57434055),a=m(a,r,c,l,s[u+12],6,1700485571),l=m(l,a,r,c,s[u+3],10,-1894986606),c=m(c,l,a,r,s[u+10],15,-1051523),r=m(r,c,l,a,s[u+1],21,-2054922799),a=m(a,r,c,l,s[u+8],6,1873313359),l=m(l,a,r,c,s[u+15],10,-30611744),c=m(c,l,a,r,s[u+6],15,-1560198380),r=m(r,c,l,a,s[u+13],21,1309151649),a=m(a,r,c,l,s[u+4],6,-145523070),l=m(l,a,r,c,s[u+11],10,-1120210379),c=m(c,l,a,r,s[u+2],15,718787259),r=m(r,c,l,a,s[u+9],21,-343485551),a=a+Wt>>>0,r=r+Yt>>>0,c=c+zt>>>0,l=l+Vt>>>0}return t.endian([a,r,c,l])};n._ff=function(i,h,s,b,a,r,c){var l=i+(h&s|~h&b)+(a>>>0)+c;return(l<<r|l>>>32-r)+h},n._gg=function(i,h,s,b,a,r,c){var l=i+(h&b|s&~b)+(a>>>0)+c;return(l<<r|l>>>32-r)+h},n._hh=function(i,h,s,b,a,r,c){var l=i+(h^s^b)+(a>>>0)+c;return(l<<r|l>>>32-r)+h},n._ii=function(i,h,s,b,a,r,c){var l=i+(s^(h|~b))+(a>>>0)+c;return(l<<r|l>>>32-r)+h},n._blocksize=16,n._digestsize=16,K.exports=function(i,h){if(i==null)throw new Error("Illegal argument "+i);var s=t.wordsToBytes(n(i,h));return h&&h.asBytes?s:h&&h.asString?d.bytesToString(s):t.bytesToHex(s)}})();var Tt=K.exports;const Bt=Ct(Tt),Z=["avatar_url","email","name"],_t=[...Z,"identifier_hash"],F=()=>{const t="cw_user_",{websiteToken:e}=window.$chatwoot;return`${t}${e}`},Mt=({identifier:t="",user:e})=>`${_t.reduce((d,n)=>`${d}${n}${e[n]||""}`,"")}identifier${t}`,$t=(...t)=>Bt(Mt(...t)),Lt=t=>Z.reduce((e,o)=>e||!!t[o],!1),H=(t,e,{expires:o=365,baseDomain:d=void 0}={})=>{const n={expires:o,sameSite:"Lax",domain:d};typeof e=="object"&&(e=JSON.stringify(e)),C.set(t,e,n)},Q=["click","touchstart","keypress","keydown"],Pt=()=>{let t;try{t=new(window.AudioContext||window.webkitAudioContext)}catch{}return t},kt=async(t="",e)=>{const o=Pt(),d=n=>{window.playAudioAlert=()=>{if(o){const i=o.createBufferSource();i.buffer=n,i.connect(o.destination),i.loop=!1,i.start()}}};if(o){const{type:n="dashboard",alertTone:i="ding"}=e||{},h=`${t}/audio/${n}/${i}.mp3`,s=new Request(h);fetch(s).then(b=>b.arrayBuffer()).then(b=>(o.decodeAudioData(b).then(d),new Promise(a=>a()))).catch(()=>{})}},At=({origin:t,conversationCookie:e,websiteToken:o,locale:d})=>{const n=new URL("/widget",t);return n.searchParams.append("cw_conversation",e),n.searchParams.append("website_token",o),n.searchParams.append("locale",d),n.toString()},Ft=(t,e,o,d)=>{try{const n=At({origin:t,websiteToken:e,locale:o,conversationCookie:d});window.open(n,`webwidget_session_${e}`,"resizable=off,width=400,height=600").focus()}catch(n){console.log(n)}};function tt(t){if(t===null||t===!0||t===!1)return NaN;var e=Number(t);return isNaN(e)?e:e<0?Math.ceil(e):Math.floor(e)}function U(t,e){if(e.length<t)throw new TypeError(t+" argument"+(t>1?"s":"")+" required, but only "+e.length+" present")}function Ht(t){U(1,arguments);var e=Object.prototype.toString.call(t);return t instanceof Date||typeof t=="object"&&e==="[object Date]"?new Date(t.getTime()):typeof t=="number"||e==="[object Number]"?new Date(t):((typeof t=="string"||e==="[object String]")&&typeof console<"u"&&(console.warn("Starting with v2.0.0-beta.1 date-fns doesn't accept strings as date arguments. Please use `parseISO` to parse strings. See: https://git.io/fjule"),console.warn(new Error().stack)),new Date(NaN))}function Ut(t,e){U(2,arguments);var o=Ht(t).getTime(),d=tt(e);return new Date(o+d)}var Ot=36e5;function Rt(t,e){U(2,arguments);var o=tt(e);return Ut(t,o*Ot)}const et=(t,e="")=>H("cw_conversation",t,{baseDomain:e}),It=t=>{const e=Rt(new Date,1);H("cw_snooze_campaigns_till",Number(e),{expires:e,baseDomain:t})},w={getUrl({baseUrl:t,websiteToken:e}){return`${t}/widget?website_token=${e}`},createFrame:({baseUrl:t,websiteToken:e})=>{if(w.getAppFrame())return;it();const o=document.createElement("iframe"),d=C.get("cw_conversation");let n=w.getUrl({baseUrl:t,websiteToken:e});d&&(n=`${n}&cw_conversation=${d}`),o.src=n,o.allow="camera;microphone;fullscreen;display-capture;picture-in-picture;clipboard-write;",o.id="chatwoot_live_chat_widget",o.style.visibility="hidden";let i=`woot-widget-holder woot--hide woot-elements--${window.$chatwoot.position}`;window.$chatwoot.hideMessageBubble&&(i+=" woot-widget--without-bubble"),W(window.$chatwoot.widgetStyle)&&(i+=" woot-widget-holder--flat"),E(x,i),x.id="cw-widget-holder",x.dataset.turboPermanent=!0,x.appendChild(o),V.appendChild(x),w.initPostMessageCommunication(),w.initWindowSizeListener(),w.preventDefaultScroll()},getAppFrame:()=>document.getElementById("chatwoot_live_chat_widget"),getBubbleHolder:()=>document.getElementsByClassName("woot--bubble-holder"),sendMessage:(t,e)=>{w.getAppFrame().contentWindow.postMessage(`chatwoot-widget:${JSON.stringify({event:t,...e})}`,"*")},initPostMessageCommunication:()=>{window.onmessage=t=>{if(typeof t.data!="string"||t.data.indexOf("chatwoot-widget:")!==0)return;const e=JSON.parse(t.data.replace("chatwoot-widget:",""));typeof w.events[e.event]=="function"&&w.events[e.event](e)}},initWindowSizeListener:()=>{window.addEventListener("resize",()=>w.toggleCloseButton())},preventDefaultScroll:()=>{x.addEventListener("wheel",t=>{const e=t.deltaY,o=x.scrollHeight,d=x.offsetHeight,n=x.scrollTop;(n===0&&e<0||d+n===o&&e>0)&&t.preventDefault()})},setFrameHeightToFitContent:(t,e)=>{const o=w.getAppFrame(),d=e?`${t}px`:"100%";o&&o.setAttribute("style",`height: ${d} !important`)},setupAudioListeners:()=>{const{baseUrl:t=""}=window.$chatwoot;kt(t,{type:"widget",alertTone:"ding"}).then(()=>Q.forEach(e=>{document.removeEventListener(e,w.setupAudioListeners,!1)}))},events:{loaded:t=>{et(t.config.authToken,window.$chatwoot.baseDomain),window.$chatwoot.hasLoaded=!0;const e=C.get("cw_snooze_campaigns_till");w.sendMessage("config-set",{locale:window.$chatwoot.locale,position:window.$chatwoot.position,hideMessageBubble:window.$chatwoot.hideMessageBubble,showPopoutButton:window.$chatwoot.showPopoutButton,widgetStyle:window.$chatwoot.widgetStyle,darkMode:window.$chatwoot.darkMode,showUnreadMessagesDialog:window.$chatwoot.showUnreadMessagesDialog,campaignsSnoozedTill:e}),w.onLoad({widgetColor:t.config.channelConfig.widgetColor}),w.toggleCloseButton(),window.$chatwoot.user&&w.sendMessage("set-user",window.$chatwoot.user),window.playAudioAlert=()=>{},Q.forEach(o=>{document.addEventListener(o,w.setupAudioListeners,!1)}),window.$chatwoot.resetTriggered||D({eventName:dt})},error:({errorType:t,data:e})=>{D({eventName:at,data:e}),t===xt&&C.remove(F())},onEvent({eventIdentifier:t,data:e}){D({eventName:t,data:e})},setBubbleLabel(t){bt(window.$chatwoot.launcherTitle||t.label)},setAuthCookie({data:{widgetAuthToken:t}}){et(t,window.$chatwoot.baseDomain)},setCampaignReadOn(){It(window.$chatwoot.baseDomain)},postback(t){D({eventName:lt,data:t})},toggleBubble:t=>{let e={};t==="open"?e.toggleValue=!0:t==="close"&&(e.toggleValue=!1),T(e)},popoutChatWindow:({baseUrl:t,websiteToken:e,locale:o})=>{const d=C.get("cw_conversation");window.$chatwoot.toggle("close"),Ft(t,e,o,d)},closeWindow:()=>{T({toggleValue:!1}),q()},onBubbleToggle:t=>{w.sendMessage("toggle-open",{isOpen:t}),t&&w.pushEvent("webwidget.triggered")},onLocationChange:({referrerURL:t,referrerHost:e})=>{w.sendMessage("change-url",{referrerURL:t,referrerHost:e})},updateIframeHeight:t=>{const{extraHeight:e=0,isFixedHeight:o}=t;w.setFrameHeightToFitContent(e,o)},setUnreadMode:()=>{vt(),T({toggleValue:!0})},resetUnreadMode:()=>q(),handleNotificationDot:t=>{if(window.$chatwoot.hideMessageBubble)return;const e=document.querySelector(".woot-widget-bubble");t.unreadMessageCount>0&&!e.classList.contains("unread-notification")?E(e,"unread-notification"):t.unreadMessageCount===0&&_(e,"unread-notification")},closeChat:()=>{T({toggleValue:!1})},playAudio:()=>{window.playAudioAlert()}},pushEvent:t=>{w.sendMessage("push-event",{eventName:t})},onLoad:({widgetColor:t})=>{const e=w.getAppFrame();if(e.style.visibility="",e.setAttribute("id","chatwoot_live_chat_widget"),w.getBubbleHolder().length)return;pt(window.$chatwoot.hideMessageBubble),st();let o="woot-widget-bubble",d=`woot-elements--${window.$chatwoot.position} woot-widget-bubble woot--close woot--hide`;W(window.$chatwoot.widgetStyle)&&(o+=" woot-widget-bubble--flat",d+=" woot-widget-bubble--flat"),yt(t)&&(o+=" woot-widget-bubble-color--lighter",d+=" woot-widget-bubble-color--lighter");const n=gt({className:o,path:wt,target:y});E(v,d),n.style.background=t,v.style.background=t,S.appendChild(n),S.appendChild(v),mt()},toggleCloseButton:()=>{let t=!1;window.matchMedia("(max-width: 668px)").matches&&(t=!0),w.sendMessage("toggle-close-button",{isMobile:t})}},Nt="sdk-set-bubble-visibility",Xt=({baseUrl:t,websiteToken:e})=>{if(window.$chatwoot)return;document.addEventListener("turbo:before-render",i=>{i.detail.renderMethod!=="morph"&&L(i.detail.newBody)}),window.Turbolinks&&document.addEventListener("turbolinks:before-render",i=>{L(i.data.newBody)}),document.addEventListener("astro:before-swap",i=>L(i.newDocument.body));const o=window.chatwootSettings||{};let d=o.locale,n=o.baseDomain;o.useBrowserLanguage&&(d=window.navigator.language.replace("-","_")),window.$chatwoot={baseUrl:t,baseDomain:n,hasLoaded:!1,hideMessageBubble:o.hideMessageBubble||!1,isOpen:!1,position:o.position==="left"?"left":"right",websiteToken:e,locale:d,useBrowserLanguage:o.useBrowserLanguage||!1,type:N(o.type),launcherTitle:o.launcherTitle||"",showPopoutButton:o.showPopoutButton||!1,showUnreadMessagesDialog:o.showUnreadMessagesDialog??!0,widgetStyle:rt(o.widgetStyle)||"standard",resetTriggered:!1,darkMode:Y(o.darkMode),toggle(i){w.events.toggleBubble(i)},toggleBubbleVisibility(i){let h=document.querySelector(".woot--bubble-holder"),s=document.querySelector(".woot-widget-holder");i==="hide"?(E(s,"woot-widget--without-bubble"),E(h,"woot-hidden"),window.$chatwoot.hideMessageBubble=!0):i==="show"&&(_(h,"woot-hidden"),_(s,"woot-widget--without-bubble"),window.$chatwoot.hideMessageBubble=!1),w.sendMessage(Nt,{hideMessageBubble:window.$chatwoot.hideMessageBubble})},popoutChatWindow(){w.events.popoutChatWindow({baseUrl:window.$chatwoot.baseUrl,websiteToken:window.$chatwoot.websiteToken,locale:d})},setUser(i,h){if(typeof i!="string"&&typeof i!="number")throw new Error("Identifier should be a string or a number");if(!Lt(h))throw new Error("User object should have one of the keys [avatar_url, email, name]");const s=F(),b=C.get(s),a=$t({identifier:i,user:h});a!==b&&(window.$chatwoot.identifier=i,window.$chatwoot.user=h,w.sendMessage("set-user",{identifier:i,user:h}),H(s,a,{baseDomain:n}))},setCustomAttributes(i={}){if(!i||!Object.keys(i).length)throw new Error("Custom attributes should have atleast one key");w.sendMessage("set-custom-attributes",{customAttributes:i})},deleteCustomAttribute(i=""){if(i)w.sendMessage("delete-custom-attribute",{customAttribute:i});else throw new Error("Custom attribute is required")},setConversationCustomAttributes(i={}){if(!i||!Object.keys(i).length)throw new Error("Custom attributes should have atleast one key");w.sendMessage("set-conversation-custom-attributes",{customAttributes:i})},deleteConversationCustomAttribute(i=""){if(i)w.sendMessage("delete-conversation-custom-attribute",{customAttribute:i});else throw new Error("Custom attribute is required")},setLabel(i=""){w.sendMessage("set-label",{label:i})},removeLabel(i=""){w.sendMessage("remove-label",{label:i})},setLocale(i="en"){w.sendMessage("set-locale",{locale:i})},setColorScheme(i="light"){w.sendMessage("set-color-scheme",{darkMode:Y(i)})},reset(){window.$chatwoot.isOpen&&w.events.toggleBubble(),C.remove("cw_conversation"),C.remove(F());const i=w.getAppFrame();i.src=w.getUrl({baseUrl:window.$chatwoot.baseUrl,websiteToken:window.$chatwoot.websiteToken}),window.$chatwoot.resetTriggered=!0}},w.createFrame({baseUrl:t,websiteToken:e})};window.chatwootSDK={run:Xt}})();
