$ErrorActionPreference='Stop'
$source='E:\экотранспорт явинет\прототипы\ЯвьЕдет — прототип — фильтрация МО.html'
$s=[IO.File]::ReadAllText($source)
$geo=[IO.File]::ReadAllText((Join-Path (Get-Location) 'map-data.json'))
$map=[IO.File]::ReadAllText((Join-Path (Get-Location) 'map-layer.js'))
function Swap($pattern,$replacement){
 $hits=[regex]::Matches($script:s,$pattern)
 if($hits.Count -ne 1){throw "Expected one match, got $($hits.Count): $pattern"}
 $m=$hits[0];$script:s=$script:s.Substring(0,$m.Index)+$replacement+$script:s.Substring($m.Index+$m.Length)
}
Swap '(?ms)^const GEO=.*?(?=^const D=)' "const GEO=$geo;`n"
Swap '(?m)^#mapwrap[^\r\n]*' '#mapwrap{position:relative;flex:1;min-height:120px;width:100%;background:var(--map);overflow:hidden}#leafletMap{position:absolute;inset:0;width:100%;height:100%;z-index:0}.mc,.lg{z-index:4}.lp{z-index:6}#mapStatus{position:absolute;z-index:4;top:10px;left:10px;right:60px;background:var(--card);padding:6px 8px;border-radius:8px;font-size:12px}'
Swap '<div id="leafletMap" aria-hidden="true"></div><div id="tiles" aria-hidden="true"></div><canvas id="cv"></canvas><div style="position:absolute;right:10px;bottom:8px;z-index:4;font-size:10px;font-weight:700;color:#53647A;background:#FFFFFFDD;border:1px solid #D3DCE6;border-radius:8px;padding:4px 7px">© OpenStreetMap contributors</div>' '<div id="leafletMap" role="region" aria-label="Карта маршрутов"></div><div id="mapStatus" role="status" hidden></div><a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer" style="position:absolute;right:10px;bottom:8px;z-index:4;font-size:10px;font-weight:700;color:#53647A;background:#FFFFFFDD;border:1px solid #D3DCE6;border-radius:8px;padding:4px 7px">© OpenStreetMap contributors</a>'
Swap '(?m)^ +const mercLat=.*\r?\n +const invMerc=.*\r?\n' ''
Swap '(?ms)^// ---- map\r?\n.*?(?=^function selectRoute)' ($map+"`n")
Swap '(?m)^ c\.routes\.forEach\(\(r,i\)=>\{r\.i=i;.*\r?\n.*\r?\n  r\.w=w;.*\r?\n' @'
 const byIndex=new Map(GEO[cid].features.map(f=>[f.properties.i,f.geometry]));
 c.routes.forEach((r,i)=>{r.i=i;r.cid=cid;const g=byIndex.get(i);const pts=g.type==='LineString'?g.coordinates:g.coordinates.flat();const w=[],cum=[0];
  pts.forEach(([lon,lat],j)=>{const x=lon*kx,y=-lat;if(j)cum.push(cum[j-1]+Math.hypot((x-w[2*j-2])*111320,(y-w[2*j-1])*110574));w.push(x,y)});
  r.w=w;r.cum=cum;r.L=cum[cum.length-1]||1;
'@
$s=$s.Replace('const p=city(S.city).sw[o.si];V.x=p[0];V.y=p[1];if(V.k<fitK*8)V.k=fitK*8','focusStop(city(S.city),o.si)').Replace('V.x=p[0];V.y=p[1];if(V.k<fitK*6)V.k=fitK*6','focusStop(c,si)')
Swap '(?m)^new ResizeObserver\(\(\)=>\{const first=!W;resize\(\);if\(first\)fitCity\(\)\}\)\.observe\(cv\);\r?\n' ''
$s=$s.Replace('renderAll();requestAnimationFrame(loop);','renderAll();initMap();requestAnimationFrame(loop);').Replace('aria-label="Весь город"','aria-label="Показать маршрут или город целиком"').Replace('© OpenStreetMap contributors</a>','© OpenStreetMap contributors</a> · <a href="https://carto.com/attributions" target="_blank" rel="noopener noreferrer">© CARTO</a></span>').Replace('<a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer" style="','<span style="').Replace('padding:4px 7px">© OpenStreetMap','padding:4px 7px"><a href="https://www.openstreetmap.org/copyright" target="_blank" rel="noopener noreferrer">© OpenStreetMap')
$s=$s.Replace('https://carto.com/attributions','https://openfreemap.org').Replace('© CARTO','OpenFreeMap · © OpenMapTiles').Replace('&lt;/head&gt;','&lt;/head&gt;')
$s=$s.Replace('<style>',@'
<link rel="stylesheet" href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css">
<script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js"></script>
<script src="https://unpkg.com/@maplibre/maplibre-gl-leaflet@0.1.3/leaflet-maplibre-gl.js"></script>
<style>
'@)
[IO.File]::WriteAllText((Join-Path (Get-Location) 'YavEdet-native.html'),$s)
$probe=$s.Replace('renderAll();initMap();requestAnimationFrame(loop);','renderAll();initMap();if(map&&S.city==="msk"){selectRoute(D.msk.routes.findIndex(r=>r.n==="121"),false);$("#sheet").classList.add("min");map.setView([55.86357273637526,37.54829343512087],16,{animate:false});}requestAnimationFrame(loop);')
[IO.File]::WriteAllText((Join-Path (Get-Location) 'YavEdet-dmitrov-check.html'),$probe)
