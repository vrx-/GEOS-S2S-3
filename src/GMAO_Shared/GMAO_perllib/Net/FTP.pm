# Net::FTP.pm
#
# Copyright (c) 1995-8 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Documentation (at end) improved 1996 by Nathan Torkington <gnat@frii.com>.

package Net::FTP;

require 5.001;

use strict;
use vars qw(@ISA $VERSION);
use Carp;

use Socket 1.3;
use IO::Socket;
use Time::Local;
use Net::Cmd;
use Net::Config;
# use AutoLoader qw(AUTOLOAD);

$VERSION = "2.56"; # $Id: FTP.pm,v 1.1 2002/01/30 20:42:21 lucchesi Exp $
@ISA     = qw(Exporter Net::Cmd IO::Socket::INET);

# Someday I will "use constant", when I am not bothered to much about
# compatability with older releases of perl

use vars qw($TELNET_IAC $TELNET_IP $TELNET_DM);
($TELNET_IAC,$TELNET_IP,$TELNET_DM) = (255,244,242);

# Name is too long for AutoLoad, it clashes with pasv_xfer
sub pasv_xfer_unique {
    my($sftp,$sfile,$dftp,$dfile) = @_;
    $sftp->pasv_xfer($sfile,$dftp,$dfile,1);
}

1;
# Having problems with AutoLoader
#__END__

sub new
{
 my $pkg  = shift;
 my $peer = shift;
 my %arg  = @_; 

 my $host = $peer;
 my $fire = undef;

 if(exists($arg{Firewall}) || Net::Config->requires_firewall($peer))
  {
   $fire = $arg{Firewall}
	|| $ENV{FTP_FIREWALL}
	|| $NetConfig{ftp_firewall}
	|| undef;

   if(defined $fire)
    {
     $peer = $fire;
     delete $arg{Port};
    }
  }

 my $ftp = $pkg->SUPER::new(PeerAddr => $peer, 
			    PeerPort => $arg{Port} || 'ftp(21)',
			    Proto    => 'tcp',
			    Timeout  => defined $arg{Timeout}
						? $arg{Timeout}
						: 120
			   ) or return undef;

 ${*$ftp}{'net_ftp_host'}     = $host;		# Remote hostname
 ${*$ftp}{'net_ftp_type'}     = 'A';		# ASCII/binary/etc mode
 ${*$ftp}{'net_ftp_blksize'}  = abs($arg{'BlockSize'} || 10240);

 ${*$ftp}{'net_ftp_firewall'} = $fire
	if(defined $fire);

 ${*$ftp}{'net_ftp_passive'} = int
	exists $arg{Passive}
	    ? $arg{Passive}
	    : exists $ENV{FTP_PASSIVE}
		? $ENV{FTP_PASSIVE}
		: defined $fire
		    ? $NetConfig{ftp_ext_passive}
		    : $NetConfig{ftp_int_passive};	# Whew! :-)

 $ftp->hash(exists $arg{Hash} ? $arg{Hash} : 0, 1024);

 $ftp->autoflush(1);

 $ftp->debug(exists $arg{Debug} ? $arg{Debug} : undef);

 unless ($ftp->response() == CMD_OK)
  {
   $ftp->close();
   $@ = $ftp->message;
   undef $ftp;
  }

 $ftp;
}

##
## User interface methods
##

sub hash {
    my $ftp = shift;		# self
    my $prev = ${*$ftp}{'net_ftp_hash'} || [\*STDERR, 0];

    unless(@_) {
      return $prev;
    }
    my($h,$b) = @_;
    if(@_ == 1) {
      unless($h) {
        delete ${*$ftp}{'net_ftp_hash'};
        return $prev;
      }
      elsif(ref($h)) {
        $b = 1024;
      }
      else {
        ($h,$b) = (\*STDERR,$h);
      }
    }
    select((select($h), $|=1)[0]);
    $b = 512 if $b < 512;
    ${*$ftp}{'net_ftp_hash'} = [$h, $b];
    $prev;
}        

sub quit
{
 my $ftp = shift;

 $ftp->_QUIT;
 $ftp->close;
}

sub DESTROY
{
 my $ftp = shift;
 defined(fileno($ftp)) && $ftp->quit
}

sub ascii  { shift->type('A',@_); }
sub binary { shift->type('I',@_); }

sub ebcdic
{
 carp "TYPE E is unsupported, shall default to I";
 shift->type('E',@_);
}

sub byte
{
 carp "TYPE L is unsupported, shall default to I";
 shift->type('L',@_);
}

# Allow the user to send a command directly, BE CAREFUL !!

sub quot
{ 
 my $ftp = shift;
 my $cmd = shift;

 $ftp->command( uc $cmd, @_);
 $ftp->response();
}

sub site
{
 my $ftp = shift;

 $ftp->command("SITE", @_);
 $ftp->response();
}

sub mdtm
{
 my $ftp  = shift;
 my $file = shift;

 # Server Y2K bug workaround
 #
 # sigh; some idiotic FTP servers use ("19%d",tm.tm_year) instead of 
 # ("%d",tm.tm_year+1900).  This results in an extra digit in the
 # string returned. To account for this we allow an optional extra
 # digit in the year. Then if the first two digits are 19 we use the
 # remainder, otherwise we subtract 1900 from the whole year.

 $ftp->_MDTM($file) && $ftp->message =~ /((\d\d)(\d\d\d?))(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/
    ? timegm($8,$7,$6,$5,$4-1,$2 eq '19' ? $3 : ($1-1900))
    : undef;
}

sub size {
  my $ftp  = shift;
  my $file = shift;
  my $io;
  if($ftp->supported("SIZE")) {
    return $ftp->_SIZE($file)
	? ($ftp->message =~ /(\d+)/)[0]
	: undef;
 }
 elsif($ftp->supported("STAT")) {
   my @msg;
   return undef
       unless $ftp->_STAT($file) && (@msg = $ftp->message) == 3;
   my $line;
   foreach $line (@msg) {
     return (split(/\s+/,$line))[4]
	 if $line =~ /^[-rw]{10}/
   }
 }
 else {
   my @files = $ftp->dir($file);
   if(@files) {
     return (split(/\s+/,$1))[4]
	 if $files[0] =~ /^([-rw]{10}.*)$/;
   }
 }
 undef;
}

sub login {
  my($ftp,$user,$pass,$acct) = @_;
  my($ok,$ruser,$fwtype);

  unless (defined $user) {
    require Net::Netrc;

    my $rc = Net::Netrc->lookup(${*$ftp}{'net_ftp_host'});

    ($user,$pass,$acct) = $rc->lpa()
	 if ($rc);
   }

  $user ||= "anonymous";
  $ruser = $user;

  $fwtype = $NetConfig{'ftp_firewall_type'} || 0;

  if ($fwtype && defined ${*$ftp}{'net_ftp_firewall'}) {
    if ($fwtype == 1 || $fwtype == 7) {
      $user .= '@' . ${*$ftp}{'net_ftp_host'};
    }
    else {
      require Net::Netrc;

      my $rc = Net::Netrc->lookup(${*$ftp}{'net_ftp_firewall'});

      my($fwuser,$fwpass,$fwacct) = $rc ? $rc->lpa() : ();

      if ($fwtype == 5) {
	$user = join('@',$user,$fwuser,${*$ftp}{'net_ftp_host'});
	$pass = $pass . '@' . $fwpass;
      }
      else {
	if ($fwtype == 2) {
	  $user .= '@' . ${*$ftp}{'net_ftp_host'};
	}
	elsif ($fwtype == 6) {
	  $fwuser .= '@' . ${*$ftp}{'net_ftp_host'};
	}

	$ok = $ftp->_USER($fwuser);

	return 0 unless $ok == CMD_OK || $ok == CMD_MORE;

	$ok = $ftp->_PASS($fwpass || "");

	return 0 unless $ok == CMD_OK || $ok == CMD_MORE;

	$ok = $ftp->_ACCT($fwacct)
	  if defined($fwacct);

	if ($fwtype == 3) {
          $ok = $ftp->command("SITE",${*$ftp}{'net_ftp_host'})->response;
	}
	elsif ($fwtype == 4) {
          $ok = $ftp->command("OPEN",${*$ftp}{'net_ftp_host'})->response;
	}

	return 0 unless $ok == CMD_OK || $ok == CMD_MORE;
      }
    }
  }

  $ok = $ftp->_USER($user);

  # Some dumb firewalls don't prefix the connection messages
  $ok = $ftp->response()
	 if ($ok == CMD_OK && $ftp->code == 220 && $user =~ /\@/);

  if ($ok == CMD_MORE) {
    unless(defined $pass) {
      require Net::Netrc;

      my $rc = Net::Netrc->lookup(${*$ftp}{'net_ftp_host'}, $ruser);

      ($ruser,$pass,$acct) = $rc->lpa()
	 if ($rc);

      $pass = "-" . (eval { (getpwuid($>))[0] } || $ENV{NAME} ) . '@'
         if (!defined $pass && (!defined($ruser) || $ruser =~ /^anonymous/o));
    }

    $ok = $ftp->_PASS($pass || "");
  }

  $ok = $ftp->_ACCT($acct)
	 if (defined($acct) && ($ok == CMD_MORE || $ok == CMD_OK));

  if ($fwtype == 7 && $ok == CMD_OK && defined ${*$ftp}{'net_ftp_firewall'}) {
    my($f,$auth,$resp) = _auth_id($ftp);
    $ftp->authorize($auth,$resp) if defined($resp);
  }

  $ok == CMD_OK;
}

sub account
{
 @_ == 2 or croak 'usage: $ftp->account( ACCT )';
 my $ftp = shift;
 my $acct = shift;
 $ftp->_ACCT($acct) == CMD_OK;
}

sub _auth_id {
 my($ftp,$auth,$resp) = @_;

 unless(defined $resp)
  {
   require Net::Netrc;

   $auth ||= eval { (getpwuid($>))[0] } || $ENV{NAME};

   my $rc = Net::Netrc->lookup(${*$ftp}{'net_ftp_firewall'}, $auth)
        || Net::Netrc->lookup(${*$ftp}{'net_ftp_firewall'});

   ($auth,$resp) = $rc->lpa()
     if ($rc);
  }
  ($ftp,$auth,$resp);
}

sub authorize
{
 @_ >= 1 || @_ <= 3 or croak 'usage: $ftp->authorize( [AUTH [, RESP]])';

 my($ftp,$auth,$resp) = &_auth_id;

 my $ok = $ftp->_AUTH($auth || "");

 $ok = $ftp->_RESP($resp || "")
	if ($ok == CMD_MORE);

 $ok == CMD_OK;
}

sub rename
{
 @_ == 3 or croak 'usage: $ftp->rename(FROM, TO)';

 my($ftp,$from,$to) = @_;

 $ftp->_RNFR($from)
    && $ftp->_RNTO($to);
}

sub type
{
 my $ftp = shift;
 my $type = shift;
 my $oldval = ${*$ftp}{'net_ftp_type'};

 return $oldval
	unless (defined $type);

 return undef
	unless ($ftp->_TYPE($type,@_));

 ${*$ftp}{'net_ftp_type'} = join(" ",$type,@_);

 $oldval;
}

sub abort
{
 my $ftp = shift;

 send($ftp,pack("CCC", $TELNET_IAC, $TELNET_IP, $TELNET_IAC),MSG_OOB);

 $ftp->command(pack("C",$TELNET_DM) . "ABOR");
 
 ${*$ftp}{'net_ftp_dataconn'}->close()
    if defined ${*$ftp}{'net_ftp_dataconn'};

 $ftp->response();

 $ftp->status == CMD_OK;
}

sub get
{
 my($ftp,$remote,$local,$where) = @_;

 my($loc,$len,$buf,$resp,$localfd,$data);
 local *FD;

 $localfd = ref($local) || ref(\$local) eq "GLOB"
             ? fileno($local)
	     : undef;

 ($local = $remote) =~ s#^.*/##
	unless(defined $local);

 croak("Bad remote filename '$remote'\n")
	if $remote =~ /[\r\n]/s;

 ${*$ftp}{'net_ftp_rest'} = $where
	if ($where);

 delete ${*$ftp}{'net_ftp_port'};
 delete ${*$ftp}{'net_ftp_pasv'};

 $data = $ftp->retr($remote) or
	return undef;

 if(defined $localfd)
  {
   $loc = $local;
  }
 else
  {
   $loc = \*FD;

   unless(($where) ? open($loc,">>$local") : open($loc,">$local"))
    {
     carp "Cannot open Local file $local: $!\n";
     $data->abort;
     return undef;
    }
  }

 if($ftp->type eq 'I' && !binmode($loc))
  {
   carp "Cannot binmode Local file $local: $!\n";
   $data->abort;
   close($loc) unless $localfd;
   return undef;
  }

 $buf = '';
 my($count,$hashh,$hashb,$ref) = (0);

 ($hashh,$hashb) = @$ref
   if($ref = ${*$ftp}{'net_ftp_hash'});

 my $blksize = ${*$ftp}{'net_ftp_blksize'};

 while(1)
  {
   last unless $len = $data->read($buf,$blksize);
   if($hashh) {
    $count += $len;
    print $hashh "#" x (int($count / $hashb));
    $count %= $hashb;
   }
   my $written = syswrite($loc,$buf,$len);
   unless(defined($written) && $written == $len)
    {
     carp "Cannot write to Local file $local: $!\n";
     $data->abort;
     close($loc)
        unless defined $localfd;
     return undef;
    }
  }

 print $hashh "\n" if $hashh;

 close($loc)
	unless defined $localfd;
 
 $data->close(); # implied $ftp->response

 return $local;
}

sub cwd
{
 @_ == 1 || @_ == 2 or croak 'usage: $ftp->cwd( [ DIR ] )';

 my($ftp,$dir) = @_;

 $dir = "/" unless defined($dir) && $dir =~ /\S/;

 $dir eq ".."
    ? $ftp->_CDUP()
    : $ftp->_CWD($dir);
}

sub cdup
{
 @_ == 1 or croak 'usage: $ftp->cdup()';
 $_[0]->_CDUP;
}

sub pwd
{
 @_ == 1 || croak 'usage: $ftp->pwd()';
 my $ftp = shift;

 $ftp->_PWD();
 $ftp->_extract_path;
}

# rmdir( $ftp, $dir, [ $recurse ] )
#
# Removes $dir on remote host via FTP.
# $ftp is handle for remote host
#
# If $recurse is TRUE, the directory and deleted recursively.
# This means all of its contents and subdirectories.
#
# Initial version contributed by Dinkum Software
#
sub rmdir
{
    @_ == 2 || @_ == 3 or croak('usage: $ftp->rmdir( DIR [, RECURSE ] )');

    # Pick off the args
    my ($ftp, $dir, $recurse) = @_ ;
    my $ok;

    return $ok
	if $ftp->_RMD( $dir ) || !$recurse;

    # Try to delete the contents
    # Get a list of all the files in the directory
    my $filelist = $ftp->ls($dir);

    return undef
	unless $filelist && @$filelist; # failed, it is probably not a directory

    # Go thru and delete each file or the directory
    my $file;
    foreach $file (map { m,/, ? $_ : "$dir/$_" } @$filelist)
    {
	next  # successfully deleted the file
	    if $ftp->delete($file);

	# Failed to delete it, assume its a directory
	# Recurse and ignore errors, the final rmdir() will
	# fail on any errors here
	return $ok
	    unless $ok = $ftp->rmdir($file, 1) ;
    }

    # Directory should be empty
    # Try to remove the directory again
    # Pass results directly to caller
    # If any of the prior deletes failed, this
    # rmdir() will fail because directory is not empty
    return $ftp->_RMD($dir) ;
}

sub mkdir
{
 @_ == 2 || @_ == 3 or croak 'usage: $ftp->mkdir( DIR [, RECURSE ] )';

 my($ftp,$dir,$recurse) = @_;

 $ftp->_MKD($dir) || $recurse or
    return undef;

 my $path = $dir;

 unless($ftp->ok)
  {
   my @path = split(m#(?=/+)#, $dir);

   $path = "";

   while(@path)
    {
     $path .= shift @path;

     $ftp->_MKD($path);

     $path = $ftp->_extract_path($path);
    }

   # If the creation of the last element was not sucessful, see if we
   # can cd to it, if so then return path

   unless($ftp->ok)
    {
     my($status,$message) = ($ftp->status,$ftp->message);
     my $pwd = $ftp->pwd;
     
     if($pwd && $ftp->cwd($dir))
      {
       $path = $dir;
       $ftp->cwd($pwd);
      }
     else
      {
       undef $path;
      }
     $ftp->set_status($status,$message);
    }
  }

 $path;
}

sub delete
{
 @_ == 2 || croak 'usage: $ftp->delete( FILENAME )';

 $_[0]->_DELE($_[1]);
}

sub put        { shift->_store_cmd("stor",@_) }
sub put_unique { shift->_store_cmd("stou",@_) }
sub append     { shift->_store_cmd("appe",@_) }

sub nlst { shift->_data_cmd("NLST",@_) }
sub list { shift->_data_cmd("LIST",@_) }
sub retr { shift->_data_cmd("RETR",@_) }
sub stor { shift->_data_cmd("STOR",@_) }
sub stou { shift->_data_cmd("STOU",@_) }
sub appe { shift->_data_cmd("APPE",@_) }

sub _store_cmd 
{
 my($ftp,$cmd,$local,$remote) = @_;
 my($loc,$sock,$len,$buf,$localfd);
 local *FD;

 $localfd = ref($local) || ref(\$local) eq "GLOB"
             ? fileno($local)
	     : undef;

 unless(defined $remote)
  {
   croak 'Must specify remote filename with stream input'
	if defined $localfd;

   require File::Basename;
   $remote = File::Basename::basename($local);
  }

 croak("Bad remote filename '$remote'\n")
	if $remote =~ /[\r\n]/s;

 if(defined $localfd)
  {
   $loc = $local;
  }
 else
  {
   $loc = \*FD;

   unless(open($loc,"<$local"))
    {
     carp "Cannot open Local file $local: $!\n";
     return undef;
    }
  }

 if($ftp->type eq 'I' && !binmode($loc))
  {
   carp "Cannot binmode Local file $local: $!\n";
   return undef;
  }

 delete ${*$ftp}{'net_ftp_port'};
 delete ${*$ftp}{'net_ftp_pasv'};

 $sock = $ftp->_data_cmd($cmd, $remote) or 
	return undef;

 my $blksize = ${*$ftp}{'net_ftp_blksize'};

 my($count,$hashh,$hashb,$ref) = (0);

 ($hashh,$hashb) = @$ref
   if($ref = ${*$ftp}{'net_ftp_hash'});

 while(1)
  {
   last unless $len = sysread($loc,$buf="",$blksize);

   if($hashh) {
    $count += $len;
    print $hashh "#" x (int($count / $hashb));
    $count %= $hashb;
   }

   my $wlen;
   unless(defined($wlen = $sock->write($buf,$len)) && $wlen == $len)
    {
     $sock->abort;
     close($loc)
	unless defined $localfd;
     print $hashh "\n" if $hashh;
     return undef;
    }
  }

 print $hashh "\n" if $hashh;

 close($loc)
	unless defined $localfd;

 $sock->close() or
	return undef;

 ($remote) = $ftp->message =~ /unique file name:\s*(\S*)\s*\)/
	if ('STOU' eq uc $cmd);

 return $remote;
}

sub port
{
 @_ == 1 || @_ == 2 or croak 'usage: $ftp->port([PORT])';

 my($ftp,$port) = @_;
 my $ok;

 delete ${*$ftp}{'net_ftp_intern_port'};

 unless(defined $port)
  {
   # create a Listen socket at same address as the command socket

   ${*$ftp}{'net_ftp_listen'} ||= IO::Socket::INET->new(Listen    => 5,
				    	    	        Proto     => 'tcp',
				    	    	       );
  
   my $listen = ${*$ftp}{'net_ftp_listen'};

   my($myport, @myaddr) = ($listen->sockport, split(/\./,$ftp->sockhost));

   $port = join(',', @myaddr, $myport >> 8, $myport & 0xff);

   ${*$ftp}{'net_ftp_intern_port'} = 1;
  }

 $ok = $ftp->_PORT($port);

 ${*$ftp}{'net_ftp_port'} = $port;

 $ok;
}

sub ls  { shift->_list_cmd("NLST",@_); }
sub dir { shift->_list_cmd("LIST",@_); }

sub pasv
{
 @_ == 1 or croak 'usage: $ftp->pasv()';

 my $ftp = shift;

 delete ${*$ftp}{'net_ftp_intern_port'};

 $ftp->_PASV && $ftp->message =~ /(\d+(,\d+)+)/
    ? ${*$ftp}{'net_ftp_pasv'} = $1
    : undef;    
}

sub unique_name
{
 my $ftp = shift;
 ${*$ftp}{'net_ftp_unique'} || undef;
}

sub supported {
    @_ == 2 or croak 'usage: $ftp->supported( CMD )';
    my $ftp = shift;
    my $cmd = uc shift;
    my $hash = ${*$ftp}{'net_ftp_supported'} ||= {};

    return $hash->{$cmd}
        if exists $hash->{$cmd};

    return $hash->{$cmd} = 0
	unless $ftp->_HELP($cmd);

    my $text = $ftp->message;
    if($text =~ /following\s+commands/i) {
	$text =~ s/^.*\n//;
	$text =~ s/\n/ /sog;
	while($text =~ /(\w+)([* ])/g) {
	    $hash->{"\U$1"} = $2 eq " " ? 1 : 0;
	}
    }
    else {
	$hash->{$cmd} = $text !~ /unimplemented/i;
    }

    $hash->{$cmd} ||= 0;
}

##
## Deprecated methods
##

sub lsl
{
 carp "Use of Net::FTP::lsl deprecated, use 'dir'"
    if $^W;
 goto &dir;
}

sub authorise
{
 carp "Use of Net::FTP::authorise deprecated, use 'authorize'"
    if $^W;
 goto &authorize;
}


##
## Private methods
##

sub _extract_path
{
 my($ftp, $path) = @_;

 # This tries to work both with and without the quote doubling
 # convention (RFC 959 requires it, but the first 3 servers I checked
 # didn't implement it).  It will fail on a server which uses a quote in
 # the message which isn't a part of or surrounding the path.
 $ftp->ok &&
    $ftp->message =~ /(?:^|\s)\"(.*)\"(?:$|\s)/ &&
    ($path = $1) =~ s/\"\"/\"/g;

 $path;
}

##
## Communication methods
##

sub _dataconn
{
 my $ftp = shift;
 my $data = undef;
 my $pkg = "Net::FTP::" . $ftp->type;

 eval "require " . $pkg;

 $pkg =~ s/ /_/g;

 delete ${*$ftp}{'net_ftp_dataconn'};

 if(defined ${*$ftp}{'net_ftp_pasv'})
  {
   my @port = split(/,/,${*$ftp}{'net_ftp_pasv'});

   $data = $pkg->new(PeerAddr => join(".",@port[0..3]),
    	    	     PeerPort => $port[4] * 256 + $port[5],
    	    	     Proto    => 'tcp'
    	    	    );
  }
 elsif(defined ${*$ftp}{'net_ftp_listen'})
  {
   $data = ${*$ftp}{'net_ftp_listen'}->accept($pkg);
   close(delete ${*$ftp}{'net_ftp_listen'});
  }

 if($data)
  {
   ${*$data} = "";
   $data->timeout($ftp->timeout);
   ${*$ftp}{'net_ftp_dataconn'} = $data;
   ${*$data}{'net_ftp_cmd'} = $ftp;
   ${*$data}{'net_ftp_blksize'} = ${*$ftp}{'net_ftp_blksize'};
  }

 $data;
}

sub _list_cmd
{
 my $ftp = shift;
 my $cmd = uc shift;

 delete ${*$ftp}{'net_ftp_port'};
 delete ${*$ftp}{'net_ftp_pasv'};

 my $data = $ftp->_data_cmd($cmd,@_);

 return
	unless(defined $data);

 require Net::FTP::A;
 bless $data, "Net::FTP::A"; # Force ASCII mode

 my $databuf = '';
 my $buf = '';
 my $blksize = ${*$ftp}{'net_ftp_blksize'};

 while($data->read($databuf,$blksize)) {
   $buf .= $databuf;
 }

 my $list = [ split(/\n/,$buf) ];

 $data->close();

 wantarray ? @{$list}
           : $list;
}

sub _data_cmd
{
 my $ftp = shift;
 my $cmd = uc shift;
 my $ok = 1;
 my $where = delete ${*$ftp}{'net_ftp_rest'} || 0;
 my $arg;

 for $arg (@_) {
   croak("Bad argument '$arg'\n")
	if $arg =~ /[\r\n]/s;
 }

 if(${*$ftp}{'net_ftp_passive'} &&
     !defined ${*$ftp}{'net_ftp_pasv'} &&
     !defined ${*$ftp}{'net_ftp_port'})
  {
   my $data = undef;

   $ok = defined $ftp->pasv;
   $ok = $ftp->_REST($where)
	if $ok && $where;

   if($ok)
    {
     $ftp->command($cmd,@_);
     $data = $ftp->_dataconn();
     $ok = CMD_INFO == $ftp->response();
     if($ok) 
      {
       $data->reading
         if $data && $cmd =~ /RETR|LIST|NLST/;
       return $data
      }
     $data->_close
	if $data;
    }
   return undef;
  }

 $ok = $ftp->port
    unless (defined ${*$ftp}{'net_ftp_port'} ||
            defined ${*$ftp}{'net_ftp_pasv'});

 $ok = $ftp->_REST($where)
    if $ok && $where;

 return undef
    unless $ok;

 $ftp->command($cmd,@_);

 return 1
    if(defined ${*$ftp}{'net_ftp_pasv'});

 $ok = CMD_INFO == $ftp->response();

 return $ok 
    unless exists ${*$ftp}{'net_ftp_intern_port'};

 if($ok) {
   my $data = $ftp->_dataconn();

   $data->reading
         if $data && $cmd =~ /RETR|LIST|NLST/;

   return $data;
 }

 
 close(delete ${*$ftp}{'net_ftp_listen'});
 
 return undef;
}

##
## Over-ride methods (Net::Cmd)
##

sub debug_text { $_[2] =~ /^(pass|resp|acct)/i ? "$1 ....\n" : $_[2]; }

sub command
{
 my $ftp = shift;

 delete ${*$ftp}{'net_ftp_port'};
 $ftp->SUPER::command(@_);
}

sub response
{
 my $ftp = shift;
 my $code = $ftp->SUPER::response();

 delete ${*$ftp}{'net_ftp_pasv'}
    if ($code != CMD_MORE && $code != CMD_INFO);

 $code;
}

sub parse_response
{
 return ($1, $2 eq "-")
    if $_[1] =~ s/^(\d\d\d)(.?)//o;

 my $ftp = shift;

 # Darn MS FTP server is a load of CRAP !!!!
 return ()
	unless ${*$ftp}{'net_cmd_code'} + 0;

 (${*$ftp}{'net_cmd_code'},1);
}

##
## Allow 2 servers to talk directly
##

sub pasv_xfer {
    my($sftp,$sfile,$dftp,$dfile,$unique) = @_;

    ($dfile = $sfile) =~ s#.*/##
	unless(defined $dfile);

    my $port = $sftp->pasv or
	return undef;

    $dftp->port($port) or
	return undef;

    return undef
	unless($unique ? $dftp->stou($dfile) : $dftp->stor($dfile));

    unless($sftp->retr($sfile) && $sftp->response == CMD_INFO) {
	$sftp->retr($sfile);
	$dftp->abort;
	$dftp->response();
	return undef;
    }

    $dftp->pasv_wait($sftp);
}

sub pasv_wait
{
 @_ == 2 or croak 'usage: $ftp->pasv_wait(NON_PASV_FTP)';

 my($ftp, $non_pasv) = @_;
 my($file,$rin,$rout);

 vec($rin='',fileno($ftp),1) = 1;
 select($rout=$rin, undef, undef, undef);

 $ftp->response();
 $non_pasv->response();

 return undef
	unless $ftp->ok() && $non_pasv->ok();

 return $1
	if $ftp->message =~ /unique file name:\s*(\S*)\s*\)/;

 return $1
	if $non_pasv->message =~ /unique file name:\s*(\S*)\s*\)/;

 return 1;
}

sub cmd { shift->command(@_)->response() }

########################################
#
# RFC959 commands
#

sub _ABOR { shift->command("ABOR")->response()	 == CMD_OK }
sub _CDUP { shift->command("CDUP")->response()	 == CMD_OK }
sub _NOOP { shift->command("NOOP")->response()	 == CMD_OK }
sub _PASV { shift->command("PASV")->response()	 == CMD_OK }
sub _QUIT { shift->command("QUIT")->response()	 == CMD_OK }
sub _DELE { shift->command("DELE",@_)->response() == CMD_OK }
sub _CWD  { shift->command("CWD", @_)->response() == CMD_OK }
sub _PORT { shift->command("PORT",@_)->response() == CMD_OK }
sub _RMD  { shift->command("RMD", @_)->response() == CMD_OK }
sub _MKD  { shift->command("MKD", @_)->response() == CMD_OK }
sub _PWD  { shift->command("PWD", @_)->response() == CMD_OK }
sub _TYPE { shift->command("TYPE",@_)->response() == CMD_OK }
sub _RNTO { shift->command("RNTO",@_)->response() == CMD_OK }
sub _RESP { shift->command("RESP",@_)->response() == CMD_OK }
sub _MDTM { shift->command("MDTM",@_)->response() == CMD_OK }
sub _SIZE { shift->command("SIZE",@_)->response() == CMD_OK }
sub _HELP { shift->command("HELP",@_)->response() == CMD_OK }
sub _STAT { shift->command("STAT",@_)->response() == CMD_OK }
sub _APPE { shift->command("APPE",@_)->response() == CMD_INFO }
sub _LIST { shift->command("LIST",@_)->response() == CMD_INFO }
sub _NLST { shift->command("NLST",@_)->response() == CMD_INFO }
sub _RETR { shift->command("RETR",@_)->response() == CMD_INFO }
sub _STOR { shift->command("STOR",@_)->response() == CMD_INFO }
sub _STOU { shift->command("STOU",@_)->response() == CMD_INFO }
sub _RNFR { shift->command("RNFR",@_)->response() == CMD_MORE }
sub _REST { shift->command("REST",@_)->response() == CMD_MORE }
sub _USER { shift->command("user",@_)->response() } # A certain brain dead firewall :-)
sub _PASS { shift->command("PASS",@_)->response() }
sub _ACCT { shift->command("ACCT",@_)->response() }
sub _AUTH { shift->command("AUTH",@_)->response() }

sub _ALLO { shift->unsupported(@_) }
sub _SMNT { shift->unsupported(@_) }
sub _MODE { shift->unsupported(@_) }
sub _SYST { shift->unsupported(@_) }
sub _STRU { shift->unsupported(@_) }
sub _REIN { shift->unsupported(@_) }

1;

__END__

=head1 NAME

Net::FTP - FTP Client class

=head1 SYNOPSIS

    use Net::FTP;
    
    $ftp = Net::FTP->new("some.host.name", Debug => 0);
    $ftp->login("anonymous",'me@here.there');
    $ftp->cwd("/pub");
    $ftp->get("that.file");
    $ftp->quit;

=head1 DESCRIPTION

C<Net::FTP> is a class implementing a simple FTP client in Perl as
described in RFC959.  It provides wrappers for a subset of the RFC959
commands.

=head1 OVERVIEW

FTP stands for File Transfer Protocol.  It is a way of transferring
files between networked machines.  The protocol defines a client
(whose commands are provided by this module) and a server (not
implemented in this module).  Communication is always initiated by the
client, and the server responds with a message and a status code (and
sometimes with data).

The FTP protocol allows files to be sent to or fetched from the
server.  Each transfer involves a B<local file> (on the client) and a
B<remote file> (on the server).  In this module, the same file name
will be used for both local and remote if only one is specified.  This
means that transferring remote file C</path/to/file> will try to put
that file in C</path/to/file> locally, unless you specify a local file
name.

The protocol also defines several standard B<translations> which the
file can undergo during transfer.  These are ASCII, EBCDIC, binary,
and byte.  ASCII is the default type, and indicates that the sender of
files will translate the ends of lines to a standard representation
which the receiver will then translate back into their local
representation.  EBCDIC indicates the file being transferred is in
EBCDIC format.  Binary (also known as image) format sends the data as
a contiguous bit stream.  Byte format transfers the data as bytes, the
values of which remain the same regardless of differences in byte size
between the two machines (in theory - in practice you should only use
this if you really know what you're doing).

=head1 CONSTRUCTOR

=over 4

=item new (HOST [,OPTIONS])

This is the constructor for a new Net::FTP object. C<HOST> is the
name of the remote host to which a FTP connection is required.

C<OPTIONS> are passed in a hash like fashion, using key and value pairs.
Possible options are:

B<Firewall> - The name of a machine which acts as a FTP firewall. This can be
overridden by an environment variable C<FTP_FIREWALL>. If specified, and the
given host cannot be directly connected to, then the
connection is made to the firewall machine and the string C<@hostname> is
appended to the login identifier. This kind of setup is also refered to
as a ftp proxy.

B<BlockSize> - This is the block size that Net::FTP will use when doing
transfers. (defaults to 10240)

B<Port> - The port number to connect to on the remote machine for the
FTP connection

B<Timeout> - Set a timeout value (defaults to 120)

B<Debug> - debug level (see the debug method in L<Net::Cmd>)

B<Passive> - If set to a non-zero value then all data transfers will be done
using passive mode. This is not usually required except for some I<dumb>
servers, and some firewall configurations. This can also be set by the
environment variable C<FTP_PASSIVE>.

B<Hash> - If TRUE, print hash marks (#) on STDERR every 1024 bytes.  This
simply invokes the C<hash()> method for you, so that hash marks are displayed
for all transfers.  You can, of course, call C<hash()> explicitly whenever
you'd like.

If the constructor fails undef will be returned and an error message will
be in $@

=back

=head1 METHODS

Unless otherwise stated all methods return either a I<true> or I<false>
value, with I<true> meaning that the operation was a success. When a method
states that it returns a value, failure will be returned as I<undef> or an
empty list.

=over 4

=item login ([LOGIN [,PASSWORD [, ACCOUNT] ] ])

Log into the remote FTP server with the given login information. If
no arguments are given then the C<Net::FTP> uses the C<Net::Netrc>
package to lookup the login information for the connected host.
If no information is found then a login of I<anonymous> is used.
If no password is given and the login is I<anonymous> then the users
Email address will be used for a password.

If the connection is via a firewall then the C<authorize> method will
be called with no arguments.

=item authorize ( [AUTH [, RESP]])

This is a protocol used by some firewall ftp proxies. It is used
to authorise the user to send data out.  If both arguments are not specified
then C<authorize> uses C<Net::Netrc> to do a lookup.

=item site (ARGS)

Send a SITE command to the remote server and wait for a response.

Returns most significant digit of the response code.

=item type (TYPE [, ARGS])

This method will send the TYPE command to the remote FTP server
to change the type of data transfer. The return value is the previous
value.

=item ascii ([ARGS]) binary([ARGS]) ebcdic([ARGS]) byte([ARGS])

Synonyms for C<type> with the first arguments set correctly

B<NOTE> ebcdic and byte are not fully supported.

=item rename ( OLDNAME, NEWNAME )

Rename a file on the remote FTP server from C<OLDNAME> to C<NEWNAME>. This
is done by sending the RNFR and RNTO commands.

=item delete ( FILENAME )

Send a request to the server to delete C<FILENAME>.

=item cwd ( [ DIR ] )

Attempt to change directory to the directory given in C<$dir>.  If
C<$dir> is C<"..">, the FTP C<CDUP> command is used to attempt to
move up one directory. If no directory is given then an attempt is made
to change the directory to the root directory.

=item cdup ()

Change directory to the parent of the current directory.

=item pwd ()

Returns the full pathname of the current directory.

=item rmdir ( DIR )

Remove the directory with the name C<DIR>.

=item mkdir ( DIR [, RECURSE ])

Create a new directory with the name C<DIR>. If C<RECURSE> is I<true> then
C<mkdir> will attempt to create all the directories in the given path.

Returns the full pathname to the new directory.

=item ls ( [ DIR ] )

Get a directory listing of C<DIR>, or the current directory.

In an array context, returns a list of lines returned from the server. In
a scalar context, returns a reference to a list.

=item dir ( [ DIR ] )

Get a directory listing of C<DIR>, or the current directory in long format.

In an array context, returns a list of lines returned from the server. In
a scalar context, returns a reference to a list.

=item get ( REMOTE_FILE [, LOCAL_FILE [, WHERE]] )

Get C<REMOTE_FILE> from the server and store locally. C<LOCAL_FILE> may be
a filename or a filehandle. If not specified the the file will be stored in
the current directory with the same leafname as the remote file.

If C<WHERE> is given then the first C<WHERE> bytes of the file will
not be transfered, and the remaining bytes will be appended to
the local file if it already exists.

Returns C<LOCAL_FILE>, or the generated local file name if C<LOCAL_FILE>
is not given.

=item put ( LOCAL_FILE [, REMOTE_FILE ] )

Put a file on the remote server. C<LOCAL_FILE> may be a name or a filehandle.
If C<LOCAL_FILE> is a filehandle then C<REMOTE_FILE> must be specified. If
C<REMOTE_FILE> is not specified then the file will be stored in the current
directory with the same leafname as C<LOCAL_FILE>.

Returns C<REMOTE_FILE>, or the generated remote filename if C<REMOTE_FILE>
is not given.

B<NOTE>: If for some reason the transfer does not complete and an error is
returned then the contents that had been transfered will not be remove
automatically.

=item put_unique ( LOCAL_FILE [, REMOTE_FILE ] )

Same as put but uses the C<STOU> command.

Returns the name of the file on the server.

=item append ( LOCAL_FILE [, REMOTE_FILE ] )

Same as put but appends to the file on the remote server.

Returns C<REMOTE_FILE>, or the generated remote filename if C<REMOTE_FILE>
is not given.

=item unique_name ()

Returns the name of the last file stored on the server using the
C<STOU> command.

=item mdtm ( FILE )

Returns the I<modification time> of the given file

=item size ( FILE )

Returns the size in bytes for the given file as stored on the remote server.

B<NOTE>: The size reported is the size of the stored file on the remote server.
If the file is subsequently transfered from the server in ASCII mode
and the remote server and local machine have different ideas about
"End Of Line" then the size of file on the local machine after transfer
may be different.

=item supported ( CMD )

Returns TRUE if the remote server supports the given command.

=item hash ( [FILEHANDLE_GLOB_REF],[ BYTES_PER_HASH_MARK] )

Called without parameters, or with the first argument false, hash marks
are suppressed.  If the first argument is true but not a reference to a 
file handle glob, then \*STDERR is used.  The second argument is the number
of bytes per hash mark printed, and defaults to 1024.  In all cases the
return value is a reference to an array of two:  the filehandle glob reference
and the bytes per hash mark.

=back

The following methods can return different results depending on
how they are called. If the user explicitly calls either
of the C<pasv> or C<port> methods then these methods will
return a I<true> or I<false> value. If the user does not
call either of these methods then the result will be a
reference to a C<Net::FTP::dataconn> based object.

=over 4

=item nlst ( [ DIR ] )

Send a C<NLST> command to the server, with an optional parameter.

=item list ( [ DIR ] )

Same as C<nlst> but using the C<LIST> command

=item retr ( FILE )

Begin the retrieval of a file called C<FILE> from the remote server.

=item stor ( FILE )

Tell the server that you wish to store a file. C<FILE> is the
name of the new file that should be created.

=item stou ( FILE )

Same as C<stor> but using the C<STOU> command. The name of the unique
file which was created on the server will be available via the C<unique_name>
method after the data connection has been closed.

=item appe ( FILE )

Tell the server that we want to append some data to the end of a file
called C<FILE>. If this file does not exist then create it.

=back

If for some reason you want to have complete control over the data connection,
this includes generating it and calling the C<response> method when required,
then the user can use these methods to do so.

However calling these methods only affects the use of the methods above that
can return a data connection. They have no effect on methods C<get>, C<put>,
C<put_unique> and those that do not require data connections.

=over 4

=item port ( [ PORT ] )

Send a C<PORT> command to the server. If C<PORT> is specified then it is sent
to the server. If not the a listen socket is created and the correct information
sent to the server.

=item pasv ()

Tell the server to go into passive mode. Returns the text that represents the
port on which the server is listening, this text is in a suitable form to
sent to another ftp server using the C<port> method.

=back

The following methods can be used to transfer files between two remote
servers, providing that these two servers can connect directly to each other.

=over 4

=item pasv_xfer ( SRC_FILE, DEST_SERVER [, DEST_FILE ] )

This method will do a file transfer between two remote ftp servers. If
C<DEST_FILE> is omitted then the leaf name of C<SRC_FILE> will be used.

=item pasv_xfer_unique ( SRC_FILE, DEST_SERVER [, DEST_FILE ] )

Like C<pasv_xfer> but the file is stored on the remote server using
the STOU command.

=item pasv_wait ( NON_PASV_SERVER )

This method can be used to wait for a transfer to complete between a passive
server and a non-passive server. The method should be called on the passive
server with the C<Net::FTP> object for the non-passive server passed as an
argument.

=item abort ()

Abort the current data transfer.

=item quit ()

Send the QUIT command to the remote FTP server and close the socket connection.

=back

=head2 Methods for the adventurous

C<Net::FTP> inherits from C<Net::Cmd> so methods defined in C<Net::Cmd> may
be used to send commands to the remote FTP server.

=over 4

=item quot (CMD [,ARGS])

Send a command, that Net::FTP does not directly support, to the remote
server and wait for a response.

Returns most significant digit of the response code.

B<WARNING> This call should only be used on commands that do not require
data connections. Misuse of this method can hang the connection.

=back

=head1 THE dataconn CLASS

Some of the methods defined in C<Net::FTP> return an object which will
be derived from this class.The dataconn class itself is derived from
the C<IO::Socket::INET> class, so any normal IO operations can be performed.
However the following methods are defined in the dataconn class and IO should
be performed using these.

=over 4

=item read ( BUFFER, SIZE [, TIMEOUT ] )

Read C<SIZE> bytes of data from the server and place it into C<BUFFER>, also
performing any <CRLF> translation necessary. C<TIMEOUT> is optional, if not
given the the timeout value from the command connection will be used.

Returns the number of bytes read before any <CRLF> translation.

=item write ( BUFFER, SIZE [, TIMEOUT ] )

Write C<SIZE> bytes of data from C<BUFFER> to the server, also
performing any <CRLF> translation necessary. C<TIMEOUT> is optional, if not
given the the timeout value from the command connection will be used.

Returns the number of bytes written before any <CRLF> translation.

=item abort ()

Abort the current data transfer.

=item close ()

Close the data connection and get a response from the FTP server. Returns
I<true> if the connection was closed successfully and the first digit of
the response from the server was a '2'.

=back

=head1 UNIMPLEMENTED

The following RFC959 commands have not been implemented:

=over 4

=item B<ALLO>

Allocates storage for the file to be transferred.

=item B<SMNT>

Mount a different file system structure without changing login or
accounting information.

=item B<HELP>

Ask the server for "helpful information" (that's what the RFC says) on
the commands it accepts.

=item B<MODE>

Specifies transfer mode (stream, block or compressed) for file to be
transferred.

=item B<SYST>

Request remote server system identification.

=item B<STAT>

Request remote server status.

=item B<STRU>

Specifies file structure for file to be transferred.

=item B<REIN>

Reinitialize the connection, flushing all I/O and account information.

=back

=head1 REPORTING BUGS

When reporting bugs/problems please include as much information as possible.
It may be difficult for me to reproduce the problem as almost every setup
is different.

A small script which yields the problem will probably be of help. It would
also be useful if this script was run with the extra options C<Debug => 1>
passed to the constructor, and the output sent with the bug report. If you
cannot include a small script then please include a Debug trace from a
run of your program which does yield the problem.

=head1 AUTHOR

Graham Barr <gbarr@pobox.com>

=head1 SEE ALSO

L<Net::Netrc>
L<Net::Cmd>

ftp(1), ftpd(8), RFC 959
http://www.cis.ohio-state.edu/htbin/rfc/rfc959.html

=head1 CREDITS

Henry Gabryjelski <henryg@WPI.EDU> - for the suggestion of creating directories
recursively.

Nathan Torkington <gnat@frii.com> - for some input on the documentation.

Roderick Schertler <roderick@gate.net> - for various inputs

=head1 COPYRIGHT

Copyright (c) 1995-1998 Graham Barr. All rights reserved.
This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
