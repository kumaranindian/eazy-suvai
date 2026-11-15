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
 * - "more" / "less" for descriptions longer than one line, placed at the
 *   end of the item's pill line so it takes no extra row.
 * - Filter chips (dietary labels and tags): shows the bar, hides items that
 *   don't match, then empty sections and their category links. Any chip
 *   within a group matches; the two groups narrow each other.
 * - Analytics ({@link BEACON_SCRIPT}, M09).
 */

/**
 * The analytics beacon (M09, FR-071, FR-075), under 1 KB (a test checks).
 * `track(type, data)` posts `{type, slug, src, id?}` with
 * `navigator.sendBeacon` to `<body data-beacon>` (`/e`); without that
 * attribute it sends nothing. No cookies and no identifiers leave the
 * browser: a `view` is sent at most once per 30 minutes per tab session,
 * remembered as a time stamp in `sessionStorage` (`es_v_{slug}`).
 * Events: `view` on load (`src` = `qr` | `direct`), `cat` on a category
 * tap (`{id}`), `item` on a photo or "more" (`{id}`).
 */
export const BEACON_SCRIPT = `var ss=null;try{ss=w.sessionStorage}catch(e){}
function track(t,x){var u=ds.beacon;if(!u||!navigator.sendBeacon)return;
try{if(t==="view"&&ss){var k="es_v_"+(ds.slug||""),n=Date.now(),l=+ss.getItem(k)||0;
if(l&&n-l<18e5&&n>=l)return;ss.setItem(k,String(n))}}catch(e){}
try{var p={type:t,slug:ds.slug||"",src:src};for(var k2 in x)p[k2]=x[k2];
navigator.sendBeacon(u,new Blob([JSON.stringify(p)],{type:"text/plain"}))}catch(e){}}`;

/**
 * Runs in `<head>` before first paint, so the clamp applies without a jump.
 * Also shows the opening splash card once per tab session: on a repeat
 * visit it adds `no-splash` before the card can paint (key `es_s_{path}`).
 */
export const HEAD_SCRIPT = "var h=document.documentElement;h.classList.add(\"js\");" +
  "try{var k=\"es_s_\"+location.pathname,ss=sessionStorage;if(ss.getItem(k))h.classList.add(\"no-splash\");else ss.setItem(k,\"1\")}catch(e){}";

/** Runs at the end of `<body>`. */
export const BODY_SCRIPT = `(function(){
var d=document,b=d.body,ds=b.dataset,w=window;
var f=d.getElementById("es-font");if(f){if(f.sheet)f.media="all";else f.addEventListener("load",function(){f.media="all"})}
var src=/[?&]src=qr(&|$)/.test(location.search)?"qr":"direct";
if(src==="qr"&&history.replaceState){history.replaceState(null,"",location.pathname+location.hash)}
${BEACON_SCRIPT}
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
var meta=p.parentNode.querySelector(".item-meta");if(meta)meta.appendChild(btn);else p.parentNode.insertBefore(btn,p.nextSibling)});
var fb=d.querySelector(".filters");if(fb){fb.hidden=false;
var chips=fb.querySelectorAll(".chip[data-g]"),clr=fb.querySelector(".clear"),nm=d.querySelector(".no-match"),st=d.querySelector("[data-shown]");
function picked(g){var r=[];for(var i=0;i<chips.length;i++){var c=chips[i];if(c.getAttribute("data-g")===g&&c.getAttribute("aria-pressed")==="true")r.push(c.getAttribute("data-v"))}return r}
function apply(){var D=picked("d"),T=picked("t"),on=D.length+T.length>0,n=0,its=d.querySelectorAll("main .item");
for(var i=0;i<its.length;i++){var it=its[i],dv=it.getAttribute("data-d")||"",tv=(it.getAttribute("data-t")||"").split(" "),ok=!D.length||D.indexOf(dv)>=0;
if(ok&&T.length){ok=false;for(var j=0;j<T.length;j++){if(tv.indexOf(T[j])>=0)ok=true}}
it.hidden=!ok;if(ok&&it.closest("section[id^='c-']"))n++}
var secs=d.querySelectorAll("main section");for(var k=0;k<secs.length;k++){var sc=secs[k],vis=!!sc.querySelector(".item:not([hidden])");sc.hidden=!vis;
for(var m=0;m<links.length;m++){if(links[m].getAttribute("href")==="#"+sc.id)links[m].parentNode.hidden=!vis}}
clr.hidden=!on;nm.hidden=!on||n>0;st.textContent=on?st.getAttribute("data-shown").replace("{count}",n):""}
for(var q=0;q<chips.length;q++){chips[q].addEventListener("click",function(){this.setAttribute("aria-pressed",String(this.getAttribute("aria-pressed")!=="true"));apply()})}
clr.addEventListener("click",function(){for(var i=0;i<chips.length;i++)chips[i].setAttribute("aria-pressed","false");apply();if(chips[0])chips[0].focus()})}
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
