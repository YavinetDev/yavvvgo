// ---- map
const mapEl=$('#leafletMap'), mapStatus=$('#mapStatus');
let map=null, routes=null, stopsLayer=null, vehiclesLayer=null, activeCity=null, fitPending=true, cityZoom=0, dirty=true, renderedSel=null, buses=[];
const routeLayers=new Map();
const status=text=>{mapStatus.textContent=text;mapStatus.hidden=!text};
const css=n=>getComputedStyle(document.documentElement).getPropertyValue(n).trim();
function updLegend(){$('#lg').innerHTML=(LAY.d?'<span><i style="background:#177bc9"></i>депо</span>':'')+(LAY.o?'<span><i style="background:#ed4543"></i>ОРП</span>':'')+'<span><i style="background:var(--acc);border-radius:50%"></i>маршруты</span>'}
function initMap(){
 if(!window.L){status('Не удалось загрузить Leaflet');return}
 map=L.map(mapEl,{zoomControl:false,attributionControl:false,minZoom:4,maxZoom:19});
 if(L.maplibreGL){
  status('Загрузка карты…');
  try{
   const base=L.maplibreGL({style:'https://tiles.openfreemap.org/styles/liberty',interactive:false});
   map.whenReady(()=>{
    try{
     base.addTo(map);
     const gl=base.getMaplibreMap();
     gl.on('error',()=>status('Не удалось загрузить часть карты.'));
     gl.on('idle',()=>{if(gl.isStyleLoaded()&&gl.areTilesLoaded()&&gl.queryRenderedFeatures().length)status('')});
    }catch(e){status('Подложка недоступна: не удалось запустить WebGL.')}
   });
  }catch(e){status('Не удалось запустить подложку карты.')}
 }else status('Не удалось загрузить движок подложки.');
 map.createPane('stopsPane').style.zIndex=450;
 map.createPane('vehiclesPane').style.zIndex=460;
 stopsLayer=L.layerGroup().addTo(map);vehiclesLayer=L.layerGroup().addTo(map);
 map.on('zoomend',()=>{dirty=true});
 map.on('click',()=>$('#lp').classList.remove('on'));
 new ResizeObserver(resize).observe(mapEl);
 resize();
}
function syncCity(){
 if(activeCity===S.city)return;
 if(routes)routes.remove();
 activeCity=S.city;renderedSel=null;routeLayers.clear();
 const c=city(activeCity);
 routes=L.geoJSON(GEO[activeCity],{smoothFactor:0,style:f=>({color:c.routes[f.properties.i].c,weight:2.4,opacity:.85}),onEachFeature(f,layer){
  const i=f.properties.i;routeLayers.set(i,layer);layer.on('click',()=>{ $('#lp').classList.remove('on');selectRoute(i,false) });
 }}).addTo(map);
}
function resize(){
 if(!map||!mapEl.clientWidth||!mapEl.clientHeight)return;
 if(map._loaded)map.invalidateSize({pan:false,animate:false});
 if(!fitPending)return;
 syncCity();fitPending=false;
 const bounds=routes.getBounds(), selected=routeLayers.get(S.sel);
 const padding=[Math.min(36,mapEl.clientWidth/5),Math.min(30,mapEl.clientHeight/5)];
 if(bounds.isValid()){
  cityZoom=map.getBoundsZoom(bounds,false,L.point(padding).multiplyBy(2));
  map.fitBounds(selected?selected.getBounds():bounds,{padding,animate:false,maxZoom:17});
 }
 dirty=true;
}
function queueFit(){fitPending=true;requestAnimationFrame(resize)}
function fitCity(){queueFit()}
function fitRoute(){queueFit()}
function focusStop(c,i){if(map&&map._loaded){const s=c.stops[i];map.setView([s[1],s[2]],Math.min(19,Math.max(map.getZoom(),15)),{animate:false})}}
$('#zi').onclick=()=>{if(map&&map._loaded)map.zoomIn()};
$('#zo').onclick=()=>{if(map&&map._loaded)map.zoomOut()};
$('#fit').onclick=queueFit;
function drawMarkers(c,sel){
 stopsLayer.clearLayers();
 const point=(p,r,options)=>L.circleMarker([p[1],p[2]],{pane:'stopsPane',radius:r,weight:2,fillOpacity:1,...options}).addTo(stopsLayer);
 c.dep.forEach(d=>{if(d[3]==='o'?!LAY.o:!LAY.d)return;const color=d[3]==='o'?'#ed4543':'#177bc9';point(d,4,{color,fillColor:color,interactive:false})});
 const show=map.getZoom()-cityZoom;
 const marked=new Set(S.stopSel?S.stopSel.g:[]);
 const addStop=(i,color,current,label)=>{
  const s=c.stops[i],m=point(s,current?6:4,{color,fillColor:current?css('--acc'):'#fff',bubblingMouseEvents:false});
  if(label){const el=document.createElement('span');el.textContent=s[0];m.bindTooltip(el)}
  m.on('click',()=>openStop(i));marked.delete(i);
 };
 if(sel&&show>2){prep(sel);for(const i of new Set(sel.sl.map(o=>o.si)))addStop(i,sel.c,sel.un[S.stopI]?.si===i,true)}
 else if(!sel&&show>3)c.stops.forEach((_,i)=>addStop(i,'#0B1120',false,true));
 marked.forEach(i=>addStop(i,css('--acc'),true,true));
}
function drawMap(){
 if(!map||!mapEl.clientWidth||!mapEl.clientHeight)return;
 syncCity();if(!map._loaded)return;
 const c=city(S.city),sel=S.sel==null?null:c.routes[S.sel];
 if(renderedSel!==sel){
  renderedSel=sel;vehiclesLayer.clearLayers();buses=[];
  routeLayers.forEach((layer,i)=>layer.setStyle({weight:i===S.sel?5:2.4,opacity:sel&&i!==S.sel?.25:.9}));
  routeLayers.get(S.sel)?.bringToFront();
 }
 drawMarkers(c,sel);
}
function updateVehicles(){
 if(!map||!map._loaded||!mapEl.clientWidth||S.sel==null)return;
 const c=city(S.city),r=c.routes[S.sel];
 veh(r).forEach((d,i)=>{
  const p=posAt(r,d),ll=[-p[1],p[0]/c.kx];
  if(buses[i])buses[i].setLatLng(ll);
  else buses[i]=L.circleMarker(ll,{pane:'vehiclesPane',radius:6,color:'#fff',weight:2,fillColor:r.c,fillOpacity:1,interactive:false}).addTo(vehiclesLayer);
 });
}
let lastEta=0;
function loop(t){
 if(dirty){dirty=false;drawMap()}
 if(t-lastEta>700){lastEta=t;updateVehicles();if(S.stopSel)updStop();else if(S.sel!=null)updEta()}
 requestAnimationFrame(loop);
}
