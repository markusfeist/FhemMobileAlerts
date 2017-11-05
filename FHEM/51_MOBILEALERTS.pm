##############################################
# $Id$
# Written by Markus Feist, 2017
package main;

use strict;
use warnings;

sub
MOBILEALERTS_Initialize($)
{
  my ($hash) = @_;

  $hash->{DefFn}   = "MOBILEALERTS_Define";
  $hash->{UndefFn} = "MOBILEALERTS_Undef";
  $hash->{SetFn}   = "MOBILEALERTS_Set";
  $hash->{AttrFn}  = "MOBILEALERTS_Attr";
  $hash->{ParseFn} = "MOBILEALERTS_Parse";
  $hash->{Match} = "^.*";
  $hash->{AttrList} = "lastMsg:0,1 ". "stateFormat " . "ignore:0,1 " . $readingFnAttributes;  
}

sub
MOBILEALERTS_Define($$)
{
  my ($hash, $def) = @_;
  my ($name, $type, $deviceID) = split("[ \t]+", $def);
  Log 3, "DeviceID $deviceID";
  return "Usage: define <name> MOBILEALERTS <id-12 stellig hex >"
        if($deviceID !~ m/^[0-9a-f]{12}$/);
  $modules{MOBILEALERTS}{defptr}{$deviceID}=$hash;
  $hash->{DeviceID} = $deviceID;
  return undef;
}

sub
MOBILEALERTS_Undef($$)
{
  my ($hash, $name) = @_;
  return undef;
}

sub
MOBILEALERTS_Attr($$$$)
{
	my ( $cmd, $name, $attrName, $attrValue ) = @_;
    
	if ($cmd eq "set") {
		if ($attrName eq "lastMsg") {
			if ( $attrValue !~ /^[01]$/ ) {
				Log3 $name, 3, "MOBILEALERTS ($name) - Invalid parameter attr $name $attrName $attrValue";
				return "Invalid value $attrValue allowed 0,1";
			}
		}
	}
	return undef;
}

sub
MOBILEALERTS_Set ($$@)
{
	my ( $hash, $name, $cmd, @args ) = @_;
  return "\"set $name\" needs at least one argument" unless(defined($cmd));
	
  if($cmd eq "clear") {
    if($args[0] eq "readings") {
        for (keys %{$hash->{READINGS}}) {
          delete $hash->{READINGS}->{$_} if($_ ne 'state');
        }
        return undef;
    } else {
	      return "Unknown value $args[0] for $cmd, choose one of readings";
	  }  
  } else {
		return "Unknown argument $cmd, choose one of clear:readings";
	}
}


sub 
MOBILEALERTS_Parse ($$)
{
	my ( $io_hash, $message) = @_;

  #$deviceID = substr ;
  #$message = pack("H*", $message);
  my ($packageHeader, $timeStamp, $packageLength, $deviceID) = unpack("H2NCH12", $message);

  Log3 $io_hash->{NAME}, 5, "Search for Device ID: " . $deviceID;
  if(my $hash = $modules{MOBILEALERTS}{defptr}{$deviceID}) 
	{
    Log3 $io_hash->{NAME}, 5, "Found Device: " . $hash->{NAME};
	  # Nachricht für $hash verarbeiten
    readingsBeginUpdate($hash);
    my $sub="MOBILEALERTS_Parse_" . substr($deviceID, 0, 2) . "_" . $packageHeader;
    if (defined &$sub) {
      #no strict "refs";
      &{\&$sub}($hash, substr $message, 12, $packageLength - 12);
      #use strict "refs";
    } else {
      Log3 $hash->{NAME}, 2, "For id " . substr($deviceID, 0, 2) . 
                             " and packageHeader $packageHeader is no decoding defined.";
      readingsBulkUpdateIfChanged($hash, "deviceType", "Unknown - " . substr($deviceID, 0, 2) . " " . $packageHeader);
    }
    readingsBulkUpdateIfChanged($hash, "lastRcv", FmtDateTime($timeStamp));
    readingsBulkUpdateIfChanged($hash, "lastMsg", unpack("H*", $message)) if ( AttrVal($hash->{NAME}, "lastMsg", 0) == 1);
    readingsEndUpdate($hash, 1);
    
		# Rückgabe des Gerätenamens, für welches die Nachricht bestimmt ist.
		return $hash->{NAME}; 
	}
  my $res = "UNDEFINED MA_".$deviceID." MOBILEALERTS $deviceID";
  Log3 $io_hash->{NAME}, 5, "Parse return: " . $res;
	return $res;
}

sub
MOBILEALERTS_Parse_02_ce ($$)
{
	my ( $hash, $message) = @_;
  my ( $txCounter, $temperature, $prevTemperature) = unpack("nnn", $message);

  readingsBulkUpdateIfChanged($hash, "txCounter", MOBILEALERTS_decodeTxCounter($txCounter));
  readingsBulkUpdateIfChanged($hash, "triggered", MOBILEALERTS_triggeredTxCounter($txCounter));
  $temperature = MOBILEALERTS_decodeTemperature($temperature);
  readingsBulkUpdateIfChanged($hash, "temperature", $temperature);
  readingsBulkUpdateIfChanged($hash, "temperatureString", MOBILEALERTS_temperatureToString($temperature));
  $prevTemperature = MOBILEALERTS_decodeTemperature($prevTemperature);
  readingsBulkUpdateIfChanged($hash, "prevTemperature", $prevTemperature);
  readingsBulkUpdateIfChanged($hash, "deviceType", "MA10100");
  readingsBulkUpdateIfChanged($hash, "state", "T: " . $temperature);
}

sub
MOBILEALERTS_Parse_03_d2 ($$)
{
	my ( $hash, $message) = @_;
  my ( $txCounter, $temperature, $humidity, $prevTemperature, $prevHumidity) = unpack("nnnnn", $message);

  readingsBulkUpdateIfChanged($hash, "txCounter", MOBILEALERTS_decodeTxCounter($txCounter));
  readingsBulkUpdateIfChanged($hash, "triggered", MOBILEALERTS_triggeredTxCounter($txCounter));
  $temperature = MOBILEALERTS_decodeTemperature($temperature);
  readingsBulkUpdateIfChanged($hash, "temperature", $temperature);
  readingsBulkUpdateIfChanged($hash, "temperatureString", MOBILEALERTS_temperatureToString($temperature));
  $humidity = MOBILEALERTS_decodeHumidity($humidity);
  readingsBulkUpdateIfChanged($hash, "humidity", $humidity);
  readingsBulkUpdateIfChanged($hash, "humidityString", MOBILEALERTS_humidityToString($humidity));
  $prevTemperature = MOBILEALERTS_decodeTemperature($prevTemperature);
  readingsBulkUpdateIfChanged($hash, "prevTemperature", $prevTemperature);
  $prevHumidity = MOBILEALERTS_decodeHumidity($prevHumidity);
  readingsBulkUpdateIfChanged($hash, "prevHumidity", $prevHumidity);
  readingsBulkUpdateIfChanged($hash, "deviceType", "MA10200");
  readingsBulkUpdateIfChanged($hash, "state", "T: " . $temperature . " H: " . $humidity);
}

sub
MOBILEALERTS_Parse_04_d4 ($$)
{
	my ( $hash, $message) = @_;
  my ( $txCounter, $temperature, $humidity, $wetness, 
       $prevTemperature, $prevHumidity , $prevWetness) = unpack("nnnCnnC", $message);

  readingsBulkUpdateIfChanged($hash, "txCounter", MOBILEALERTS_decodeTxCounter($txCounter));
  readingsBulkUpdateIfChanged($hash, "triggered", MOBILEALERTS_triggeredTxCounter($txCounter));
  $temperature = MOBILEALERTS_decodeTemperature($temperature);
  readingsBulkUpdateIfChanged($hash, "temperature", $temperature);
  readingsBulkUpdateIfChanged($hash, "temperatureString", MOBILEALERTS_temperatureToString($temperature));
  $humidity = MOBILEALERTS_decodeHumidity($humidity);
  readingsBulkUpdateIfChanged($hash, "humidity", $humidity);
  readingsBulkUpdateIfChanged($hash, "humidityString", MOBILEALERTS_humidityToString($humidity));
  $wetness = MOBILEALERTS_decodeWetness($wetness);
  readingsBulkUpdateIfChanged($hash, "wetness", $wetness);
  $prevTemperature = MOBILEALERTS_decodeTemperature($prevTemperature);
  readingsBulkUpdateIfChanged($hash, "prevTemperature", $prevTemperature);
  $prevHumidity = MOBILEALERTS_decodeHumidity($prevHumidity);
  $prevWetness = MOBILEALERTS_decodeWetness($prevWetness);
  readingsBulkUpdateIfChanged($hash, "prevWetness", $prevWetness);
  readingsBulkUpdateIfChanged($hash, "prevHumidity", $prevHumidity);
  readingsBulkUpdateIfChanged($hash, "deviceType", "MA10350");
  readingsBulkUpdateIfChanged($hash, "state", "T: " . $temperature . " H: " . $humidity . " " . $wetness);
}

sub
MOBILEALERTS_Parse_07_da ($$)
{
	my ( $hash, $message) = @_;
  my ( $txCounter, $temperatureIn, $humidityIn, $temperatureOut, $humidityOut,
    $prevTemperatureIn, $prevHumidityIn, $prevTemperatureOut, $prevHumidityOut) = 
    unpack("nnnnnnnnn", $message);

  readingsBulkUpdateIfChanged($hash, "txCounter", MOBILEALERTS_decodeTxCounter($txCounter));
  readingsBulkUpdateIfChanged($hash, "triggered", MOBILEALERTS_triggeredTxCounter($txCounter));
  $temperatureIn = MOBILEALERTS_decodeTemperature($temperatureIn);
  readingsBulkUpdateIfChanged($hash, "temperatureIn", $temperatureIn);
  readingsBulkUpdateIfChanged($hash, "temperatureInString", MOBILEALERTS_temperatureToString($temperatureIn));
  $humidityIn = MOBILEALERTS_decodeHumidity($humidityIn);
  readingsBulkUpdateIfChanged($hash, "humidityIn", $humidityIn);
  readingsBulkUpdateIfChanged($hash, "humidityInString", MOBILEALERTS_humidityToString($humidityIn));
  $temperatureOut = MOBILEALERTS_decodeTemperature($temperatureOut);
  readingsBulkUpdateIfChanged($hash, "temperatureOut", $temperatureOut);
  readingsBulkUpdateIfChanged($hash, "temperatureOutString", MOBILEALERTS_temperatureToString($temperatureOut));
  $humidityOut = MOBILEALERTS_decodeHumidity($humidityOut);
  readingsBulkUpdateIfChanged($hash, "humidityOut", $humidityOut);
  readingsBulkUpdateIfChanged($hash, "humidityOutString", MOBILEALERTS_humidityToString($humidityOut));

  readingsBulkUpdateIfChanged($hash, "deviceType", "MA10410");
  readingsBulkUpdateIfChanged($hash, "state", "In T: " . $temperatureIn . " H: " . $humidityIn .
                                              " Out T: " . $temperatureOut . " H: " . $humidityOut);
}

sub
MOBILEALERTS_Parse_08_e1 ($$)
{
	my ( $hash, $message) = @_;
  my @eventTime;
  (my ( $txCounter, $temperature, $eventCounter), @eventTime[0 .. 8]) = 
    unpack("nnnnnnnnnnnn", $message);

  readingsBulkUpdateIfChanged($hash, "txCounter", MOBILEALERTS_decodeTxCounter($txCounter));
  readingsBulkUpdateIfChanged($hash, "triggered", MOBILEALERTS_triggeredTxCounter($txCounter));
  $temperature = MOBILEALERTS_decodeTemperature($temperature);
  readingsBulkUpdateIfChanged($hash, "temperature", $temperature);
  readingsBulkUpdateIfChanged($hash, "temperatureString", MOBILEALERTS_temperatureToString($temperature));
  for (my $z=0; $z<9; $z++) {
    my $eventTimeString = MOBILEALERTS_convertEventTimeString($eventTime[$z], 14);
    $eventTime[$z] = MOBILEALERTS_convertEventTime($eventTime[$z], 14);
    if ($z == 0) {
      readingsBulkUpdateIfChanged($hash, "lastEvent", $eventTime[$z]);
      readingsBulkUpdateIfChanged($hash, "lastEventString", $eventTimeString);
    } else {
      readingsBulkUpdateIfChanged($hash, "lastEvent" . $z, $eventTime[$z]);
      readingsBulkUpdateIfChanged($hash, "lastEvent" . $z . "String", $eventTimeString);
    }
  }
  readingsBulkUpdateIfChanged($hash, "deviceType", "MA10650");
  readingsBulkUpdateIfChanged($hash, "state", "T: " . $temperature . " C: " . $eventCounter);
}

sub
MOBILEALERTS_Parse_0b_e2 ($$)
{
	my ( $hash, $message) = @_;  
  my @dirTable = (  "N","NNE","NE","ENE"
                  , "E","ESE","SE","SSE"
                  , "S","SSW","SW","WSW"
                  , "W","WNW","NW","NNW" );
  my ( $txCounter, $data0, $data1, $data2, $data3) = unpack("NCCCC", "\0".$message);

  my $dir = $data0 >> 4;
  my $overFlowBits = $data0 & 3;
  my $windSpeed = ((($overFlowBits & 2) >> 1) << 8) + $data1 * 0.1;
  my $gustSpeed = ((($overFlowBits & 1) >> 1) << 8) + $data2 * 0.1;
  my $lastTransmit = $data3 * 2;

  readingsBulkUpdateIfChanged($hash, "txCounter", MOBILEALERTS_decodeTxCounter($txCounter));
  readingsBulkUpdateIfChanged($hash, "direction", $dirTable[$dir]);
  readingsBulkUpdateIfChanged($hash, "windSpeed", $windSpeed);
  readingsBulkUpdateIfChanged($hash, "gustSpeed", $gustSpeed);
  readingsBulkUpdateIfChanged($hash, "deviceType", "MA10660");
  readingsBulkUpdateIfChanged($hash, "state", "D: " . $dirTable[$dir] . " W: " . $windSpeed . " G: " . $gustSpeed);
}

sub
MOBILEALERTS_Parse_10_d3 ($$)
{
	my ( $hash, $message) = @_;
  my @data;
  (my ( $txCounter), @data[0..3]) = unpack("nnnnn", $message);

  readingsBulkUpdateIfChanged($hash, "txCounter", MOBILEALERTS_decodeTxCounter($txCounter));
  for (my $z=0;$z<4;$z++) {
    my $eventTimeString = MOBILEALERTS_convertEventTimeString($data[$z], 13);
    my $eventTime = MOBILEALERTS_convertEventTime($data[$z], 13);
    $data[$z] = MOBILEALERTS_convertOpenState($data[$z]);
    
    if ($z == 0) {
      readingsBulkUpdateIfChanged($hash, "state", $data[$z]);
      readingsBulkUpdateIfChanged($hash, "lastEvent", $eventTime);
      readingsBulkUpdateIfChanged($hash, "lastEventString", $eventTimeString);
    } else {
      readingsBulkUpdateIfChanged($hash, "state" . $z, $data[$z]);
      readingsBulkUpdateIfChanged($hash, "lastEvent" . $z, $eventTime);
      readingsBulkUpdateIfChanged($hash, "lastEvent" . $z . "String", $eventTimeString);
    }    
  }
  readingsBulkUpdateIfChanged($hash, "deviceType", "MA10800");
}

sub
MOBILEALERTS_Parse_12_d9 ($$)
{
	my ( $hash, $message) = @_;
  my ( $txCounter, $humidity3h, $humidity24h, $humidity7d, $humidity30d, $temperature, $humidity) =
    unpack("nCCCCnC", $message);

  readingsBulkUpdateIfChanged($hash, "txCounter", MOBILEALERTS_decodeTxCounter($txCounter));
  readingsBulkUpdateIfChanged($hash, "triggered", MOBILEALERTS_triggeredTxCounter($txCounter));
  $temperature = MOBILEALERTS_decodeTemperature($temperature);
  readingsBulkUpdateIfChanged($hash, "temperature", $temperature);
  readingsBulkUpdateIfChanged($hash, "temperatureString", MOBILEALERTS_temperatureToString($temperature));
  $humidity = MOBILEALERTS_decodeHumidity($humidity);
  readingsBulkUpdateIfChanged($hash, "humidity", $humidity);
  readingsBulkUpdateIfChanged($hash, "humidityString", MOBILEALERTS_humidityToString($humidity));
  $humidity3h = MOBILEALERTS_decodeHumidity($humidity3h);
  readingsBulkUpdateIfChanged($hash, "humidity3h", $humidity3h);
  readingsBulkUpdateIfChanged($hash, "humidity3hString", MOBILEALERTS_humidityToString($humidity3h));
  $humidity24h = MOBILEALERTS_decodeHumidity($humidity24h);
  readingsBulkUpdateIfChanged($hash, "humidity24h", $humidity3h);
  readingsBulkUpdateIfChanged($hash, "humidity24hString", MOBILEALERTS_humidityToString($humidity24h));
  $humidity7d = MOBILEALERTS_decodeHumidity($humidity7d);
  readingsBulkUpdateIfChanged($hash, "humidity7d", $humidity7d);
  readingsBulkUpdateIfChanged($hash, "humidity7dString", MOBILEALERTS_humidityToString($humidity7d));
  $humidity30d = MOBILEALERTS_decodeHumidity($humidity30d);
  readingsBulkUpdateIfChanged($hash, "humidity30d", $humidity30d);
  readingsBulkUpdateIfChanged($hash, "humidity30dString", MOBILEALERTS_humidityToString($humidity30d));
  readingsBulkUpdateIfChanged($hash, "deviceType", "MA10230");
  readingsBulkUpdateIfChanged($hash, "state", "T: " . $temperature . " H: " . $humidity . " " 
    . $humidity3h . "/" . $humidity24h . "/" . $humidity7d . "/" . $humidity30d);
}

sub
MOBILEALERTS_Parse_06_d6 ($$)
{
        my ( $hash, $message) = @_;
  my ( $txCounter, $temperatureIn, $temperatureOut, $humidityIn, $prevTemperatureIn, $prevTemperatureOut, $prevHumidityIn) = unpack("nnnnnnn", $message);

  readingsBulkUpdateIfChanged($hash, "txCounter", MOBILEALERTS_decodeTxCounter($txCounter));
  readingsBulkUpdateIfChanged($hash, "triggered", MOBILEALERTS_triggeredTxCounter($txCounter));
  $temperatureIn = MOBILEALERTS_decodeTemperature($temperatureIn);
  readingsBulkUpdateIfChanged($hash, "temperatureIn", $temperatureIn);
  readingsBulkUpdateIfChanged($hash, "temperatureStringIn", MOBILEALERTS_temperatureToString($temperatureIn));
  $temperatureOut = MOBILEALERTS_decodeTemperature($temperatureOut);
  readingsBulkUpdateIfChanged($hash, "temperatureOut", $temperatureOut);
  readingsBulkUpdateIfChanged($hash, "temperatureStringOut", MOBILEALERTS_temperatureToString($temperatureOut));
  $humidityIn = MOBILEALERTS_decodeHumidity($humidityIn);
  readingsBulkUpdateIfChanged($hash, "humidity", $humidityIn);
  readingsBulkUpdateIfChanged($hash, "humidityString", MOBILEALERTS_humidityToString($humidityIn));
  $prevTemperatureIn = MOBILEALERTS_decodeTemperature($prevTemperatureIn);
  readingsBulkUpdateIfChanged($hash, "prevTemperatureIn", $prevTemperatureIn);
  $prevTemperatureOut = MOBILEALERTS_decodeTemperature($prevTemperatureOut);
  readingsBulkUpdateIfChanged($hash, "prevTemperatureOut", $prevTemperatureOut);
  $prevHumidityIn = MOBILEALERTS_decodeHumidity($prevHumidityIn);
  readingsBulkUpdateIfChanged($hash, "prevHumidityIn", $prevHumidityIn);
  readingsBulkUpdateIfChanged($hash, "deviceType", "MA10300/MA10700");
  readingsBulkUpdateIfChanged($hash, "state", "In T: " . $temperatureIn . " H: " . $humidityIn . 
                                              " Out T: " . $temperatureOut);
}

sub
MOBILEALERTS_decodeTxCounter($)
{
  my ($txCounter) = @_;
  return $txCounter & 0x3FFF;
}

sub
MOBILEALERTS_triggeredTxCounter($)
{
  my ($txCounter) = @_;
  if ( ($txCounter & 0x4000) == 0x4000) {
    return 1;
  }
  return 0;
}

sub
MOBILEALERTS_decodeTemperature($)
{
  my ($temperature) = @_;

  #Overflow
  return 9999 if ( ($temperature & 0x2000) == 0x2000);
  #Illegal value
  return -9999 if ( ($temperature & 0x1000) == 0x1000);
  #Negativ Values  
  return (0x800 - ($temperature & 0x7ff)) * 0.1 if ( ($temperature & 0x400) == 0x400);
  #Positiv Values
  return ($temperature & 0x7ff) * 0.1;
}

sub
MOBILEALERTS_temperatureToString($)
{
  my ($temperature) = @_;
  return "---" if ($temperature < -1000);
  return "OLF" if ($temperature > 1000);
  return $temperature . "°C";
}

sub
MOBILEALERTS_decodeHumidity($)
{
  my ($humidity) = @_;
  return 9999 if (($humidity & 0x80) == 0x80);
  return $humidity & 0x7F;
}

sub
MOBILEALERTS_humidityToString($)
{
  my ($humidity) = @_;
  return "---" if ($humidity > 1000);
  return $humidity . "%";
}

sub
MOBILEALERTS_decodeWetness($)
{
  my ($wetness) = @_;

  return "dry" if ($wetness & 0x01);
  return "wet";
}

sub
MOBILEALERTS_convertOpenState($)
{
  my ($value) = @_;
  return "open" if ($value & 0x8000);
  return "closed";
}

sub
MOBILEALERTS_convertEventTime($$)
{
  my ($value, $timeScaleBitOffset) = @_;
  my $timeScaleFactor =  ($value >> $timeScaleBitOffset) & 3;
  $value = $value & ((1 << $timeScaleBitOffset) - 1);
  if($timeScaleFactor == 0) {       # days
    return $value * 60 * 60 * 24;
  } elsif($timeScaleFactor == 1) {  # hours
    return $value * 60 * 60;
  } elsif($timeScaleFactor == 2) {  # minutes
    return $value * 60;
  } elsif($timeScaleFactor == 3) {  # seconds
    return $value;
  }
}

sub
MOBILEALERTS_convertEventTimeString($$)
{
  my ($value, $timeScaleBitOffset) = @_;
  my $timeScaleFactor =  ($value >> $timeScaleBitOffset) & 3;
  $value = $value & ((1 << $timeScaleBitOffset) - 1);
  if($timeScaleFactor == 0) {       # days
    return $value . " d";
  } elsif($timeScaleFactor == 1) {  # hours
    return $value . " h";
  } elsif($timeScaleFactor == 2) {  # minutes
    return $value . " m";
  } elsif($timeScaleFactor == 3) {  # seconds
    return $value . " s";
  }
}

# Eval-Rückgabewert für erfolgreiches
# Laden des Moduls
1;

=pod
=item device
=item summary    virtual device for MOBILEALERTSGW
=item summary_DE virtuelles device für MOBILEALERTSGW
=begin html

<a name="MOBILEALERTS"></a>
<h3>MOBILEALERTS</h3>
<ul>
  The MOBILEALERTS is a fhem module for the german MobileAlerts devices.
  <br><br>
  The fhem module represents a MobileAlerts device. The connection is provided by the <a href="#MOBILEALERTSGW">MOBILELAERTSGW</a> module.
  Currently supported: MA10100, MA10200, MA10230, MA10300, MA10410.<br>
  Supported but untested: MA10350, MA10650, MA10660, MA10700, MA10800<br>
  <br>

  <a name="MOBILEALERTSdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; MOBILEALERTS &lt;deviceID&gt;</code><br>
    <br>
    deviceID is the sensorcode on the sensor.
  </ul>
  <br>

  <a name="MOBILEALERTSset"></a>
  <b>Set</b>
  <ul>
    <li><code>set &lt;name&gt; clear &lt;readings&gt;</code><br>
    Clears the readings. </li>
  </ul>
  <br>

  <a name="MOBILEALERTSget"></a>
  <b>Get</b>
  <ul>
  N/A
  </ul>
  <br>
  <br>

  <a name="MOBILEALERTSattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#ignore">ignore</a></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>  
    <li><a href="#MOBILEALERTSlastMsg">lastMsg</a><br>
      If value 1 is set, the last received message will be logged as reading.
    </li>
  </ul>
</ul>

=end html
=begin html_DE

<a name="MOBILEALERTS"></a>
<h3>MOBILEALERTS</h3>
<ul>
  MOBILEALERTS ist ein FHEM-Modul f&uuml; die deutschen MobileAlerts Ger&auml;.
  <br><br>
  Dieses FHEM Modul stellt jeweils ein MobileAlerts Ger&auml;t dar. Die Verbindung wird durch das 
  <a href="#MOBILEALERTSGW">MOBILELAERTSGW</a> Modul bereitgestellt.<br>
  Aktuell werden unterst&uuml;zt: MA10100, MA10200, MA10230, MA10300, MA10410.<br>
  Unterst&uuml;zt aber ungetestet: MA10350, MA10650, MA10660, MA10700, MA10800<br>
  <br>

  <a name="MOBILEALERTSdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; MOBILEALERTS &lt;deviceID&gt;</code><br>
    <br>
    deviceID ist der Sensorcode auf dem Sensor.
  </ul>
  <br>

  <a name="MOBILEALERTSset"></a>
  <b>Set</b>
  <ul>
    <li><code>set &lt;name&gt; clear &lt;readings&gt;</code><br>
    L&ouml;scht die Readings. </li>
  </ul>
  <br>

  <a name="MOBILEALERTSget"></a>
  <b>Get</b>
  <ul>
  N/A
  </ul>
  <br>
  <br>

  <a name="MOBILEALERTSattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#ignore">ignore</a></li>
    <li><a href="#readingFnAttributes">readingFnAttributes</a></li>  
    <li><a href="#MOBILEALERTSlastMsg">lastMsg</a><br>
      Wenn dieser Wert auf 1 gesetzt ist, wird die letzte erhaltene Nachricht als Reading gelogt.
    </li>
  </ul>
</ul>

=end html_DE
=cut
