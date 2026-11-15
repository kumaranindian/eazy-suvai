/**
 * The public menu's only JavaScript (M07). Inline, no libraries, well under
 * the 10 KB budget (a test checks the size). The page works without it:
 * category links are plain anchors, photos link to the large rendition and
 * descriptions are shown in full until the script clamps them.
 *
 * What it adds:
 * - Turns on the theme font stylesheet once loaded (it never blocks the
 *   first paint).
 * - Category bar: highlights the category in view (IntersectionObserver)
 *   and keeps the active pill visible (FR-039, FR-040).
 * - Lightbox: a `<dialog>` with a close button, Escape, backdrop tap and
 *   swipe down (FR-041).
 * - "more" / "less" for descriptions longer than three lines.
 * - The analytics hook `track(type, data)` (M09). It does nothing unless
 *   `<body data-beacon="/e">` is set; M09 sets it and owns the payload.
 *   Events: `view` on load (`src` = `qr` | `direct`), `cat` on a category
 *   tap (`{id}`), `item` on a photo or "more" (`{id}`).
 */

/** Runs in `<head>` before first paint, so the clamp applies without a jump. */
export const HEAD_SCRIPT = "document.documentElement.classList.add(\"js\")";

/** Runs at the end of `<body>`. */
export const BODY_SCRIPT = `(function(){
var d=document,b=d.body,ds=b.dataset,w=window;
var f=d.getElementById("es-font");if(f){if(f.sheet)f.media="all";else f.addEventListener("load",function(){f.media="all"})}
var src=/[?&]src=qr(&|$)/.test(location.search)?"qr":"direct";
if(src==="qr"&&history.replaceState){history.replaceState(null,"",location.pathname+location.hash)}
function track(t,x){var u=ds.beacon;if(!u||!navigator.sendBeacon)return;
try{var p={type:t,slug:ds.slug||"",src:src};for(var k in x)p[k]=x[k];
navigator.sendBeacon(u,new Blob([JSON.stringify(p)],{type:"application/json"}))}catch(e){}}
w.esTrack=track;
track("view",{});
var nav=d.querySelector(".cats"),links=nav?nav.querySelectorAll("a[href^='#']"):[];
function setActive(id){for(var i=0;i<links.length;i++){var a=links[i];
if(a.getAttribute("href")==="#"+id){a.setAttribute("aria-current","true");
var ul=a.parentNode.parentNode;if(ul.scrollWidth>ul.clientWidth){ul.scrollLeft=a.offsetLeft-(ul.clientWidth-a.offsetWidth)/2}}
else a.removeAttribute("aria-current")}}
for(var i=0;i<links.length;i++){links[i].addEventListener("click",function(){var id=this.getAttribute("href").slice(1);
setActive(id);track("cat",{id:id.replace(/^c-/,"")})})}
if(links.length&&"IntersectionObserver" in w){var seen={};
var io=new IntersectionObserver(function(es){es.forEach(function(e){seen[e.target.id]=e.isIntersecting});
var secs=d.querySelectorAll("main section[id^='c-']");for(var j=0;j<secs.length;j++){if(seen[secs[j].id]){setActive(secs[j].id);break}}},
{rootMargin:"-72px 0px -55% 0px"});
d.querySelectorAll("main section[id^='c-']").forEach(function(s){io.observe(s)})}
var more=ds.more||"more",less=ds.less||"less";
d.querySelectorAll(".item-desc").forEach(function(p){if(p.scrollHeight<=p.clientHeight+2)return;
var btn=d.createElement("button");btn.type="button";btn.className="more";btn.textContent=more;btn.setAttribute("aria-expanded","false");
btn.addEventListener("click",function(){var o=p.classList.toggle("open");btn.textContent=o?less:more;btn.setAttribute("aria-expanded",String(o));
if(o){var li=p.closest(".item");if(li)track("item",{id:li.getAttribute("data-id")})}});
p.parentNode.insertBefore(btn,p.nextSibling)});
var dlg=d.createElement("dialog");if(!dlg.showModal)return;
dlg.className="lb";dlg.innerHTML='<button type="button" class="lb-close"><span aria-hidden="true">\\u00d7</span></button><img alt="">';
var x=dlg.firstChild,img=dlg.lastChild;x.setAttribute("aria-label",ds.close||"Close");b.appendChild(dlg);
function shut(){img.style.transform="";if(dlg.open)dlg.close()}
x.addEventListener("click",shut);
dlg.addEventListener("click",function(e){if(e.target===dlg)shut()});
dlg.addEventListener("close",function(){img.removeAttribute("src")});
var y0=null,dy=0;
dlg.addEventListener("touchstart",function(e){y0=e.touches[0].clientY;dy=0},{passive:true});
dlg.addEventListener("touchmove",function(e){if(y0===null)return;dy=Math.max(0,e.touches[0].clientY-y0);img.style.transform="translateY("+dy+"px)"},{passive:true});
dlg.addEventListener("touchend",function(){if(dy>80)shut();else img.style.transform="";y0=null});
d.addEventListener("click",function(e){var a=e.target.closest&&e.target.closest("a.zoom");if(!a)return;e.preventDefault();
var im=a.querySelector("img");img.src=a.getAttribute("href");img.alt=im?im.getAttribute("data-alt")||"":"";dlg.showModal();x.focus();
var li=a.closest(".item");if(li)track("item",{id:li.getAttribute("data-id")})});
})();`;
