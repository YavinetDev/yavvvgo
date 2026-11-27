param([switch]$Export)
$ErrorActionPreference='Stop'
$root='E:\экотранспорт явинет'
$p=Join-Path $root 'прототипы\ЯвьЕдет — прототип — фильтрация МО.html'
$s=[IO.File]::ReadAllText($p)
$d=([regex]::Match($s,'(?m)^const D=(.*);\r?$').Groups[1].Value)|ConvertFrom-Json
$result=@{}
foreach($f in Get-ChildItem -LiteralPath "$root\Новая папка" -Filter *.geojson){
 $id=switch -Regex ($f.Name){'Энгельс'{'eng'} 'ижевска'{'izh'} 'Твери'{'tver'} 'СПб'{'spb'} 'явьэлектротранс'{'msk'}}
 $j=[IO.File]::ReadAllText($f.FullName)|ConvertFrom-Json
 $features=@($j.features|Where-Object {$_.geometry.type -in 'LineString','MultiLineString'})
 $lookup=@{}
 for($fi=0;$fi -lt $features.Count;$fi++){
  $ftr=$features[$fi]
  if($ftr.geometry.type -eq 'LineString'){$parts=,($ftr.geometry.coordinates)}else{$parts=$ftr.geometry.coordinates}
  foreach($part in $parts){foreach($pt in $part){
   if($pt[0] -lt 25 -or $pt[0] -gt 60 -or $pt[1] -lt 50 -or $pt[1] -gt 62){throw 'Unexpected CRS / coordinate order'}
   $key="$( [math]::Round($pt[1]*1e5) ),$( [math]::Round($pt[0]*1e5) )"
   if(!$lookup.ContainsKey($key)){$lookup[$key]=[Collections.Generic.HashSet[int]]::new()}
   [void]$lookup[$key].Add($fi)
  }}
 }
 $list=[Collections.Generic.List[object]]::new(); $missing=@(); $i=-1
 foreach($r in $d.$id.routes){$i++; $lat=0;$lon=0;$votes=@{}; for($k=0;$k -lt $r.l.Count;$k+=2){$lat+=$r.l[$k];$lon+=$r.l[$k+1]; foreach($idx in $lookup["$lat,$lon"]){$votes[$idx]=1+$votes[$idx]}}
  $best=@($votes.GetEnumerator()|Sort-Object Value -Descending|Select-Object -First 2)
  if(!$best.Count -or $best[0].Value -lt 4 -or ($best.Count -gt 1 -and $best[0].Value -eq $best[1].Value)){ $missing+= "$i/$($r.n)/$($r.t)";continue }
  $ftr=$features[$best[0].Key]; $list.Add(@{type='Feature';properties=@{i=$i};geometry=$ftr.geometry})
 }
 $result[$id]=@{type='FeatureCollection';features=$list}; "$id parsed=$($features.Count) matched=$($list.Count) missing=$($missing -join ' ')"
}
if($Export){$json=ConvertTo-Json -InputObject $result -Depth 15 -Compress; [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'map-data.json'),$json)}
