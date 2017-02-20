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
# Command line options.
#
# -c - client mac address (es. 00:04:20:12:b3:17) -> clientId
# -p - preference file.
# -l - log folder.
# -x - server folder.
# -i - input stream format (es. flc) -> inFormat
# -o - output stream format (es. wav) -> outFormat
# -t - stream time start offset (m:ss.cc es. 24:46.02) -> startTime
# -v - stream time end offset (m:ss.cc es. 28:24.06) -> endTime
# -s - stream seconds start offset (hh:mm:ss.mmm es. 00:15:47.786) -> startSec
# -u - stream seconds end offset (hh:mm:ss.mmm es. 00:19:07.000) -> endSec
# -w - stream seconds duration (n*.n* es. 542.986666666667) -> durationSec
# -r - imposed samplerate
# -h - answer with an hello message, do nothing else.
# -d - run in debug mode, don't send the real command.
# -b - run as header restorer or dummy transcoder
#
# The input file is the first and only parameter (with no option) in line.
#
#########################################################################

package main;

use strict;
use warnings;

my @inc0=();
for my $i (@INC){addToArray($i,\@inc0);}

use FindBin qw($Bin);
use lib $Bin;

my @inc1=();
for my $i (@INC){addToArray($i,\@inc1);}

use File::Spec::Functions qw(:ALL);
use File::Basename;

my $C3PODir=$Bin;
my ($volume,$directories,$file) =File::Spec->splitpath($0);

#print '$volume is      : '.$volume."\n";
#print '$directories is : '.$directories."\n";
#print '$file is   : '.$file."\n";

if (!$file) {die "undefined filename";}

if ($file eq 'C-3PO.exe'){

	# We are running the compiled version in 
	# \Bin\MSWin32-x86-multi-thread folder inside the
	#plugin folder.
	$C3PODir = File::Spec->canonpath(getAncestor($Bin,2));

} elsif ($file eq 'C-3PO'){

	#running on linux or mac OS x from inside the Bin folder
	#$C3PODir= File::Spec->canonpath(File::Basename::dirname(__FILE__)); #C3PO Folder
	$C3PODir = File::Spec->canonpath(getAncestor($Bin,1));
        
} elsif ($file eq 'C-3PO.pl'){

	#running .pl 
	#$C3PODir= File::Spec->canonpath(File::Basename::dirname(__FILE__)); #C3PO Folder
	$C3PODir= $Bin;

} else{
	
	# at the moment.
	die "unexpected filename";
}

my $lib = File::Spec->rel2abs(catdir($C3PODir, 'lib'));
my $cpan= File::Spec->rel2abs(catdir($C3PODir,'CPAN'));

my @a=($C3PODir,$lib,$cpan);
for my $i (@a){addToArray($i, \@INC);}

require Utils::Config;

@a= Utils::Config::expandINC($C3PODir);
for my $i (@a){addToArray($i, \@INC);}

#unshift @INC, Utils::Config::expandINC($C3PODir);

my @inc2=();
for my $i (@INC){addToArray($i,\@inc2);}

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
require Logger;
require Transcoder;
require Shared;
require OsHelper;

require FfmpegHelper;
require FlacHelper;
require FaadHelper;
require SoxHelper;

require Utils::Log;
require Utils::File;
require Utils::Config;

require Formats::Format;
require Formats::Wav;
require Formats::Aiff;
require Formats::Flac;
require Formats::Alac;

#in Base
#require FileHandle;
#require YAML::XS;
#require Data::Dump;

#In lib.
require Module::Load;
require File::HomeDir;
require Getopt::Long;

our $serverFolder;
our $logFolder;
our $logfile;
our $isDebug;
our $logLevel = main::DEBUGLOG ? 'debug' : main::INFOLOG ? 'info' : 'warn';

#$logLevel='verbose'; #to show more debug mesages
#$logLevel='debug';
#$logLevel='info';
#$logLevel='warn'; #to show less debug mesages

main();
#################

sub main{
	#
	# until we read preferences, we don't know where logfile is.
	# use a deault one instead.
	#
	$logfile = Plugins::C3PO::Logger::guessFileFatal();

	Plugins::C3PO::Logger::verboseMessage ('C3PO.pl Started');

	my $options=getOptions();
	if (!defined $options) {Plugins::C3PO::Logger::dieMessage("Missing options");}
	
	if (defined $options->{logFolder}){
	
		$logFolder=$options->{logFolder};

		Plugins::C3PO::Logger::verboseMessage ('found log foder in options: '.$logFolder);
		
		my $newLogfile= Plugins::C3PO::Logger::getLogFile($logFolder);
		Plugins::C3PO::Logger::verboseMessage("Swithing log file to ".$newLogfile);

		$logfile= $newLogfile;
		Plugins::C3PO::Logger::verboseMessage("Now log file is $logfile");
	
	}

	if (defined $options->{'serverFolder'}){
		
		$serverFolder=$options->{'serverFolder'};

		my $lib = File::Spec->rel2abs(catdir($serverFolder, 'lib'));
		my $cpan= File::Spec->rel2abs(catdir($serverFolder,'CPAN'));

		my @a=($serverFolder,$lib,$cpan);
		for my $i (@a){addToArray($i, \@INC);}

		require Utils::Config;
		@a= Utils::Config::expandINC($serverFolder);
		for my $i (@a){addToArray($i, \@INC);}
		
		#in LMS CPAN or lib.
		
		require FileHandle;
		require YAML::XS;
		require Data::Dump;
		require Audio::Scan;

	}
	Plugins::C3PO::Logger::debugMessage('DEBUGLOG '.main::DEBUGLOG);
	Plugins::C3PO::Logger::debugMessage('INFOLOG '.main::INFOLOG);
	Plugins::C3PO::Logger::debugMessage('loglevel '.$logLevel);
	
	Plugins::C3PO::Logger::debugMessage('BIN '.$Bin);
	Plugins::C3PO::Logger::debugMessage('C-3PO '.$C3PODir);
	Plugins::C3PO::Logger::debugMessage('Server '.$serverFolder);
	Plugins::C3PO::Logger::debugMessage('inc0'.Data::Dump::dump(@inc0));
	Plugins::C3PO::Logger::debugMessage('inc1'.Data::Dump::dump(@inc1));
	Plugins::C3PO::Logger::debugMessage('inc2'.Data::Dump::dump(@inc2));
	Plugins::C3PO::Logger::debugMessage('INC '.Data::Dump::dump(@INC));
	
	Plugins::C3PO::Logger::debugMessage('Inc: '.$INC{'Module/Load.pm'});
	Plugins::C3PO::Logger::debugMessage('Inc: '.$INC{'File/HomeDir.pm'});
	Plugins::C3PO::Logger::debugMessage('Inc: '.$INC{'Getopt/Long.pm'});
	Plugins::C3PO::Logger::debugMessage('Inc: '.$INC{'FileHandle.pm'});
	Plugins::C3PO::Logger::debugMessage('Inc: '.$INC{'Data/Dump.pm'});
	Plugins::C3PO::Logger::debugMessage('Inc: '.$INC{'YAML/XS.pm'});
	Plugins::C3PO::Logger::debugMessage('Inc: '.$INC{'Audio/Scan.pm'});
	
	$isDebug= $options->{debug};
	if ($isDebug){
		Plugins::C3PO::Logger::infoMessage('Running in debug mode');
	}
	Plugins::C3PO::Logger::debugMessage('options '.Data::Dump::dump($options));
	
	if (defined $options->{hello}) {

		my $message="C-3PO says $options->{hello}! see $logfile for errors ".
					"log level is $logLevel";
					
		print $message;

		Plugins::C3PO::Logger::infoMessage($message);
		Plugins::C3PO::Logger::debugMessage('Bin is: '.$Bin);
		Plugins::C3PO::Logger::debugMessage('PluginDir is: '.$C3PODir);
		Plugins::C3PO::Logger::verboseMessage('Inc is: '.Data::Dump::dump(@INC));
		exit 0;
	}
	
	if (!defined $options->{prefFile}) {Plugins::C3PO::Logger::dieMessage("Missing preference file in options")}
	
	my $prefFile=$options->{prefFile};
	Plugins::C3PO::Logger::debugMessage ('Pref File: '.$prefFile);

	my $prefs=loadPreferences($prefFile);
	if (!defined $prefs) {Plugins::C3PO::Logger::dieMessage("Invalid pref file in options")}
	Plugins::C3PO::Logger::debugMessage ('Prefs: '.Data::Dump::dump($prefs));
	
	#use prefs only if not already in options.
	if (!defined $serverFolder){
	
		$serverFolder=$prefs->{'serverFolder'};
		if (!defined $serverFolder) {Plugins::C3PO::Logger::dieMessage("Missing ServerFolder")}
		Plugins::C3PO::Logger::debugMessage ('server foder: '.$serverFolder);
	}
	if (!defined $options->{logFolder}){
		
		my $logFolder=$prefs->{'logFolder'};
		if (!defined $logFolder) {Plugins::C3PO::Logger::warnMessage("Missing log directory in preferences")}
		Plugins::C3PO::Logger::debugMessage ('log foder: '.$logFolder);

		Plugins::C3PO::Logger::verboseMessage("Swithing log file to ".catdir($logFolder, 'C-3PO.log'));

		$main::logfile= catdir($logFolder, 'C-3PO.log');

		Plugins::C3PO::Logger::verboseMessage("Now log file is $main::logfile");
	}
	
	if (defined $options->{headerRestorer}){ 
		
		#running as header restorer or dummy transcoder.
		my $infile = $options->{file};
		my $buffer;
		
		
		if ($infile){
		
			Plugins::C3PO::Logger::infoMessage('Running as header restorer - header file :'.$infile);

			my $in = FileHandle->new();

			$in->open("< $infile") or die "HeaderRestorer: Not able to open the file for reading $!" ;
			
			Plugins::C3PO::Logger::infoMessage("$infile opened");
			
			binmode ($in);
			
			Plugins::C3PO::Logger::infoMessage("HeaderRestorer: start copy from $infile");
				
			while (
				sysread ($in, $buffer, 65536)	# read in (up to) 64k chunks, write
				and syswrite STDOUT, $buffer	# exit if read or write fails
			  ) {
				Plugins::C3PO::Logger::debugMessage(
					"HeaderRestorer: copied 64Kb chunk from $infile");
			}
			if ($!){
				Plugins::C3PO::Logger::errorMessage(
					"HeaderRestorer: Problem writing header from file:  $!");
			} else{
		
			Plugins::C3PO::Logger::infoMessage(
				"HeaderRestorer: end copy from $infile");
			}	
			close ($in);
			
			unlink $infile;
			if ($!){
				Plugins::C3PO::Logger::errorMessage(
					"HeaderRestorer: Unable to remove $infile: $!");
			} else{
		
			Plugins::C3PO::Logger::infoMessage(
				"HeaderRestorer: $infile removed");
			}	
		} else{
			Plugins::C3PO::Logger::infoMessage('Running as Dummy Transcoder (no header file)');
		}
		
		Plugins::C3PO::Logger::infoMessage(
				"Start copy from STDIN");
		while (
			sysread (STDIN, $buffer, 65536)	# read in (up to) 64k chunks, write
			and syswrite STDOUT, $buffer	# exit if read or write fails
			) {
				Plugins::C3PO::Logger::debugMessage(
				"copied 64Kb chunk from STDIN");
		}
		if ($!){		

			Plugins::C3PO::Logger::errorMessage(
				"Problem writing body from STDIN: $!");
		} else{
		
			Plugins::C3PO::Logger::infoMessage(
				"end copy from STDIN");
		}		
		flush STDOUT;
	
	} else{

		#running as C-3PO.
		Plugins::C3PO::Logger::infoMessage('Running as Transcoder');
		
		if (!defined $options->{clientId}) {Plugins::C3PO::Logger::dieMessage("Missing clientId in options")}
		if (!defined $options->{inCodec})  {Plugins::C3PO::Logger::dieMessage("Missing input codec in options")}

		my $clientId= $options->{clientId};
		Plugins::C3PO::Logger::debugMessage ('clientId: '.$clientId);

		my $client=Plugins::C3PO::Shared::buildClientString($clientId);
		Plugins::C3PO::Logger::debugMessage ('client: '.$client);
		
		my $transcodeTable=Plugins::C3PO::Shared::buildTranscoderTable($client,$prefs,$options);
	
		Plugins::C3PO::Logger::verboseMessage('Transcoder table : '.Data::Dump::dump($transcodeTable));
		Plugins::C3PO::Logger::verboseMessage('@INC : '.Data::Dump::dump(@INC));

		$transcodeTable->{'inCodec'}=$options->{inCodec};
		my $commandTable=Plugins::C3PO::Transcoder::buildCommand($transcodeTable);

		executeCommand($commandTable->{'command'});
		
	}
}
# launch command and die, passing Output directly to LMS, so far the best.
# but does not work in Windows with I capability (socketwrapper involved)
#
sub executeCommand{
	my $command=shift;

	#some hacking on quoting and escaping for differents Os...
	$command= Plugins::C3PO::Shared::finalizeCommand($command);

	Plugins::C3PO::Logger::infoMessage(qq(execute command  : $command));
	Plugins::C3PO::Logger::verboseMessage($main::isDebug ? 'in debug' : 'production');
	
	if ($main::isDebug){
	
		return $command;
	
	} else {
	
		my @args =($command);
		exec @args or &Plugins::C3PO::Logger::errorMessage("couldn't exec command: $!");	
	}
}
sub loadPreferences {
	my $file=shift;
	
	my $prefs;
	$prefs = eval {YAML::XS::LoadFile($file) };

	if ($@) {
		Plugins::C3PO::Logger::warnMessage("Unable to read prefs from $file : $@\n");
	}
	return $prefs;
}
sub getOptions{

	#Data::Dump::dump(@ARGV);

	my $options={};
	if ( @ARGV > 0 ) {

		Getopt::Long::GetOptions(	
			'b' => \$options->{headerRestorer},
			'd' => \$options->{debug},
			'h=s' => \$options->{hello},
			'l=s' => \$options->{logFolder},
			'x=s' => \$options->{serverFolder},
			'p=s' => \$options->{prefFile},
			'c=s' => \$options->{clientId},
			'i=s' => \$options->{inCodec},
			'o=s' => \$options->{outCodec},
			't=s' => \$options->{startTime},
			'v=s' => \$options->{endTime},
			's=s' => \$options->{startSec},
			'u=s' => \$options->{endSec},
			'w=s' => \$options->{durationSec},
			'r=s' => \$options->{forcedSamplerate},
			'nodebuglog' => \$options->{nodebuglog}, #already detected
			'noinfolog' => \$options->{noinfolog}, #already detected
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
sub addToArray{
	my $in=shift;
	my $out=shift;
	
	my $found;

	$found=0;
	for my $o (@$out){
		if ($o eq $in){
			$found=1;
			last;
		}
	}
	if (!$found){
		push @$out, $in;
	}
}
1;

