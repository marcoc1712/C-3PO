#!/usr/bin/perl
#
# This program is part of the C-3PO Plugin. 
# See Plugin.pm for credits, license terms and others.
#
# Logitech Media Server Copyright 2001-2011 Logitech.
# This Plugin Copyright 2015 Marco Curti (marcoc1712 at gmail dot com)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License,
# version 2.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
#########################################################################
#
package main;

use strict;
use warnings;

use FindBin qw($Bin);
use lib $Bin;

use File::Spec::Functions qw(:ALL);
use File::Basename;

my $C3PODir;
my ($volume,$directories,$file) =File::Spec->splitpath($0);

if ($file && $file eq 'HeaderRestorer.exe'){

	# We are running the compiled version in 
	# \Bin\MSWin32-x86-multi-thread folder inside the
	#plugin folder.
	
	$C3PODir = File::Spec->canonpath(getAncestor($Bin,2));

} elsif ($file eq 'HeaderRestorer'){

	#running on linux or mac OS x from inside the Bin folder
	#$C3PODir= File::Spec->canonpath(File::Basename::dirname(__FILE__)); #C3PO Folder
	$C3PODir = File::Spec->canonpath(getAncestor($Bin,1));
        

} elsif ($file && $file eq 'HeaderRestorer.pl'){

	#running .pl 
	#$C3PODir= File::Spec->canonpath(File::Basename::dirname(__FILE__)); #C3PO Folder
	$C3PODir= $Bin;

} else{
	
	# at the moment.
	die "unexpected filename";
}


my $lib= File::Spec->rel2abs(catdir($C3PODir, 'lib'));
my $cpan=  File::Spec->rel2abs(catdir($C3PODir,'CPAN'));
my $util=  File::Spec->rel2abs(catdir($C3PODir,'Util'));

#print '$directories is : '.$lib."\n";
#print '$directories is : '.$cpan."\n";
#print '$directories is : '.$util."\n";

#use Data::Dump;
#Data::Dump::dump @INC;

my @i=($lib,$cpan,$C3PODir);

unshift @INC, @i;

#Data::Dump::dump @INC;

require Utils::Config;

unshift @INC, Utils::Config::expandINC($C3PODir);

# let standard modules load.
#
use constant SLIM_SERVICE => 0;
use constant SCANNER      => 1;
use constant RESIZER      => 0;
use constant TRANSCODING  => 0;
use constant PERFMON      => 0;
use constant DEBUGLOG     => ( grep { /--nodebuglog/ } @ARGV ) ? 0 : 1;
use constant INFOLOG      => ( grep { /--noinfolog/ } @ARGV ) ? 0 : 1;
use constant STATISTICS   => ( grep { /--nostatistics/ } @ARGV ) ? 0 : 1;
use constant SB1SLIMP3SYNC=> 0;
use constant IMAGE        => ( grep { /--noimage/ } @ARGV ) ? 0 : 1;
use constant VIDEO        => ( grep { /--novideo/ } @ARGV ) ? 0 : 1;
use constant MEDIASUPPORT => IMAGE || VIDEO;
use constant WEBUI        => 0;
use constant ISWINDOWS    => ( $^O =~ /^m?s?win/i ) ? 1 : 0;
use constant ISMAC        => ( $^O =~ /darwin/i ) ? 1 : 0;
use constant HAS_AIO      => 0;
use constant LOCALFILE    => 0;
use constant NOMYSB       => 1;
#
#######################################################################

use Logger;
use OsHelper;

use Utils::Log;
use Utils::Config;

require Getopt::Long;
require Data::Dump;
require File::HomeDir;

use FileHandle;

our $logfile;
our $isDebug;
our $logLevel = DEBUGLOG ? 'debug' : INFOLOG ? 'info' : 'warn';

main();

sub main{
	#
	# until we read preferences, we don't know where logfile is.
	# use a deault one instead.
	#
	$logfile = Plugins::C3PO::Logger::guessFileFatal();

	Plugins::C3PO::Logger::verboseMessage ('HeaderRestorer: Started');
	
	my $options=getOptions();
	if (!defined $options) {Plugins::C3PO::Logger::dieMessage("HeaderRestorer: Missing options");}
	
	$isDebug = (defined $options->{debugLevel});
	Plugins::C3PO::Logger::infoMessage('debug? '.$isDebug);
	$logLevel = ($isDebug ? $options->{debugLevel} : $logLevel);

	if (defined $options->{logFile}){
		Plugins::C3PO::Logger::verboseMessage("HeaderRestorer: Swithing log file to ".$options->{logFile});
		$logfile=$options->{logFile};
		Plugins::C3PO::Logger::verboseMessage("HeaderRestorer: Swithed log file");
	}

	Plugins::C3PO::Logger::debugMessage('HeaderRestorer: options '.Data::Dump::dump($options));

	my $infile = $options->{file};
	my $buffer;
	Plugins::C3PO::Logger::debugMessage('HeaderRestorer: header file :'.$infile);

	if ($infile){

		my $in = FileHandle->new();

		if (!$in->open("< $infile")){
		
			 Plugins::C3PO::Logger::errorMessage("HeaderRestorer: Not able to open the file for reading");
		}

		binmode ($in);

		while (
			sysread ($in, $buffer, 65536)	# read in (up to) 64k chunks, write
			and syswrite STDOUT, $buffer	# exit if read or write fails
		  ) {};
		if ($!){
			Plugins::C3PO::Logger::errorMessage(
				"HeaderRestorer: Problem writing header from file:  $!");
		}
		close ($in);
		unlink $infile;
		if ($!){
			Plugins::C3PO::Logger::errorMessage(
				"HeaderRestorer: Unable to remove $infile: $!");
		}
	}

	while (
		sysread (STDIN, $buffer, 65536)	# read in (up to) 64k chunks, write
		and syswrite STDOUT, $buffer	# exit if read or write fails
	  ) {};
	if ($!){		
			
		Plugins::C3PO::Logger::errorMessage(
			"HeaderRestorer: Problem writing body from STDIN: $!");
	}
	flush STDOUT;
}
############################################################################

sub getOptions{

	#Data::Dump::dump(@ARGV);

	my $options={};
	if ( @ARGV > 0 ) {

		Getopt::Long::GetOptions(	
			'd=s' => \$options->{debugLevel},
			'l=s' => \$options->{logFile},
		);

		my $file;
		for my $str (@ARGV){

			if (!defined $file){

				$file=$str;

			} else {

				$file = qq($file $str);
			}
		}
		$options->{file}=$file;

		#print "\n\n\n".$options->{file}."\n";
		return $options;
	}
	return undef;
}

1;
sub getAncestor{
	my $folder=shift;
	my $lev=shift || 1;
	
	#print $folder."\n";
	
	my ($volume,$directories,$file) =
                       File::Spec->splitpath( $folder, 1 );
	
	my @dirs = File::Spec->splitdir( $directories );

	my $dirs= @dirs;

	@dirs= splice @dirs, 0, $lev*-1;

	return File::Spec->catfile($volume, File::Spec->catdir( @dirs ), $file);
}

1;



