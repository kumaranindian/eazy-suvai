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
 *   and keeps the active pill visible (FR-039, FR-040). The zone starts
 *   8 px below the bar (sections scroll to 72 px), so the previous section
 *   ending at the bar never counts as the one in view.
 * - Lightbox: a `<dialog>` with a close button, Escape, backdrop tap and
 *   swipe down (FR-041).
 * - "more" / "less" for descriptions longer than one line, placed at the
 *   end of the item's pill line so it takes no extra row.
 * - Filter chips (dietary labels and tags): shows the bar, hides items that
 *   don't match, then empty sections and their category links. Any chip
 *   within a group matches; the two groups narrow each other. Items marked
 *   `data-off` (unavailable, FR-043) never show when `<body data-hide-off>`
 *   is set (the owner hides unavailable items); otherwise they show dimmed.
 * - Live updates (FR-044, FR-095): while the tab is visible it checks
 *   `<body data-live>` (`/{slug}/live.json`) at once and then every 10 s,
 *   and again when the tab comes back. Availability changes are applied in
 *   place: the item is dimmed with its badge, or hidden, or shown again. A newer version is fetched from `/{slug}?v={n}` (not yet in the
 *   CDN) and swapped into the page, keeping the scroll position. A null
 *   version (suspended, moved, gone) loads the URL again, past the CDN.
 *   Hidden tabs never poll. After `<body data-idle>` minutes (default 30)
 *   without a tap, scroll or key it pauses; the next one, or coming back
 *   to the tab, checks at once and starts again. `<body data-max>` minutes
 *   (default 120) after the page was opened it stops for good; opening
 *   the link again (a new scan) starts a new session. Both come from
 *   `config/platform` (`live-limits.ts`).
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
if(/[?&](src|v|r)=/.test(location.search)&&history.replaceState){history.replaceState(null,"",location.pathname+location.hash)}
${BEACON_SCRIPT}
w.esTrack=track;
track("view",{});
var links=[],io=null,fb=null,chips=[],clr,nm,st,dlg=null,more=ds.more||"more",less=ds.less||"less";
function setActive(id){for(var i=0;i<links.length;i++){var a=links[i];
if(a.getAttribute("href")==="#"+id){a.setAttribute("aria-current","true");
var ul=a.parentNode.parentNode;if(ul.scrollWidth>ul.clientWidth){ul.scrollLeft=a.offsetLeft-(ul.clientWidth-a.offsetWidth)/2}}
else a.removeAttribute("aria-current")}}
function mores(){d.querySelectorAll(".item-desc:not([data-m])").forEach(function(p){if(!p.offsetParent)return;p.setAttribute("data-m","");if(p.scrollHeight<=p.clientHeight+2)return;
var btn=d.createElement("button");btn.type="button";btn.className="more";btn.textContent=more;btn.setAttribute("aria-expanded","false");
btn.addEventListener("click",function(){var o=p.classList.toggle("open");btn.textContent=o?less:more;btn.setAttribute("aria-expanded",String(o));
if(o){var li=p.closest(".item");if(li)track("item",{id:li.getAttribute("data-id")})}});
var meta=p.parentNode.querySelector(".item-meta");if(meta)meta.appendChild(btn);else p.parentNode.insertBefore(btn,p.nextSibling)})}
function picked(g){var r=[];for(var i=0;i<chips.length;i++){var c=chips[i];if(c.getAttribute("data-g")===g&&c.getAttribute("aria-pressed")==="true")r.push(c.getAttribute("data-v"))}return r}
function refresh(){var D=picked("d"),T=picked("t"),on=D.length+T.length>0,n=0,its=d.querySelectorAll("main .item");
for(var i=0;i<its.length;i++){var it=its[i],dv=it.getAttribute("data-d")||"",tv=(it.getAttribute("data-t")||"").split(" "),ok=!("hideOff" in ds&&it.hasAttribute("data-off"))&&(!D.length||D.indexOf(dv)>=0);
if(ok&&T.length){ok=false;for(var j=0;j<T.length;j++){if(tv.indexOf(T[j])>=0)ok=true}}
it.hidden=!ok;if(ok&&it.closest("section[id^='c-']"))n++}
var secs=d.querySelectorAll("main section");for(var k=0;k<secs.length;k++){var sc=secs[k],vis=!!sc.querySelector(".item:not([hidden])");sc.hidden=!vis;
for(var m=0;m<links.length;m++){if(links[m].getAttribute("href")==="#"+sc.id)links[m].parentNode.hidden=!vis}}
var em=d.querySelector("main .empty");if(em)em.hidden=on||n>0;
if(fb){clr.hidden=!on;nm.hidden=!on||n>0;st.textContent=on?st.getAttribute("data-shown").replace("{count}",n):""}
mores()}
function init(){var nav=d.querySelector(".cats");links=nav?nav.querySelectorAll("a[href^='#']"):[];
for(var i=0;i<links.length;i++){links[i].addEventListener("click",function(){var id=this.getAttribute("href").slice(1);
setActive(id);track("cat",{id:id.replace(/^c-/,"")})})}
if(io){io.disconnect();io=null}
if(links.length&&"IntersectionObserver" in w){var seen={};
io=new IntersectionObserver(function(es){es.forEach(function(e){seen[e.target.id]=e.isIntersecting});
var secs=d.querySelectorAll("main section[id^='c-']");for(var j=0;j<secs.length;j++){if(seen[secs[j].id]){setActive(secs[j].id);break}}},
{rootMargin:"-80px 0px -55% 0px"});
d.querySelectorAll("main section[id^='c-']").forEach(function(s){io.observe(s)})}
fb=d.querySelector(".filters");chips=[];if(fb){fb.hidden=false;
chips=fb.querySelectorAll(".chip[data-g]");clr=fb.querySelector(".clear");nm=d.querySelector(".no-match");st=d.querySelector("[data-shown]");
for(var q=0;q<chips.length;q++){chips[q].addEventListener("click",function(){this.setAttribute("aria-pressed",String(this.getAttribute("aria-pressed")!=="true"));refresh()})}
clr.addEventListener("click",function(){for(var i=0;i<chips.length;i++)chips[i].setAttribute("aria-pressed","false");refresh();if(chips[0])chips[0].focus()})}
refresh()}
init();
var V=+ds.v||0,busy=0,tm=0,t0=Date.now(),last=t0,over=0;
function mins(k,x){return(+ds[k]||x)*6e4}
function off(it,o){it.classList.toggle("sold-out",o);var bd=it.querySelector(".badge.sold"),mt=it.querySelector(".item-meta");
if(o){it.setAttribute("data-off","");it.setAttribute("aria-disabled","true");if(!bd){bd=d.createElement("span");bd.className="badge sold";bd.textContent=ds.sold||"";
if(!mt){mt=d.createElement("div");mt.className="item-meta";it.querySelector(".item-body").appendChild(mt)}mt.insertBefore(bd,mt.firstChild)}}
else{it.removeAttribute("data-off");it.removeAttribute("aria-disabled");if(bd)bd.parentNode.removeChild(bd)}}
function avail(a){if(!a)return;var its=d.querySelectorAll("main .item"),ch=0;
for(var i=0;i<its.length;i++){var it=its[i],v=a[it.getAttribute("data-id")];if(typeof v!=="boolean"||it.hasAttribute("data-off")!==v)continue;
ch=1;off(it,!v)}
if(ch)refresh()}
function swap(v,a){busy=1;fetch(location.pathname+"?v="+v,{credentials:"omit"}).then(function(r){return r.ok?r.text():""}).then(function(t){busy=0;
var n=t?new DOMParser().parseFromString(t,"text/html"):null,nb=n&&n.body;if(!nb||!nb.querySelector("main"))return;
var os=d.querySelector("head style"),ns=n.querySelector("head style");if(os&&ns)os.textContent=ns.textContent;d.title=n.title;
nb.querySelectorAll("script,.splash").forEach(function(e){e.parentNode.removeChild(e)});
for(var i=0;i<nb.attributes.length;i++)b.setAttribute(nb.attributes[i].name,nb.attributes[i].value);
var y=w.scrollY;if(dlg&&dlg.open)dlg.close();b.innerHTML=nb.innerHTML;if(dlg)b.appendChild(dlg);
V=+ds.v||v;init();avail(a);w.scrollTo(0,y)}).catch(function(){busy=0})}
function poll(){var n=Date.now();if(n-t0>mins("max",120))over=1;
if(over||n-last>mins("idle",30)){clearInterval(tm);tm=0;return}
if(busy||d.hidden||!ds.live||!w.fetch)return;busy=1;
fetch(ds.live,{credentials:"omit"}).then(function(r){return r.ok?r.json():null}).then(function(j){busy=0;if(!j||!("v" in j))return;
if(j.v===null){clearInterval(tm);location.replace(location.pathname+"?r="+Date.now());return}
if(j.v>V)swap(j.v,j.a);else avail(j.a)}).catch(function(){busy=0})}
function sched(){clearInterval(tm);tm=0;if(!over&&!d.hidden&&ds.live){last=Date.now();tm=setInterval(poll,1e4);poll()}}
function act(){last=Date.now();if(!tm&&!over&&!d.hidden)sched()}
["scroll","touchstart","click","keydown"].forEach(function(t){w.addEventListener(t,act,{passive:true})});
d.addEventListener("visibilitychange",sched);w.addEventListener("pageshow",function(e){if(e.persisted)sched()});w.addEventListener("online",poll);sched();
dlg=d.createElement("dialog");if(!dlg.showModal){dlg=null;return}
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
