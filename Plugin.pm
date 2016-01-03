#!/usr/bin/perl
# $Id$
#
# Handles server side file type conversion and resampling.
# Replace custom-convert.conf.
#
# To be used mainly with Squeezelite-R2 
# (https://github.com/marcoc1712/squeezelite/releases)
#
# Logitech Media Server Copyright 2001-2011 Logitech.
# This Plugin Copyright 2015 Marco Curti (marcoc1712 at gmail dot com)
#
# C3PO is inspired by the DSD Player Plugin by Kimmo Taskinen <www.daphile.com>
# and Adrian Smith (triode1@btinternet.com), but it  does not replace it, 
# DSD Play is still needed to play dsf and dff files.
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
################################################################################

package Plugins::C3PO::Plugin;


use strict;
use warnings;

use FindBin qw($Bin);
use lib $Bin; #not needed here, we just neeed to know $Bin

use Data::Dump qw(dump pp);
use File::Spec::Functions qw(:ALL);
use File::Basename;

my $pluginPath=__FILE__;
my $C3PODir= File::Basename::dirname($pluginPath);

use lib rel2abs(catdir($C3PODir, 'lib'));
use lib rel2abs(catdir($C3PODir,'CPAN'));

require File::HomeDir;

use base qw(Slim::Plugin::Base);

if ( main::WEBUI ) {
	require Plugins::C3PO::Settings;
	require Plugins::C3PO::PlayerSettings;
}

use Plugins::C3PO::Shared;
use Plugins::C3PO::Logger;
use Plugins::C3PO::Transcoder;
use Plugins::C3PO::OsHelper;
use Plugins::C3PO::FfmpegHelper;
use Plugins::C3PO::FlacHelper;
use Plugins::C3PO::FaadHelper;
use Plugins::C3PO::SoxHelper;
use Plugins::C3PO::Utils::Config;
use Plugins::C3PO::Utils::File;
use Plugins::C3PO::Utils::Log;

use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Strings qw(string);
use Slim::Player::TranscodingHelper;

my $preferences = preferences('plugin.C3PO');
my $serverPreferences = preferences('server');

my $log = Slim::Utils::Log->addLogCategory( {
	category     => 'plugin.C3PO',
	defaultLevel => 'ERROR',
	description  => 'PLUGIN_C3PO_MODULE_NAME',
} );

##
#
# C-3PO capabilities
#
# codecs/formats supported or filtered.
#
my %supportedCodecs=();
$supportedCodecs{'wav'}{'supported'}=1;
$supportedCodecs{'wav'}{'defaultEnabled'}=1;
$supportedCodecs{'wav'}{'defaultEnableSeek'}=1;
$supportedCodecs{'wav'}{'defaultEnableStdin'}=0;
$supportedCodecs{'aif'}{'supported'}=1;
$supportedCodecs{'aif'}{'defaultEnabled'}=1;
$supportedCodecs{'aif'}{'defaultEnableSeek'}=0;
$supportedCodecs{'aif'}{'defaultEnableStdin'}=0;
$supportedCodecs{'flc'}{'supported'}=1;
$supportedCodecs{'flc'}{'defaultEnabled'}=1;
$supportedCodecs{'flc'}{'defaultEnableSeek'}=0;
$supportedCodecs{'flc'}{'defaultEnableStdin'}=1;
$supportedCodecs{'alc'}{'supported'}=1;
$supportedCodecs{'alc'}{'defaultEnabled'}=1;
$supportedCodecs{'alc'}{'defaultEnableSeek'}=0;
$supportedCodecs{'alc'}{'defaultEnableStdin'}=0;
$supportedCodecs{'loc'}{'unlisted'}=1;
$supportedCodecs{'pcm'}{'unlisted'}=1;
$supportedCodecs{'dff'}{'supported'}=0;
$supportedCodecs{'dsf'}{'supported'}=0;

my %previousCodecs=();

#
# samplerates
#
# List could be extended if and when some new player with higher capabilities 
# will be introduced, this is from squeezeplay.pm at 10/10/2015.
#
# my %pcm_sample_rates = (
#	  8000 => '5',
# 	 11025 => '0',
#	 12000 => '6',
#	 16000 => '7',
#	 22050 => '1',
#	 24000 => '8',
#	 32000 => '2',
#	 44100 => '3',
#	 48000 => '4',
#	 88200 => ':',
#	 96000 => '9',
#	176400 => ';',
#	192000 => '<',
#	352800 => '=',
#	384000 => '>',
#);
my %OrderedsampleRates = (
	"a" => 8000,
	"b" => 11025,
	"c" => 12000,
	"d" => 16000,
	"e" => 22050,
	"f" => 24000,
	"g" => 32000,
	"h" => 44100,
	"i" => 48000,
	"l" => 88200,
	"m" => 96000,
	"n" => 176400,
	"o" => 192000,
	"p" => 352800,
	"q" => 384000,
	"r" => 705600,
	"s" => 768000,
);

my $capabilities={};
$capabilities->{'codecs'}=\%supportedCodecs;
$capabilities->{'samplerates'}=\%OrderedsampleRates;

if (main::DEBUGLOG && $log->is_debug) {
	$log->debug("C-3PO-capabilities: ".dump($capabilities));
}
#
###############################################

sub getCapabilities{
	return $capabilities;
}

# List of the preference in general settings and possibly inherited by 
# players.

sub refreshClientPreferences{
	my $client = shift;
	
	if ($client){
		
		#It's the first time client is connecting.
		if (!defined($preferences->client($client)->get('resampleWhen'))){
	
			$preferences->client($client)->set('useGlogalSettings', 'on');
		}
	
		if  ($preferences->client($client)->get('useGlogalSettings')){

				for my $item (Plugins::C3PO::Shared::getSharedPrefNameList()){
					$preferences->client($client)->set($item, $preferences->get($item));
				}
		}
	}
	return $preferences;
}
sub getPreferences{
	return $preferences;
}
my $pathToPerl;
my $pathToC3PO_pl;
my $pathToC3PO_exe;

my $pathToHeaderRestorer_pl;
my $pathToHeaderRestorer_exe;

my $pathToprefFile;
my $pathToFlac;
my $pathToSox;
my $pathToFaad;
my $pathToFFmpeg;

my $serverFolder;
my $C3POfolder;
my $logFolder;

sub initFilesLocations {

	$serverFolder	= $Bin;
	$logFolder	= Slim::Utils::OSDetect::dirsFor('log');
	$pathToprefFile = catdir(Slim::Utils::OSDetect::dirsFor('prefs'), 'plugin', 'C3PO.prefs');
	
	$pathToFlac     = Slim::Utils::Misc::findbin("flac");
	$pathToSox      = Slim::Utils::Misc::findbin("sox");
	$pathToFaad     = Slim::Utils::Misc::findbin("faad");
	$pathToFFmpeg   = Slim::Utils::Misc::findbin("ffmpeg");
	
	$pathToPerl     = Slim::Utils::Misc::findbin("perl");
	$pathToC3PO_exe = Slim::Utils::Misc::findbin("C-3PO");
	$pathToC3PO_pl	= calcPathToC3PO_pl();
	
	$C3POfolder		= File::Basename::dirname $pathToC3PO_pl;
	
	$pathToHeaderRestorer_pl  = catdir($C3POfolder, 'HeaderRestorer.pl');
	$pathToHeaderRestorer_exe = Slim::Utils::Misc::findbin("HeaderRestorer");
	
}
sub calcPathToC3PO_pl{

	my @dirs = Slim::Utils::OSDetect::dirsFor('Plugins');

	for my $d (@dirs){
		
		my $path=catdir($d, 'C3PO', 'C-3PO.pl');

		if  (!(-e $path)){next;}
		return $path;
	}

	#last chance...
	if (!defined $pathToC3PO_pl){
		return catdir($C3PODir, 'C-3PO.pl');
	}
	return undef;
}
my $C3POwillStart;

sub testC3PO{
	
	if (!testC3POEXE()){
	
		if (main::INFOLOG && $log->is_info) {
			 $log->info('invalid path to C-3PO : '.$pathToC3PO_exe);
		}
	}else {
		
		if (main::INFOLOG && $log->is_info) {
			 $log->info('using C-3PO executable: '.$pathToC3PO_exe);
		}
		return 'exe';
	}
	
	if (!testC3POPL()){
		
		if (main::INFOLOG && $log->is_info) {
			 $log->info('invalid path to perl or C-3PO.pl :');
			 $log->info('perl    : '.$pathToPerl);
			 $log->info('C-3PO.Pl: '.$pathToC3PO_pl);
		}
	}else {
		
		if (main::INFOLOG && $log->is_info) {
			 $log->info('using installed perl to run C-3PO.pl');
			 $log->info('perl    : '.$pathToPerl);
			 $log->info('C-3PO.Pl: '.$pathToC3PO_pl);
		}
		return 'pl';
	}
	
	$log->warn('WARNING: C3PO will not start on call: ');
	$log->warn('WARNING: Perl path: '.$pathToPerl);
	$log->warn('WARNING: C-3PO.pl path: '.$pathToC3PO_pl);
	$log->warn('WARNING: C-3PO path: '.$pathToC3PO_exe);
	return 0;
}
sub testC3POEXE{

	#test if C3PO.PL will start on LMS calls
	
	if  (!(-e $pathToC3PO_exe)){
		#$log->warn('WARNING: wrong path to C-3PO.exe, will not start - '.$pathToC3PO_exe);
		return 0;
	}
		
	my $command= qq("$pathToC3PO_exe" -h hello -l "$logFolder");
	
	if (! main::DEBUGLOG) {
	
		$command = $command." --nodebuglog";
	}
	
	if (! main::INFOLOG){
	
		$command = $command." --noinfolog";
	}
	
	$command= Plugins::C3PO::Shared::finalizeCommand($command);
	
	
	if (main::INFOLOG && $log->is_info) {
			 $log->info("command: ".$command);
	}
	
	my $ret= `$command`;
	my $err=$?;
	
	if (!$err==0){
		$log->warn('WARNING: '.$err.$ret);
		return 0;}
	
	if (main::INFOLOG && $log->is_info) {
			 $log->info($ret);
	}
	return 1;
}
sub testC3POPL{

	#test if C3PO.PL will start on LMS calls
	if  (!(-e $pathToPerl)){
		#$log->warn('WARNING: wrong path to perl, C-3PO.pl, will not start - '.$pathToPerl);
		return 0;
	}
	
	if  (!(-e $pathToC3PO_pl)){
		#$log->warn('WARNING: wrong path to C-3PO.pl, will not start - '.$pathToC3PO_pl);
		return 0;
	}

	my $command= qq("$pathToPerl" "$pathToC3PO_pl" -h hello -l "$logFolder");
	
	if (! main::DEBUGLOG || ! $log->is_debug) {
	
		$command = $command." --nodebuglog";
	}
	
	if (! main::INFOLOG || ! $log->is_info){
	
		$command = $command." --noinfolog";
	}
	$command= Plugins::C3PO::Shared::finalizeCommand($command);
	
	if (main::INFOLOG && $log->is_info) {
			 $log->info('command: '.$command);
	}
	
	my $ret= `$command`;
	my $err=$?;
	
	if (!$err==0){
		$log->warn('WARNING: '.$err.$ret);
		return 0;}
	
	if (main::INFOLOG && $log->is_info) {
			 $log->info($ret);
	}
	return 1;
}
sub getPathToPrefFile{
	return $pathToprefFile;
}

## required methods

sub getDisplayName {
	return 'PLUGIN_C3PO_MODULE_NAME';
}
	
sub initPlugin {
	my $class = shift;

	$class->SUPER::initPlugin(@_);
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug('initPlugin');	
	}

	if ( main::WEBUI ) {
		Plugins::C3PO::Settings->new;
		Plugins::C3PO::PlayerSettings->new;
	}
	
	# init preferences
	$preferences->init({		
		serverFolder				=> $serverFolder,
		logFolder					=> $logFolder,
		pathToFlac					=> $pathToFlac,
		pathToSox					=> $pathToSox,
		pathToFaad					=> $pathToFaad,
		pathToFFmpeg				=> $pathToFFmpeg,
		pathToC3PO_pl				=> $pathToC3PO_pl,
		pathToC3PO_exe				=> $pathToC3PO_exe,
		C3POfolder					=> $C3POfolder,
		pathToPerl					=> $pathToPerl,
		C3POwillStart				=> $C3POwillStart,
		pathToHeaderRestorer_pl		=>  $pathToHeaderRestorer_pl,
		pathToHeaderRestorer_exe	=> $pathToHeaderRestorer_exe,
		resampleWhen				=> "A",
		resampleTo					=> "S",
		outCodec					=> "wav",
		outBitDepth					=> 3,
		#outChannels					=> 2,
		gain						=> 3,
		quality						=> "v",
		phase						=> "M",
		aliasing					=> "on",
		bandwidth					=> 907,
		dither						=> "on",
		extra						=> "",
	});
	
	#check codec list.
	my $codecList=initCodecs();
		
	#check File location at every startup.
	initFilesLocations();
	
	#test if C-3PO will raise up on call.
	$C3POwillStart=testC3PO();

	#Store them as preferences to be retieved and used by C3PO.
	$preferences->set('pathToPerl', $pathToPerl);
	#$preferences->set('pathToC3PO', undef);
	$preferences->set('pathToC3PO_exe', $pathToC3PO_exe);
	$preferences->set('pathToC3PO_pl', $pathToC3PO_pl);
	
	$preferences->set('C3POwillStart', $C3POwillStart);
	
	$preferences->set('pathToHeaderRestorer_pl', $pathToHeaderRestorer_pl);
	$preferences->set('pathToHeaderRestorer_exe', $pathToHeaderRestorer_exe);
	
	$preferences->set('serverFolder', $serverFolder);
	$preferences->set('logFolder', $logFolder);
	$preferences->set('C3POfolder', $C3POfolder);
	
	$preferences->set('pathToFlac', $pathToFlac);
	$preferences->set('pathToSox', $pathToSox);
	$preferences->set('pathToFaad', $pathToFaad);
	$preferences->set('pathToFFmpeg', $pathToFFmpeg);

	disableProfiles();

	# Subscribe to new client events
	Slim::Control::Request::subscribe(
		\&newClientCallback, 
		[['client'], ['new']],
	);
	
	# Subscribe to reconnect client events
	Slim::Control::Request::subscribe(
		\&clientReconnectCallback, 
		[['client'], ['reconnect']],
	);
}
sub shutdownPlugin {
	Slim::Control::Request::unsubscribe( \&newClientCallback );
	Slim::Control::Request::unsubscribe( \&clientReconnectCallback );
}

sub newClientCallback {
	my $request = shift;
	my $client  = $request->client() || return;
	
	return clientCalback($client,"new");
}

sub clientReconnectCallback {
	my $request = shift;
	my $client  = $request->client() || return;
	
	return clientCalback($client,"reconnect");
}

sub clientCalback{
	my $client = shift;
	my $type = shift;
	
	refreshClientPreferences($client);
	my $prefs= getPreferences($client);

	my $id= $client->id();
	my $macaddress= $client->macaddress();
	my $modelName= $client->modelName();
	my $model= $client->model();
	my $name= $client->name();
	my $maxSupportedSamplerate= $client->maxSupportedSamplerate();
	
	my $samplerateList= initSampleRates($client);
	my $clientCodecList=initClientCodecs($client);
	
	if (main::INFOLOG && $log->is_info) {
			 $log->info("$type ClientCallback received from \n".
						"id:                     $id \n".
						"mac address:            $macaddress \n".
						"modelName:              $modelName \n".
						"model:                  $model \n".
						"name:                   $name \n".
						"max samplerate:         $maxSupportedSamplerate \n".
						"supported sample rates: $samplerateList \n".
						"supported codecs :      $clientCodecList".
						"");
	}
	#register the new client in preferences.
	$preferences->client($client)->set('id',$id);
	$preferences->client($client)->set('macaddress', $macaddress);
	$preferences->client($client)->set('modelName', $modelName);
	$preferences->client($client)->set('model',$model);
	$preferences->client($client)->set('name', $name);
	$preferences->client($client)->set('maxSupportedSamplerate',$maxSupportedSamplerate);
	
	setupTranscoder($client);

	return 1;
}

sub initSampleRates{
	my $client = shift;
	
	my $maxSupportedSamplerate= $client->maxSupportedSamplerate();
	
	my $sampleRateList="";
	my $prefSampleRates;
	
	my $prefs= getPreferences($client);

	if (!defined($prefs->client($client)->get('sampleRates'))){
	
		$prefSampleRates = defaultSampleRates($client);
	
	} else {
		
		$prefSampleRates = refreshSampleRates($client);
	}

	$sampleRateList= guessSampleRateList($maxSupportedSamplerate);

	$prefs->client($client)->set('sampleRates', translateSampleRates($prefSampleRates));

	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("New sampleRates: ".dump($prefSampleRates));
	}
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("New preferences: ".dump($prefs->client($client)->get('sampleRates')));
	}
	
	return ($sampleRateList);
}
sub defaultSampleRates{
	my $client=shift;
	
	my $caps=getCapabilities();
	my $capSamplerates= $caps->{'samplerates'};
	
	my $maxSupportedSamplerate= $client->maxSupportedSamplerate();
	
	my $prefSampleRates =();

	for my $rate (keys %$capSamplerates){
		if ($capSamplerates->{$rate} <= $maxSupportedSamplerate){
			$prefSampleRates->{$rate} = 1;
		} else {
			$prefSampleRates->{$rate} = 0;
		}
	}

	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("Default SampleRates: ".dump($prefSampleRates));
	}
	return $prefSampleRates;
}
sub refreshSampleRates{
	my $client=shift;
	
	my $prefs= getPreferences($client);
	my $caps=getCapabilities();
	my $capSamplerates= $caps->{'samplerates'};

	my $maxSupportedSamplerate= $client->maxSupportedSamplerate();
	
	my $prefRef = translateSampleRates($prefs->client($client)->get('sampleRates'));
	my $prefSampleRates =();

	for my $rate (keys %$prefRef){
	
		if (!exists $capSamplerates->{$rate}){
			next;
		}
		if ($capSamplerates->{$rate} <= $maxSupportedSamplerate){
			$prefSampleRates->{$rate} = $prefRef->{$rate};
		} else {
			$prefSampleRates->{$rate} = 0;
		}
	}
	for my $rate (keys %$capSamplerates){
		
		# rate is new added in supported
		if (!exists $prefSampleRates->{$rate}){
				$prefSampleRates->{$rate}=undef;
		} 
	}
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("Refreshed SampleRates: ".dump($prefSampleRates));
	}
	return $prefSampleRates
}
sub translateSampleRates{

	my $in = shift;
	my $caps=getCapabilities();
	my $ref= $caps->{'samplerates'};
	
	my $map={};
	my $out={};
	
	for my $k (keys %$ref){
		
		my $value=$ref->{$k};
		
		$map->{$k}=$value;
		$map->{$value}=$k;
	}
	
	for my $k (keys %$in){

		my $value=$in->{$k};
		my $transKey = $map->{$k};
		
		$out->{$transKey}=$value;
	}
	return $out;
	
}
sub guessSampleRateList{
	my $maxrate=shift || 44100;

	# $client only reports the max sample rate of the player, 
	# we here assume that ANY lower sample rate in the player 
	# pcm_sample_rates table is valid.
	#
	
	my $sampleRateList="";
	
	for my $k (sort(keys %OrderedsampleRates)){
		my $rate=$OrderedsampleRates{$k};
		
		if ($rate+1 > $maxrate+1) {next};
		
		if (length($sampleRateList)>0) {
			$sampleRateList=$sampleRateList." "
		}
		$sampleRateList=$sampleRateList.$rate;
	}

	return $sampleRateList;
}

sub initCodecs{
	my $client = shift;
	
	if ($client){
	
		return initClientCodecs($client)
	}
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug('initCodecs');	
	}
	my $prefs= getPreferences();
	my $codecList="";
	my $prefCodecs;
	
	if (!defined($prefs->get('codecs'))){
	
		$prefCodecs= defaultCodecs();

	} else {
		
		$prefCodecs = refreshCodecs();
	}
	#build the complete list string
	for my $codec (keys %$prefCodecs){

		if (length($codecList)>0) {

			$codecList=$codecList." ";
		}
		$codecList=$codecList.$codec;
	}
	$prefs->set('codecs', $prefCodecs);
	return ($codecList);
}

sub initClientCodecs{
	my $client = shift;
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug('initClientCodecs');	
	}
	
	my $prefs= getPreferences($client);
	my $codecList="";
	my $prefCodecs;
	my $prefEnableSeek;
	my $prefEnableStdin;
	my $prefEnableConvert;
	my $prefEnableResample;

	if (!defined($prefs->client($client)->get('codecs'))){
	
		($prefCodecs, $prefEnableSeek,$prefEnableStdin,
		 $prefEnableConvert,$prefEnableResample) = defaultClientCodecs($client);

	} else {
		
		($prefCodecs, $prefEnableSeek,$prefEnableStdin,
		 $prefEnableConvert,$prefEnableResample) = refreshClientCodecs($client);
	}
	#build the complete list string
	for my $codec (keys %$prefCodecs){

		if (length($codecList)>0) {

			$codecList=$codecList." ";
		}
		$codecList=$codecList.$codec;
	}
	$prefs->client($client)->set('codecs', $prefCodecs);
	$prefs->client($client)->set('enableSeek', $prefEnableSeek);
	$prefs->client($client)->set('enableStdin', $prefEnableStdin);
	$prefs->client($client)->set('enableConvert', $prefEnableConvert);
	$prefs->client($client)->set('enableResample', $prefEnableResample);

	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("New codecs: ".dump($prefCodecs));
	}
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("New preferences: ".dump($prefs->client($client)->get('codecs')));
	}
	
	return ($codecList);
}
sub defaultCodecs{
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug('defaultCodecs');	
	}
	
	my $caps=getCapabilities();
	my $codecs= $caps->{'codecs'};
	
	my $prefCodecs =();

	my $supported=();

	#add all the codecs supported by C-3PO.
	for my $codec (keys %$codecs) {
		$supported->{$codec} = $codecs->{$codec}->{'supported'};
	}
	#set default enabled and remove unlisted.
	for my $codec (keys %$supported){
		
		if (exists $codecs->{$codec}->{'unlisted'}){ next;}
		
		$prefCodecs->{$codec}=undef;
		
		if (exists $codecs->{$codec}->{'supported'}){

			$prefCodecs->{$codec}=$codecs->{$codec}->{'supported'} ? "on" :undef;;
		}	
	}
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("Default codecs  : ".dump($prefCodecs));
	}
	return ($prefCodecs);
}
sub defaultClientCodecs{
	my $client=shift;
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug('initClientCodecs');	
	}

	my $C3POprefs	= getPreferences();
	my $codecs		= $C3POprefs->get('codecs');
	
	my $capabilities=getCapabilities();
	my $caps= $capabilities->{'codecs'};
	
	my $prefCodecs =();
	my $prefEnableSeek =();
	my $prefEnableStdin =();
	my $prefEnableConvert =();
	my $prefEnableResample =();
	
	my $supported=();
	
	#add all the codecs supported by the client.
	for my $codec (Slim::Player::CapabilitiesHelper::supportedFormats($client)) {
		$supported->{$codec} = 0;
		
	}
	#add all the codecs supported by C-3PO.
	for my $codec (keys %$codecs) {
		$supported->{$codec} = $codecs->{$codec};
	}
	#set default enabled
	for my $codec (keys %$supported){
		
		if ($caps->{$codec}->{'unlisted'}){ next;}
		
		$prefCodecs->{$codec}=undef;
		$prefEnableSeek->{$codec}=undef;
		$prefEnableStdin->{$codec}=undef;
		$prefEnableConvert->{$codec}=undef;
		$prefEnableResample->{$codec}=undef;
		
		if ($supported->{$codec}){

			$prefCodecs->{$codec}="on";
			$prefEnableConvert->{$codec}="on";
			$prefEnableResample->{$codec}="on";

			if ($caps->{$codec}->{'defaultEnableSeek'}){

				$prefEnableSeek->{$codec}="on";
			}
			if ($caps->{$codec}->{'defaultEnableStdin'}){

				$prefEnableStdin->{$codec}="on";
			}
		}	
	}
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("Default codecs  : ".dump($prefCodecs));
			 $log->debug("Enable Seek for : ".dump($prefEnableSeek));
			 $log->debug("Enable Stdin for : ".dump($prefEnableStdin));
			 $log->debug("Enable Convert for : ".dump($prefEnableConvert));
			 $log->debug("Enable Resample for : ".dump($prefEnableResample));
	}
	return ($prefCodecs, $prefEnableSeek, $prefEnableStdin,
	        $prefEnableConvert,$prefEnableResample);
}
sub refreshCodecs{
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug('refreshCodecs');	
	}
	
	my $prefs= getPreferences();

	my $prefRef = $prefs->get('codecs');
	
	my $caps=getCapabilities();
	my $codecs= $caps->{'codecs'};
	
	my $prefCodecs =();
	my $supported=();

	#add all the codecs supported by C-3PO.
	for my $codec (keys %$codecs) {
		$supported->{$codec} = $codecs->{$codec}->{'supported'};
	}
	#remove unlisted and unsupported.
	for my $codec (keys %$prefRef){

		if (exists $codecs->{$codec}->{'unlisted'}){
			next;
		}
		
		$prefCodecs->{$codec}=undef;
		
		if ($codecs->{$codec}->{'supported'}){

			$prefCodecs->{$codec}=$prefRef->{$codec};
		}
	}
	for my $codec (keys %$supported){

		if (exists $codecs->{$codec}->{'supported'}){

			# codec is new added in supported
			if (!exists $prefCodecs->{$codec}){
			
				$prefCodecs->{$codec}=undef;
			}
		} 
	}
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("Refreshed codecs       : ".dump($prefCodecs)); 
	}
	return ($prefCodecs);
}
sub refreshClientCodecs{
	my $client=shift;
	
	my $prefs= getPreferences($client);

	my $prefRef = $prefs->client($client)->get('codecs');
	my $prefEnableSeekRef = $prefs->client($client)->get('enableSeek');
	my $prefEnableStdinRef = $prefs->client($client)->get('enableStdin');
	my $prefEnableConvertRef = $prefs->client($client)->get('enableConvert');
	my $prefEnableResampleRef = $prefs->client($client)->get('enableResample');
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("codecs           : ".dump($prefRef));
			 $log->debug("seek enabled     : ".dump($prefEnableSeekRef));
			 $log->debug("stdin enabled    : ".dump($prefEnableStdinRef));
			 $log->debug("convert enabled  : ".dump($prefEnableConvertRef));
			 $log->debug("resample enabled : ".dump($prefEnableResampleRef));			 
	}
	
	my $capabilities=getCapabilities();
	my $caps= $capabilities->{'codecs'};
	
	my $C3POprefs	= getPreferences();
	my $codecs		= $C3POprefs->get('codecs');
	
	my $prefCodecs =();
	my $prefEnableSeek=();
	my $prefEnableStdin=();
	my $prefEnableConvert =();
	my $prefEnableResample =();
	
	my $supported=();
	
	#add all the codecs supported by the client.
	for my $codec (Slim::Player::CapabilitiesHelper::supportedFormats($client)) {
		$supported->{$codec} = 0;
	}
	#add all the codecs supported by C-3PO.
	for my $codec (keys %$codecs) {
		$supported->{$codec} = $codecs->{$codec};
	}
	#remove unlisted and unsupported.
	for my $codec (keys %$prefRef){

		if ($caps->{$codec}->{'unlisted'}){
			next;
		}

		if ($prefRef->{$codec} && $codecs->{$codec}){

			$prefCodecs->{$codec}=$prefRef->{$codec};
			$prefEnableSeek->{$codec}=$prefEnableSeekRef->{$codec};
			$prefEnableStdin->{$codec}=$prefEnableStdinRef->{$codec};
			$prefEnableConvert->{$codec}=$prefEnableConvertRef->{$codec};
			$prefEnableResample->{$codec}=$prefEnableResampleRef->{$codec};
		
		} elsif ($codecs->{$codec}){
		
			# codec was suported but disabled for player.
			$prefCodecs->{$codec}="on";
			$prefEnableConvert->{$codec}="on";
			$prefEnableResample->{$codec}="on";
			
			
			if ($caps->{$codec}->{'defaultEnableSeek'}){

				$prefEnableSeek->{$codec}="on";
			} else{
				$prefEnableSeek->{$codec}=undef;
			}
			if ($caps->{$codec}->{'defaultEnableStdin'}){

				$prefEnableStdin->{$codec}="on";
			} else {
				$prefEnableStdin->{$codec}=undef;	
			}
		} else {
			
			# codec is supported by the player but not C-3PO.
			$prefCodecs->{$codec}=undef;
			$prefEnableSeek->{$codec}=undef;
			$prefEnableStdin->{$codec}=undef;
			$prefEnableConvert->{$codec}=undef;
			$prefEnableResample->{$codec}=undef;
		}
	}
	for my $codec (keys %$supported){

		if ($caps->{$codec}->{'unlisted'}){
			next;
		}
		
		if ($codecs->{$codec}){

			# codec is new added in supported
			if (!exists $prefCodecs->{$codec}){
			
				$prefCodecs->{$codec}="on";
				$prefEnableConvert->{$codec}="on";
				$prefEnableResample->{$codec}="on";

				if ($caps->{$codec}->{'defaultEnableSeek'}){

					$prefEnableSeek->{$codec}="on";
				} else{
					$prefEnableSeek->{$codec}=undef;
				}
				if ($caps->{$codec}->{'defaultEnableStdin'}){

					$prefEnableStdin->{$codec}="on";
				} else {
					$prefEnableStdin->{$codec}=undef;	
				}
			}
		} else{
			
			# codec is supported by the player but not C-3PO.
			$prefCodecs->{$codec}=undef;
			$prefEnableSeek->{$codec}=undef;
			$prefEnableStdin->{$codec}=undef;
			$prefEnableConvert->{$codec}=undef;
			$prefEnableResample->{$codec}=undef;
		}
	}
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("Refreshed codecs       : ".dump($prefCodecs));
			 $log->debug("Refreshed seek enabled : ".dump($prefEnableSeek));
			 $log->debug("Refreshed stdin enabled: ".dump($prefEnableStdin));
			 $log->debug("Refreshed Convert enabled : ".dump($prefEnableConvert));
			 $log->debug("Refreshed Resample enable : ".dump($prefEnableResample));			 
	}
	return ($prefCodecs,$prefEnableSeek, $prefEnableStdin,
	        $prefEnableConvert,$prefEnableResample);
}
sub settingsChanged{
	my $unusedClient=shift;
	# it takes so little rebuild profiles for any player...
	
	my $prefs= getPreferences();
	
	if (main::INFOLOG && $log->is_info) {	
			my $conv = Slim::Player::TranscodingHelper::Conversions();
			my $caps = Slim::Player::TranscodingHelper::Capabilities();
			$log->info("STATUS QUO ANTE: ");
			$log->info("LMS conversion Table:   ".dump($conv));
			$log->info("LMS Capabilities Table: ".dump($caps));
	}
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug("preferences:");
		$log->debug(dump Plugins::C3PO::Shared::prefsToHash($prefs));
	}
	
	disableProfiles();
	
	if (main::DEBUGLOG && $log->is_debug) {	
			my $conv = Slim::Player::TranscodingHelper::Conversions();
			my $caps = Slim::Player::TranscodingHelper::Capabilities();
			$log->debug("AFTER PROFILES DISABLING: ");
			$log->debug("LMS conversion Table:   ".dump($conv));
			$log->debug("LMS Capabilities Table: ".dump($caps));
	}

	my @clientList = Slim::Player::Client::clients();

	for my $client (@clientList){
	
		playerSettingChanged($client);
	}
	if (main::INFOLOG && $log->is_info) {	
			my $conv = Slim::Player::TranscodingHelper::Conversions();
			my $caps = Slim::Player::TranscodingHelper::Capabilities();
			$log->info("RESULT: ");
			$log->info("LMS conversion Table:   ".dump($conv));
			$log->info("LMS Capabilities Table: ".dump($caps));
	}
}
sub playerSettingChanged{
	my $client = shift;
	
	my $prefs= getPreferences($client);
				
	#refresh the codec list.
	initClientCodecs($client);

	#refresh preferences.
	setupTranscoder($client);
}

sub disableProfiles{
	
	my %codecs=();
	
	my %newCodecs = %{getPreferences()->get('codecs')};
	
	if (main::DEBUGLOG && $log->is_debug) {		
		$log->debug("New codecs: ");
		$log->debug(dump(%newCodecs));
		$log->debug("previous codecs: ");
		$log->debug(dump(%previousCodecs));
		$log->debug("codecs: ");
		$log->debug(dump(%codecs));
	}
	
	for my $c (keys %previousCodecs){
	
		if ($previousCodecs{$c}) {$codecs{$c}=1;}
	}
	for my $c (keys %newCodecs){
		
		if ($newCodecs{$c}) {$codecs{$c}=1;}
	}
	
	if (main::DEBUGLOG && $log->is_debug) {		
		$log->debug("codecs: ");
		$log->debug(dump(%codecs));
	}
	
	my $conv = Slim::Player::TranscodingHelper::Conversions();
	
	if (main::DEBUGLOG && $log->is_debug) {		
		$log->debug("transcodeTable: ".dump($conv));
	}
	for my $profile (keys $conv){
		
		#flc-pcm-*-00:04:20:12:b3:17
		#aac-aac-*-*
		
		my ($inputtype, $outputtype, $clienttype, $clientid) = inspectProfile($profile);
		
		if ($codecs{$inputtype}){
		
			if (main::DEBUGLOG && $log->is_debug) {		
				$log->debug("disable: ". $profile);
			}
			
			disableProfile($profile);
			
			my @clientList= Slim::Player::Client::clients();
	
			for my $client (@clientList){
			
				if (main::DEBUGLOG && $log->is_debug) {			
					$log->debug("clientid: ".$clientid);
					$log->debug("client-Id: ".$client->id());
				}
				if ($clientid && ($clientid eq $client->id())){
				
					if (main::DEBUGLOG && $log->is_debug) {	
						my $conv = Slim::Player::TranscodingHelper::Conversions();
						$log->debug("transcodeTable: ".dump($conv));
					}
					
					delete $Slim::Player::TranscodingHelper::commandTable{ $profile };
					delete $Slim::Player::TranscodingHelper::capabilities{ $profile };
					
					
					if (main::DEBUGLOG && $log->is_debug) {		
						my $conv = Slim::Player::TranscodingHelper::Conversions();
						$log->debug("transcodeTable: ".dump($conv));
					}
				}
			}

		}
	}
	%previousCodecs	= %newCodecs;
}
sub inspectProfile{
	my $profile=shift;
	
	my $inputtype;
	my $outputtype;
	my $clienttype;
	my $clientid;;
	
	if ($profile =~ /^(\S+)\-+(\S+)\-+(\S+)\-+(\S+)$/) {

		$inputtype  = $1;
		$outputtype = $2;
		$clienttype = $3;
		$clientid   = lc($4);
		
		return ($inputtype, $outputtype, $clienttype, $clientid);	
	}
	return (undef,undef,undef,undef);
}
sub enableProfile{
	my $profile = shift;
	my @out = ();
	
	my @disabled = @{ $serverPreferences->get('disabledformats') };
	for my $format (@disabled) {

		if ($format eq $profile) {next;}
		push @out, $format;
	}
	$serverPreferences->set('disabledformats', \@out);
	$serverPreferences->writeAll();
}
sub disableProfile{
	my $profile = shift;
	my @disabled = @{ $serverPreferences->get('disabledformats') };
	my $found=0;
	for my $format (@disabled) {
		
		if ($format eq $profile){
			$found=1;
			last;}
	}
	if (! $found ){
		push @disabled, $profile;
		$serverPreferences->set('disabledformats', \@disabled);
		$serverPreferences->writeAll();
	}
}
sub setupTranscoder{
	my $client=shift;
	
	my $transcodeTable=buildTranscoderTable($client);
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("TranscoderTable:");
			 $log->debug(dump($transcodeTable));
	}
	my %logger=();
		$logger{'DEBUGLOG'}=main::DEBUGLOG;
		$logger{'INFOLOG'}=main::INFOLOG;
		$logger{'log'}=$log;
	
	my $commandTable=Plugins::C3PO::Transcoder::initTranscoder($transcodeTable,\%logger);
	
	if (main::INFOLOG && $log->is_info) {
		$log->info("commandTable: ".dump($commandTable));
	}

	for my $profile (keys %$commandTable){

		my $cmd = $commandTable->{$profile};
		
		if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("\n".
						"PROFILE  : ".$cmd->{'profile'}."\n".
						" Command : ".$cmd->{'command'}."\n".
						" Capabilities: ".
						dump($cmd->{'capabilities'}));
		}
		enableProfile($profile);
		$Slim::Player::TranscodingHelper::commandTable{ $cmd->{'profile'} } = $cmd->{'command'};
		$Slim::Player::TranscodingHelper::capabilities{ $cmd->{'profile'} } = $cmd->{'capabilities'};
	} 
}
sub buildTranscoderTable{
	my $client=shift;
	
	#make sure codecs are up to date for the client:
	my $clientCodecList=initClientCodecs($client);
	
	my $prefs= getPreferences($client);
	
	my $transcoderTable= Plugins::C3PO::Shared::getTranscoderTableFromPreferences($prefs,$client);
	
	#add the path to the preference file itself.
	$transcoderTable->{'pathToPrefFile'}=getPathToPrefFile();
	
	return $transcoderTable;
}
sub getStatus{
	my $client=shift;
	
	my $displayStatus;
	my $status;
	my $message;
	
	my $in = _calcStatus();
	my %statusTab=();
	my %details=();
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug(dump($in));
	}
	for my $dest (keys %$in) {
		
		 if (($client && ($dest eq $client || $dest eq 'all')) ||
		     (!$client && ($dest eq 'server' || $dest eq 'all'))) {
			
			my $stat = $in->{$dest};
			for my $st (keys %$stat){
			
				$statusTab{$st} = $stat->{$st}
				
			}
		 }
	}
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug(dump(%statusTab));
	}
	if (scalar(keys %statusTab)== 0){
		
		$displayStatus=0;
		$status= Slim::Web::HTTP::CSRF->protectName('PLUGIN_C3PO_STATUS');
		$message= Slim::Web::HTTP::CSRF->protectName('PLUGIN_C3PO_STATUS_000');
	
	} elsif (scalar (keys %statusTab) == 1){
		
		my @stat = (keys %statusTab);
		my $st= shift @stat;
		
		$displayStatus=1;
		$status = $statusTab{$st}{'status'};
		$message= $statusTab{$st}{'message'};
		
	} else{
		#use the worst status as message.
		$status = Slim::Web::HTTP::CSRF->protectName('PLUGIN_C3PO_STATUS');
		my $seen=0;
		foreach my $st (sort keys %statusTab){
			
			if (! $seen){
				$message= $statusTab{$st}{'status'};
			}
			$details{$st}= $statusTab{$st}{'message'};
		}
		$displayStatus=1;
	} 
	my %out= ();
	
	$out{'display'}=$displayStatus;
	$out{'status'}=$status;
	$out{'message'}=$message;
	$out{'details'}=\%details;
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug(dump(%out));
	}
	
	return \%out;
}
sub _calcStatus{
	
	# Error/Warning/Info conditions, see Strings for descrptions.

	my $status;
	my $message;
	my %statusTab=();
	my $ref= \%statusTab;
	
	my $prefs= getPreferences();
	
	if (!$C3POwillStart){
		
		$ref = _getStatusLine('001','all',$ref);

	}
	if ($C3POwillStart && $C3POwillStart eq 'pl'){
		
		$ref = _getStatusLine('101','all',$ref);

	}
	if (!$pathToFaad){
		
		$ref = _getStatusLine('014','all',$ref);

	}
	if (!$pathToFlac){
		
		$ref = _getStatusLine('013','all',$ref);

	}
	if (!$pathToSox){
		
		$ref = _getStatusLine('012','all',$ref);

	}
	if ($prefs->get('extra') && !($prefs->get('extra') eq "") ){
		
		$ref = _getStatusLine('905','all',$ref);

	}
	my @clientList= Slim::Player::Client::clients();

	for my $client (@clientList){
		
		if (main::DEBUGLOG && $log->is_debug) {
			
			$log->debug("Id         ".$client->id());
			$log->debug("name       ".$client->name());
			$log->debug("model name ".$client->modelName());
			$log->debug("model      ".$client->model());
			$log->debug("firmware   ".$client->revision());
			
		}
		if (($client->model() eq 'squeezelite') && !($client->modelName() eq 'SqueezeLite-R2')){

			my $firmware = $client->revision();
			
			if (index(lc($firmware),'daphile') != -1) {

				$ref = _getStatusLine('921',$client,$ref);

			} else {
				
				$ref = _getStatusLine('021','server',$ref);
				$ref = _getStatusLine('021',$client,$ref);

			}
			
		} elsif (! ($client->model() eq 'squeezelite')) {

				$ref = _getStatusLine('521',$client,$ref);

		}
		
		$prefs= getPreferences($client);
		
		my $prefEnableSeekRef		= $prefs->client($client)->get('enableSeek');
		my $prefEnableStdinRef		= $prefs->client($client)->get('enableStdin');
		my $prefEnableConvertRef	= $prefs->client($client)->get('enableConvert');
		my $prefEnableResampleRef	= $prefs->client($client)->get('enableResample');
		
		for my $codec (keys %$prefEnableSeekRef){
			
			if ($prefEnableStdinRef->{$codec} && 
			    main::ISWINDOWS &&
				(($prefs->get('resampleWhen')eq 'E') ||
				 ($prefs->get('resampleTo') eq 'S'))) {
				
				if (main::DEBUGLOG && $log->is_debug) {	
					$log->debug("Player: ".$client->name());
					$log->debug("codec: ".$codec);
					$log->debug("Stdin: ".$prefEnableStdinRef->{$codec});
					$log->debug("ISWINDOWS: ".main::ISWINDOWS);
					$log->debug("resampleWhen: ".$prefs->get('resampleWhen'));
					$log->debug("resampleTo: ".$prefs->get('resampleTo'));
				}
				
				$ref = _getStatusLine('502','server',$ref);
				$ref = _getStatusLine('502',$client,$ref);

			}
			if ($prefEnableSeekRef->{$codec} && $prefEnableStdinRef->{$codec}){
				
				$ref = _getStatusLine('503','server',$ref);
				$ref = _getStatusLine('503',$client,$ref);

			}
			if ($prefEnableSeekRef->{$codec} && $prefEnableStdinRef->{$codec}){
				
				$ref = _getStatusLine('503','server',$ref);
				$ref = _getStatusLine('503',$client,$ref);

			}
			if ($prefEnableResampleRef->{$codec} && !$prefEnableConvertRef->{$codec}){
			
				if ($codec eq 'alc'){
					$ref = _getStatusLine('504',$client,$ref);
				} elsif ($codec eq 'flc'){
					$ref = _getStatusLine('904',$client,$ref);
				}
			}
		}
	}
	return \%statusTab;
}
sub _getStatusLine{
	
	my $code=shift;
	my $dest= shift;
	my $tab=shift;

	my $status = ($code < 500 ? "PLUGIN_C3PO_STATUS_ERROR" : 
				  $code < 900 ? "PLUGIN_C3PO_STATUS_WARNING" : 
							    "PLUGIN_C3PO_STATUS_INFO");
	
	$tab->{$dest}->{$code}->{'status'}=$status;
	
	my $base= 'PLUGIN_C3PO_STATUS_';

	if ($dest eq 'server') { 
		$tab->{$dest}->{$code}->{'message'}=$base.'SERVER_'.$code;
		
	} elsif ($dest eq 'all') { 
		$tab->{$dest}->{$code}->{'message'}=$base.$code;

	} else{
		$tab->{$dest}->{$code}->{'message'}=$base.'CLIENT_'.$code;
	};
	
	return $tab;
}
1;






