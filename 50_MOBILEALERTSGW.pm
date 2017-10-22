##############################################
# $Id$
# Written by Markus Feist, 2017
package main;

use strict;
use warnings;
use TcpServerUtils;
use HttpUtils;

use constant MA_PACKAGE_LENGTH => 64;

my $MA_wname;
my $MA_chash;
my $MA_cname;
my @MA_httpheader;
my %MA_httpheader;

sub
MOBILEALERTSGW_Initialize($)
{
  my ($hash) = @_;

  $hash->{ReadFn}  = "MOBILEALERTSGW_Read";
  #$hash->{GetFn}   = "MOBILEALERTSGW_Get";
  $hash->{SetFn}   = "MOBILEALERTSGW_Set";
  $hash->{AttrFn}  = "MOBILEALERTSGW_Attr";
  $hash->{DefFn}   = "MOBILEALERTSGW_Define";
  $hash->{UndefFn} = "MOBILEALERTSGW_Undef";
  $hash->{Clients} = "MOBILEALERTS";
  $hash->{MatchList} = { "1:MOBILEALERTS"      => "^.*" };
  $hash->{Write} = "MOBILEALERTSGW_Write";
  $hash->{FingerprintFn} = "MOBILEALERTSGW_Fingerprint";
  #$hash->{NotifyFn}= ($init_done ? "FW_Notify" : "FW_SecurityCheck");
  #$hash->{AsyncOutputFn} = "MOBILEALERTSGW_AsyncOutput";
  #$hash->{ActivateInformFn} = "MOBILEALERTSGW_ActivateInform";
  $hash->{AttrList} = "forward:0,1 " . $readingFnAttributes);
}

sub
MOBILEALERTSGW_Define($$)
{
  my ($hash, $def) = @_;
  my ($name, $type, $port) = split("[ \t]+", $def);
  return "Usage: define <name> MOBILEALERTSGW <tcp-portnr>"
        if($port !~ m/^\d+$/);

  my $ret = TcpServer_Open($hash, $port, "global");

  return $ret;
}

sub
MOBILEALERTSGW_Set ($$@)
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
MOBILEALERTSGW_Undef($$)
{
  my ($hash, $name) = @_;
  my $ret = TcpServer_Close($hash);
  return $ret;
}

sub
MOBILEALERTSGW_Attr($$$$)
{
	my ( $cmd, $name, $attrName, $attrValue ) = @_;
    
	if ($cmd eq "set") {
		if ($attrName eq "forward") {
			if ( $attrValue !~ /^[01]$/ ) {
				Log3 $name, 3, "MOBILEALERTSGW ($name) - Invalid parameter attr $name $attrName $attrValue";
				return "Invalid value $attrValue allowed 0,1";
			}
		}
	}
	return undef;
}

sub 
MOBILEALERTSGW_Fingerprint($$$)
{
	my ( $io_name, $message ) = @_;
  #PackageHeader + UTC Timestamp + Package Length + Device ID + tx counter (3 bytes)
  my $fingerprint = unpack("H30", $message);
	return ( $io_name, $fingerprint );
}

sub 
MOBILEALERTSGW_Write ($$)
{
  #Dummy, because it is not possible to send to device.
	my ( $hash, @arguments) = @_;
	return undef;
}

sub MOBILEALERTSGW_Read($$);

sub
MOBILEALERTSGW_Read($$)
{
  my ($hash, $reread) = @_;
  my $name = $hash->{NAME};
  my $verbose = GetVerbose($name);

  if($hash->{SERVERSOCKET}) {   # Accept and create a child
    my $nhash = TcpServer_Accept($hash, "MOBILEALERTSGW");
    return if(!$nhash);
    my $wt = AttrVal($name, "alarmTimeout", undef);
    $nhash->{ALARMTIMEOUT} = $wt if($wt);
    $nhash->{CD}->blocking(0);
    return;
  }

  $MA_chash = $hash;
  $MA_wname = $hash->{SNAME};
  $MA_cname = $name;
  #$FW_subdir = "";

  my $c = $hash->{CD};

  if(!$reread) {
    # Data from HTTP Client
    my $buf;
    my $ret = sysread($c, $buf, 1024);

    if(!defined($ret) && $! == EWOULDBLOCK ){
      $hash->{wantWrite} = 1
        if(TcpServer_WantWrite($hash));
      return;
    } elsif(!$ret) { # 0==EOF, undef=error
      CommandDelete(undef, $name);
      Log3 $MA_wname, 4, "Connection closed for $name: ".
                  (defined($ret) ? 'EOF' : $!);
      return;
    }
    $hash->{BUF} .= $buf;
  }

  if(!$hash->{HDR}) {
    return if($hash->{BUF} !~ m/^(.*?)(\n\n|\r\n\r\n)(.*)$/s);
    $hash->{HDR} = $1;
    $hash->{BUF} = $3;
    if($hash->{HDR} =~ m/Content-Length:\s*([^\r\n]*)/si) {
      $hash->{CONTENT_LENGTH} = $1;
    }
  }

  @MA_httpheader = split(/[\r\n]+/, $hash->{HDR});
  %MA_httpheader = map {
                         my ($k,$v) = split(/: */, $_, 2);
                         $k =~ s/(\w+)/\u$1/g; # Forum #39203
                         $k=>(defined($v) ? $v : 1);
                       } @MA_httpheader;  

  my $POSTdata = "";
  if($hash->{CONTENT_LENGTH}) {
    return if(length($hash->{BUF})<$hash->{CONTENT_LENGTH});
    $POSTdata = substr($hash->{BUF}, 0, $hash->{CONTENT_LENGTH});
    $hash->{BUF} = substr($hash->{BUF}, $hash->{CONTENT_LENGTH});
  }
  delete($hash->{HDR});
  if ($verbose >= 5) {
    Log3 $MA_wname, 5, "Headers: " . join(", ", @MA_httpheader) ;
    Log3 $MA_wname, 5, "Receivebuffer: " . unpack("H*", $POSTdata) if ($verbose >= 5);
  }

  my ($method, $url, $httpvers) = split(" ", $MA_httpheader[0], 3)
        if($MA_httpheader[0]);
  $method = "" if(!$method);
  #if($method !~ m/^(GET|POST)$/i){
  if($method !~ m/^(PUT|POST)$/i){    
    TcpServer_WriteBlocking($MA_chash,
      "HTTP/1.1 405 Method Not Allowed\r\n" .
      "Content-Length: 0\r\n\r\n");
    delete $hash->{CONTENT_LENGTH};
    MOBILEALERTSGW_Read($hash, 1) if($hash->{BUF});
   Log3 $MA_wname, 3, "$MA_cname: unsupported HTTP method $method, rejecting it.";
    MOBILEALERTSGW_closeConn($hash);
    return;
  } 

  if($url !~ m/.*\/gateway\/put$/i) {
    TcpServer_WriteBlocking($MA_chash,
      "HTTP/1.1 400 Bad Request\r\n" .
      "Content-Length: 0\r\n\r\n");
    delete $hash->{CONTENT_LENGTH};
    MOBILEALERTSGW_Read($hash, 1) if($hash->{BUF});
    Log3 $MA_wname, 3, "$MA_cname: unsupported URL $url, rejecting it.";
    MOBILEALERTSGW_closeConn($hash);
    return;  
  }
  if (! exists $MA_httpheader{"HTTP_IDENTIFY"}) {
    TcpServer_WriteBlocking($MA_chash,
      "HTTP/1.1 400 Bad Request\r\n" .
      "Content-Length: 0\r\n\r\n");
    delete $hash->{CONTENT_LENGTH};
    MOBILEALERTSGW_Read($hash, 1) if($hash->{BUF});
    Log3 $MA_wname, 3, "$MA_cname: not Header http_identify, rejecting it.";
    MOBILEALERTSGW_closeConn($hash);
    return;  
  }
  Log3 $MA_wname, 5, "Header HTTP_IDENTIFY" . $MA_httpheader{"HTTP_IDENTIFY"};
  my ($gwserial, $gwmac, $actioncode) = split(/:/, $MA_httpheader{"HTTP_IDENTIFY"}); 
  readingsSingleUpdate($defs{$MA_wname}, "GW_" . $gwserial . "_lastSeen", TimeNow(), 1);
  if ($actioncode eq "00") {
    Log3 $MA_wname, 4, "$MA_cname: Initrequest from $gwserial $gwmac";
    MOBILEALERTSGW_DecodeInit($hash, $POSTdata);
    MOBILEALERTSGW_DefaultAnswer($hash);
  } elsif ($actioncode eq "C0") {
    Log3 $MA_wname, 4, "$MA_cname: Data from $gwserial $gwmac";
    MOBILEALERTSGW_DecodeData($hash, $POSTdata);
    MOBILEALERTSGW_DefaultAnswer($hash);
  } else {
    TcpServer_WriteBlocking($MA_chash,
      "HTTP/1.1 400 Bad Request\r\n" .
      "Content-Length: 0\r\n\r\n");
    delete $hash->{CONTENT_LENGTH};
    MOBILEALERTSGW_Read($hash, 1) if($hash->{BUF});
    Log3 $MA_wname, 3, "$MA_cname: unknown Actioncode $actioncode";
    Log3 $MA_wname, 4, "$MA_cname: unknown Actioncode $actioncode Postdata: " . unpack("H*", $POSTdata);
    MOBILEALERTSGW_closeConn($hash);
    return;     
  }
  MOBILEALERTSGW_closeConn($hash); #No Keep-Alive

  #Send to Server
  if ( AttrVal($MA_wname, "forward", 0) == 1) {
    my $httpparam = {
      url => "http://www.data199.com/gateway/put",
      timeout => 20,
      httpversion => "1.1",
      hash => $hash,
      method => "PUT",
      header => "HTTP_IDENTIFY: " . $MA_httpheader{"HTTP_IDENTIFY"} . "\r\nContent-Type: application/octet-stream",
      data => $POSTdata,
      callback => \&MOBILEALERTSGW_NonblockingGet_Callback
    };
    HttpUtils_NonblockingGet($httpparam);
  }
  return;
}

sub
MOBILEALERTSGW_NonblockingGet_Callback($$$) 
{
  my ($param, $err, $data) = @_;
  my $hash = $param ->{hash};
  my $code = $param->{code};
  Log3 $hash->{NAME}, 3, "Callback";
  if ($err ne "") {
    Log3 $hash->{NAME}, 3, "error while forward request to " . $param->{url} . " - $err";
  } elsif ($code != 200) {
    Log3 $hash->{NAME}, 3, "http-error while forward request to " . $param->{url} . " - " . $param->{code};
    Log3 $hash->{NAME}, 5, "http-header: " . $param->{httpheader};
    Log3 $hash->{NAME}, 5, "http-data: " . $data;
  } else {
    Log3 $hash->{NAME}, 5, "forward successfull";
    Log3 $hash->{NAME}, 5, "http-header: " . $param->{httpheader};
    Log3 $hash->{NAME}, 5, "http-data: " . unpack("H*", $data);
  }
  HttpUtils_Close($param);
}

sub
MOBILEALERTSGW_closeConn($)
{
  my ($hash) = @_;
  # Kein Keep-Alive noetig
  TcpServer_Close($hash, 1);
}

sub
MOBILEALERTSGW_DefaultAnswer($)
{
  my ($hash) = @_;
  my $buf;

  $buf= pack("NxxxxNxxxxNN",420,time,0x1761D480,15);

  TcpServer_WriteBlocking($MA_chash,
    "HTTP/1.1 200 OK\r\n" .
    "Content-Type: application/octet-stream\r\n" .
    "Content-Length: 24\r\n\r\n".
    $buf);
}

sub
MOBILEALERTSGW_DecodeInit($$)
{
  my ($hash, $POSTdata) = @_;
  my ($packageLength, $upTime, $ID, $unknown1, $unknown50) =
    unpack("CNH12nn", $POSTdata);

  Log3 $MA_wname, 4, "Uptime (s): " . $upTime . " ID: " . $ID;
}

sub
MOBILEALERTSGW_DecodeData($$)
{
  my ($hash, $POSTdata) = @_;  
  my $verbose = GetVerbose($MA_wname);

  for (my $pos = 0; $pos < length($POSTdata); $pos += MA_PACKAGE_LENGTH) {
    my $data = substr $POSTdata, $pos, MA_PACKAGE_LENGTH;
    my ($packageHeader, $timeStamp, $packageLength, $deviceID) = unpack("CNCH12", $data);    
    Log3 $MA_wname, 4, "PackageHeader: " . $packageHeader . 
                       " Timestamp: " . scalar(localtime($timeStamp)) .
                       " PackageLength: " . $packageLength .
                       " DeviceID: " . $deviceID;
    Log3 $MA_wname, 5, "Data $deviceID: " . unpack("H*", $data) if ($verbose >= 5);
    my $found = Dispatch($defs{$MA_wname}, $data, undef);
  }
}

# Eval-Rückgabewert für erfolgreiches
# Laden des Moduls
1;

=pod
=item device
=item summary    IO device for german MobileAlerts
=item summary_DE IO device für deutsche MobileAlets
=begin html

<a name="MOBILEALERTSGW"></a>
<h3>MOBILEALERTSGW</h3>
<ul>
  The MOBILEALERTSGW is a fhem module for the german MobileAlerts Gateway.
  <br><br>
  The fhem module makes simulates as http-proxy to intercept messages from the gateway.
  In order to use this module you need to configure the gateway to use the fhem-server with the defined port as proxy.
  It automatically detects devices. The other devices are handled by the <a href="#MOBILEALERTS">MOBILELAERTS</a> module,
  which uses this module as its backend.<br>
  <br>

  <a name="MOBILEALERTSGWdefine"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; MOBILEALERTSGW &lt;port&gt;</code><br>
    <br>
    port is the port where the proxy server listens. The port must be free.
  </ul>
  <br>

  <a name="MOBILEALERTSGWset"></a>
  <b>Set</b>
  <ul>
    <li><code>set &lt;name&gt; clear &lt;readings&gt;</code><br>
    Clears the readings. </li>
  </ul>
  <br>

  <a name="MOBILEALERTSGWget"></a>
  <b>Get</b>
  <ul>
  N/A
  </ul>
  <br>
  <br>

  <a name="MOBILEALERTSGWattr"></a>
  <b>Attributes</b>
  <ul>
    <li><a href="#loglevel">loglevel</a></li>
    <li><a href="#MOBILEALERTSGWforward">forward</a><br>
      If value 1 is set, the data will be forwarded to the MobileAlerts Server http://www.data199.com/gateway/put .
    </li>
  </ul>
</ul>

=end html
=cut