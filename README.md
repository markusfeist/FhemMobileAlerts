# FhemMobileAlerts
Ein Modul für FHEM für die ELV Mbolie Alerts Senosren.

## Mobile Alerts
Die Komponeten werden von [ELV](https://www.elv.de/ip-wettersensoren-system.html) in Deutschland verkauft. ACHTUNG: Es gibt anscheinend Mobile Alerts Sensoren aus den USA. Diese sind mit diesem Modul nicht kompatibel.
Dokumentation zum Protokoll finden Sie in diesem [Github Repository](https://github.com/sarnau/MMMMobileAlerts).

## Funktionsweise
Die generelle Funktionsweise ist soweit von diesem [Python Programm](https://github.com/sarnau/MMMMobileAlerts/tree/master/maserver) abgeleitet. Das Modul stellt einen Proxyserver bereit, der die Nachrichten vom Gateway abfängt und auswertet. Zusätzlich werden Funktionen zur Konfiguration des Gateways bereitgestellt.
Der Hauptgrund, warum ich dieses Modul geschrieben habe, war, dass ich auf meinem FHEM-Server wenig Resourcen habe, nicht einen MQTT, Python-Server bereitstellen wollte und mehrere Module für einen Sensor einrichten wollte.

## Unterstütze Module
Aktuell sind unterstützt und von mir getestet:
MA10100, MA10200, MA10230, MA10300

Von jemanden anderen getestet:
MA10410

Nur unterstützt (aber nicht getestet):
MA10350, MA10650, MA10660, MA10700, MA10800

## Installation
### Modul
Die Installation des Moduls erfolgt, indem man die beiden Dateien 50_MOBILEALERTSGW.pm und 51_MOBILEALERTS.pm in den Ordner FHEM der FHEM Installtion einfügt.
Das Modul legt man dann im FHEM mit dem Befehl
```
define <Name> MOBILEALERTSGW <Port>
```
Also z.B.:
```
define MobileAlertsGW MOBILEALERTSGW 8090
```
Der Port muss natürlich auf dem Server frei sein.

Ein Parmeter der noch gesetzt werden kann ist `forward` dieser ermöglicht, wenn auf `1` gesetzt, die abgefangenen Daten an den MobileAlerts Server zu senden. Damit werden die Daten weiterhin in der MobileAlerts-APP angeboten.
Man setzt den Parameter mit:
```
attr <Name> forward 1
```
Wenn `forward` nicht gesetzt (standard) oder mit `0` belegt ist, werden die Daten von der "MobileAlerts Cloud" ferngehalten.

### Konfiguration Gateway
Das Gateway muss so konfiguriert sein, dass der FHEM Server als Proxyserver genutzt wird. Dazu kann die MobileAlerts APP genutzt werden.

Alternativ kann auch das Modul dafür genutzt werden.
Dazu ist zunächst mit
```
get <Name-GatewayModul> config
```
(Name-GatewayModul ist der Name des Moduls MOBILEALERTSGW. Also zum Beispiel oben "MobileAlertsGW".)
Nach den Gateways zu suchen. Es sollten alle Gateways im lokalen LAN auftauchen. Sollte dies nicht der Fall sein (z.B. weil das Gateway in einem anderen Netzsegment ist), kann mit
```
get <Name-GatewayModul> config <IP-Adresse>
```
direkt nach einer IP-Adresse gesucht werden.
Nach dem Aufruf (und Neuladen der Anzeige in FHEM zum Modul), sollten Informationen zum Gateway in den Readings auftauchen.
Mit
```
set <Name-GatewayModul> initgateway <GatewayId>
```
kann das Gateway dann konfiguriert werden.
Die GatewayId kann im Reading Gateways ausgelesen werden.
Ggf. ist ein Reboot des Gateways nötig. Dazu kann der Befehl:
```
set <Name-GatewayModul> rebootgateway <GatewayId>
```
genutzt werden.
Zum Abschluss sollte mit:
```
get <Name-GatewayModul> config
```
die Konfiguration noch einmal eingelesen werden.

Ein Fall der so (noch) nicht konfiguriert werden kann, ist wenn das Gateway in einem anderen Netzsegment ist und der mit FHEM-Server eingerichtete Proxy-Server nur über ein auf einem Router freigeschalteten Port erreicht werden kann. Hier muss man weiterhin die APP-nutzen.

### Module für die Geräte
Die Geräte werden automatisch erkannt, sobald das Gateway des Gerätes an den Proxyserver sendet. Es wird dann im Raum MOBILEALERTS ein entsprechender Eintrag angelegt.

Leider werden die Daten nicht direkt nach dem Anlegen angezeigt, sondern erst bei der zweiten Meldung. Also wird das Gerät zunächst mit einem Status `???` angezeigt, dann unter Umständen erst 10 Minuten später mit dem richtigen Wert.

Es gibt lediglich ein besonderes Attribut hier `lastMsg`. Wird dieses auf `1` gesetzt, wird im Reading `lastMsg` die letzte empfangene Nachricht protokolliert. Diese wird benötigt, um ggf. Fehler in der Anzeige oder neue Geräte zu decodieren.

Die Geräte können mit normalen FHEM Mitteln entsprechend in der Anzeige angepasst werden.
Kleine Anregungen für Einstellungen von mir:
```
attr <Modul-Name> alias Temperatur
attr <Modul-Name> group Heizung und Klima
attr <Modul-Name> icon temp_temperature
attr <Modul-Name> stateFormat temperatureString
```
Und ein Readings-Proxy für die Luftfeuchte:
```
define <RP-Name> readingsProxy  	
<Modul-Name>:humidityString
attr <RP-Name> alias Luftfeuchte
attr <RP-Name> group Heizung und Klima
attr <RP-Name> icon humidity
```

## Fehlerbehandlung
Sollten generelle Probleme mit dem Modul auftauschen, brauche ich für eine Fehleranlyse das FHEM-Protokoll. Ggf. mit Loglevel 4 oder 5.

Sollte lediglich ein Geräte nicht richtig angezeigt werden oder ein neues Gerät hinzugefügt werden, dann benötige ich:
* Den Inhalt des Readings `lastMsg` (vorher mit dem Attribut `lastMsg` aktivieren.)
* Den Inhalt des Readings `deviceType`.
* Wenn es ein bisher nicht bekanntes Gerät ist, die Geräteart (z.B. MA10200) und Gerätebezeichnung (z.B. Thermo/hygrometer Sensor)
* Die Werte, die die Mobile-Alerts App anzeigt, (dazu das Attribut `forward` am Gateway auf `1` stellen) oder den Wert vom Gerät ablesen.

## Offene Punkte
Folgende Punkte sind noch offen, bzw. bekannte Fehler:
* Es wird kein Batteriestatus ausgegeben. (Leider ist noch unbekannt, wie dieser in die Nachrichten kodiert sind). Wenn dies jemand von ELV liest. Ich wäre für einen Tip dankbar.
* Das Modul hat nach dem automatsichen Anlegen zunächst den Status `???`. Dies korrigiert sich aber der zweiten Nachricht.

##Lizenz
Ich veröffentliche hier die FHEM Module unter der GPL V2 siehe auch [LICENSE](LICENSE).