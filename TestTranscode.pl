##!/usr/bin/perl
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
use strict;

use FindBin qw($Bin);
use lib $Bin;

use File::Spec::Functions qw(:ALL);
use File::Basename;

my $C3PODir=$Bin;
my $lib = File::Spec->rel2abs(catdir($C3PODir, 'lib'));
my $cpan= File::Spec->rel2abs(catdir($C3PODir,'CPAN'));

my @i=($C3PODir,$lib,$cpan);

unshift @INC, Utils::Config::expandINC($Bin);

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
use Utils::Config;

require FileHandle;
require Getopt::Long;
require YAML::XS;
require File::HomeDir;
require Data::Dump;
require Audio::Scan;

require Formats::Format;
require Formats::Wav;
require Formats::Aiff;
require Formats::Flac;
require Formats::Alac;

################################################################################
# Fake Options #

our $options={};
$options->{debug}=1;
$options->{hello}=undef;
$options->{clientId}= 'e8:de:27:03:05:b2';
$options->{prefFile}="C:\\Documents and Settings\\All Users\\Dati applicazioni\\SqueezeboxTest\\prefs\\plugin\\C3PO.prefs";
$options->{logFolder}="C:\\Documents and Settings\\All Users\\Dati applicazioni\\SqueezeboxTest\\logs";

#values to be settled in test cases:

$options->{file}=undef;
$options->{inCodec}=undef;
$options->{outCodec}=undef;

$options->{startTime}=undef;
$options->{endTime}=undef;
$options->{startSec}=undef;
$options->{endSec}=undef;
$options->{durationSec}=undef;

$options->{forcedSamplerate}=undef;

# Fake Preferences #

our $prefs={
  id                       => $options->{clientId},
  macaddress               => $options->{clientId},
  model                    => "squeezelite",
  modelName                => "SqueezeLite",
  name                     => "Squeezelite-R2\@Win",
  "maxSupportedSamplerate" => 192_000,
  resampleTo               => "X",
  resampleWhen             => "A",
  outCodec                 => "wav",
  outBitDepth              => 2,
  phase                    => "M",
  quality                  => "v",
  aliasing                 => "on",
  bandwidth                => 907,
  dither                   => "on",
  gain                     => 3,
  useGlogalSettings		   => "on",
  
  serverFolder             => "G:/Sviluppo/slimserver",
  C3POfolder               => "G:\\Sviluppo\\slimserver\\Plugins\\C3PO",
  logFolder                => "C:\\\\Documents and Settings\\\\All Users\\\\Dati applicazioni\\\\SqueezeboxTest\\\\logs",
  pathToC3PO_exe           => "G:\\Sviluppo\\slimserver\\Plugins\\C3PO\\Bin\\MSWin32-x86-multi-thread\\C-3PO.exe",
  pathToC3PO_pl            => "G:\\Sviluppo\\slimserver\\Plugins\\C3PO\\C-3PO.pl",
  pathToPerl               => "C:\\Perl\\bin\\perl.exe",
  C3POwillStart            => "exe",
  pathToFFmpeg             => "G:\\Sviluppo\\slimserver\\Bin\\MSWin32-x86-multi-thread\\ffmpeg.exe",
  pathToFaad               => "G:\\Sviluppo\\slimserver\\Bin\\MSWin32-x86-multi-thread\\faad.exe",
  pathToFlac			   => "G:\\Sviluppo\\slimserver\\Bin\\MSWin32-x86-multi-thread\\flac.exe",
  pathToSox                => "G:\\Sviluppo\\slimserver\\Bin\\MSWin32-x86-multi-thread\\sox.exe",
};

my $clientPrefs= {
  id                       => "e8:de:27:03:05:b2",
  macaddress               => "e8:de:27:03:05:b2",
  model                    => "squeezelite",
  modelName                => "SqueezeLite",
  name                     => "Squeezelite-R2\@Win",
  "maxSupportedSamplerate" => 192_000,
  resampleTo               => "X",
  resampleWhen             => "A",
  outCodec                 => "wav",
  outBitDepth              => 3,
  outByteOrder             => "L",
  outEncoding              => "s",               
  phase                    => "M",
  quality                  => "v",
  aliasing                 => "on",
  bandwidth                => 907,
  dither                   => "on",
  gain                     => 3,
  useGlogalSettings		   => "on",
};

my $samplerates = {
	'11025' => 'on',
    '12000' => 'on',
    '16000' => 'on',
    '22050' => 'on',
    '24000' => 'on',
    '32000' => 'on',
    '44100' => 'on',
    '48000' => 'on',
    '8000' => 'on',
    '88200' => 'on',
    '96000' => 'on',
	'176400' => undef,
    '192000' => undef,
	'352800' => 0,
    '384000' => 0,
};
my $codecs ={

	wav => 1,
	aif => 1,
	flc => 1,
};
my $seek ={

	wav => 1,
	aif => 0,
	flc => 0,
};
my $stdin ={

	wav => 0,
	aif => 0,
	flc => 1,
};   
my $convert ={

	wav => 1,
	aif => 1,
	flc => 1,
};
my $resample={
	wav => 1,
	aif => 1,
	flc => 1,
}; 

	
our $client=Plugins::C3PO::Shared::buildClientString($options->{clientId});

$prefs->{$client}=$clientPrefs;
$prefs->{$client}->{sampleRates}=$samplerates;
$prefs->{$client}->{codecs}=$codecs;
$prefs->{$client}->{enableSeek}=$seek;
$prefs->{$client}->{enableStdin}=$stdin;
$prefs->{$client}->{enableConvert}=$convert;
$prefs->{$client}->{enableResample}=$resample;

##############################################################################

our $isDebug;
our $logfile;
our $logLevel = DEBUGLOG ? 'debug' : INFOLOG ? 'info' : 'warn';

$logLevel='verbose'; #to show more debug mesages
#$logLevel='debug';
$logLevel='info';
#$logLevel='warn'; #to show less debug mesages

###############################################################################

require Test::TestSettings;
require Test::Wav;
require Test::Aif;
require Test::Flc8;

# Not able to dinamically build namespaces...
my @testNameSpaces= (\%Test::Wav::, \%Test::Aif::, \%Test::Flc8::);

preInit();
executeTests();
#doTest(\%Test::Wav::,'test_split_FLAC_flc_start_end_FFMPEG_resampling_wav');

###############################################################################
sub preInit{
#
	# until we read preferences, we don't know where logfile is.
	# use a deault one instead.
	#
	$logfile = Plugins::C3PO::Logger::guessFileFatal('C-3PO.fatal');
	
	#my $options=getOptions();
	if (!defined $options) {Plugins::C3PO::Logger::dieMessage("Missing options")}
	$isDebug= $options->{debug};
	
	if (defined $options->{logFolder}){
	
		my $logFolder=$options->{logFolder};

		Plugins::C3PO::Logger::debugMessage ('found log foder in options: '.$logFolder);
		
		my $newLogfile= Plugins::C3PO::Logger::getLogFile($logFolder);
		Plugins::C3PO::Logger::verboseMessage("Swithing log file to ".$newLogfile);

		$logfile= $newLogfile;
		Plugins::C3PO::Logger::verboseMessage("Now log file is $logfile");
	
	}
	if (defined $options->{hello}) {
		
		my $message="C-3PO says $options->{hello}! see $main::logfile for errors";
		print $message;
		Plugins::C3PO::Logger::debugMessage($message);
		exit 0;
	}
	
	if (!defined $options->{clientId}) {Plugins::C3PO::Logger::dieMessage("Missing clientId in options")}
	if (!defined $options->{prefFile}) {Plugins::C3PO::Logger::dieMessage("Missing preference file in options")}
	#if (!defined $options->{inCodec})  {Plugins::C3PO::Logger::dieMessage("Missing input codec in options")}
	
	my $prefFile=$options->{prefFile};
	Plugins::C3PO::Logger::debugMessage ('Pref File: '.$prefFile);
	
	#my $prefs=loadPreferences($prefFile);
	if (!defined $prefs) {Plugins::C3PO::Logger::dieMessage("Invalid pref file in options")}

	Plugins::C3PO::Logger::infoMessage('debug? '.$isDebug);
	Plugins::C3PO::Logger::debugMessage('options '.Data::Dump::dump($options));
	Plugins::C3PO::Logger::debugMessage ('Prefs: '.Data::Dump::dump($prefs));
}

sub start{
	
	my $options=shift;
	my $prefs=shift;
	
	my $clientId= $options->{clientId};
	Plugins::C3PO::Logger::debugMessage ('clientId: '.$clientId);

	my $client=Plugins::C3PO::Shared::buildClientString($clientId);
	Plugins::C3PO::Logger::debugMessage ('client: '.$client);
	
	my $serverFolder=$prefs->{'serverFolder'};
	if (!defined $serverFolder) {Plugins::C3PO::Logger::dieMessage("Missing ServerFolder")}
	Plugins::C3PO::Logger::debugMessage ('server foder: '.$serverFolder);

	#use prefs only if not already in options.
	if (!defined $options->{logFolder}){
		
		my $logFolder=$prefs->{'logFolder'};
		if (!defined $logFolder) {Plugins::C3PO::Logger::warnMessage("Missing log directory in preferences")}
		Plugins::C3PO::Logger::debugMessage ('log foder: '.$logFolder);

		Plugins::C3PO::Logger::verboseMessage("Swithing log file to ".catdir($logFolder, 'C-3PO.log'));

		$main::logfile= catdir($logFolder, 'C-3PO.log');

		Plugins::C3PO::Logger::verboseMessage("Now log file is $main::logfile");
	}
	my $transcodeTable=Plugins::C3PO::Shared::buildTranscoderTable($client,$prefs,$options);
	
	Plugins::C3PO::Logger::verboseMessage('Transcoder table : '.Data::Dump::dump($transcodeTable));
	Plugins::C3PO::Logger::verboseMessage('@INC : '.Data::Dump::dump(@INC));
	
	$transcodeTable->{'inCodec'}=$options->{inCodec};
	my $commandTable=Plugins::C3PO::Transcoder::buildCommand($transcodeTable);

	execCommand($commandTable->{'command'});

}
sub execCommand{
	my $command=shift;
	
	#some hacking on quoting and escaping for differents Os...
	$command= Plugins::C3PO::Shared::finalizeCommand($command);

	Plugins::C3PO::Logger::infoMessage(qq(Command is: $command));
	Plugins::C3PO::Logger::verboseMessage($main::isDebug ? 'in debug' : 'production');
	if ($main::isDebug){
	
		return $command;
	
	} else {
	
		my @args =($command);
		exec @args or &Plugins::C3PO::Logger::errorMessage("couldn't exec command: $!");
	
	}
}
sub executeTests{
	
	my $result=1;
	
	my $cnt=0;
	my $failed=0;
	
	for my $n (@testNameSpaces){

		my @cases = getTestCases($n);
		
		for my $c (@cases){
			
			my $ok= doTest($n, $c);
			
			if (!$ok) {
				
				$result=0;
				$failed= $failed+1;
				
			} 
			
			$cnt= $cnt+1;
		}
	}
	if ($result){
	
		Plugins::C3PO::Logger::infoMessage('*** All '.$cnt.' tests passed');
		
	} else{
	
		Plugins::C3PO::Logger::errorMessage('*** '.$cnt.' tests - '.$failed.' failed');
		
	}
}

sub getTestCases{
	my $nameSpace= shift;

	my @out=();
	#dump $nameSpace;
	for my $k (sort keys %$nameSpace) {
	
		if (defined *{$nameSpace->{$k}}{CODE}) {
			push @out, $k;
		};
	}
	#dump @out;
	return @out;
}
sub doTest{
	my $namespace=shift;
	my $test=shift;
	
	my $ok=0;

	if (! exists $namespace->{$test}) {
			Plugins::C3PO::Logger::infoMessage("Unknown command $test\n in ".Data::Dump::dump($namespace));}	
	else{
		
		Plugins::C3PO::Logger::infoMessage('*** Test  : '.$test);
		
		my $code	= $namespace->{$test};
		my $result  = $code->();
		$ok= evaluateTest($result, start($options,$prefs));
		
		Plugins::C3PO::Logger::infoMessage(
				'Result    :'.($ok ? 'passed' : 'failed'));
	}
	return $ok;
}

sub evaluateTest{
	my $expected=shift || "";
	my $got=shift || "";
	
	Plugins::C3PO::Logger::infoMessage('Expected  : '.$expected);
	if ($got eq $expected) {return 1};
	return 0;

}