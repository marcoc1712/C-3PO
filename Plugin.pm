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

my $serverFolder;
my $pluginPath;
my $C3POfolder;

#use lib rel2abs(catdir($C3POfolder, 'lib'));
#use lib rel2abs(catdir($C3POfolder,'CPAN'));

# sub and BEGIN block is needed to avoid PERL claims 
# in Linux but not in windows.

sub getLibDir {
	my $lib = shift;
	
	$serverFolder	= $Bin;
	$pluginPath		=__FILE__;
	$C3POfolder		= File::Basename::dirname($pluginPath);
	my $str= catdir($C3POfolder, $lib);
	my $dir = rel2abs($str);
	return $dir;

}

BEGIN{ use lib getLibDir('lib');}

require File::HomeDir;

use base qw(Slim::Plugin::Base);

if ( main::WEBUI ) {
	require Plugins::C3PO::Settings;
	require Plugins::C3PO::PlayerSettings;
}

use Plugins::C3PO::Shared;
use Plugins::C3PO::PreferencesHelper;
use Plugins::C3PO::CapabilityHelper;
use Plugins::C3PO::EnvironmentHelper;
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

use Plugins::C3PO::Formats::Format;
use Plugins::C3PO::Formats::Wav;
use Plugins::C3PO::Formats::Aiff;
use Plugins::C3PO::Formats::Flac;
use Plugins::C3PO::Formats::Alac;
use Plugins::C3PO::Formats::Dsf;
use Plugins::C3PO::Formats::Dff;

use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Slim::Utils::Strings qw(string);
use Slim::Player::TranscodingHelper;

my $class;

my $serverPreferences = preferences('server');

my %logger=();
my $log = Slim::Utils::Log->addLogCategory( {
	category     => 'plugin.C3PO',
	defaultLevel => 'ERROR',
	description  => 'PLUGIN_C3PO_MODULE_NAME',
} );
$logger{'DEBUGLOG'}=main::DEBUGLOG;
$logger{'INFOLOG'}=main::INFOLOG;
$logger{'log'}=$log;

my $EnvironmentHelper;
my $CapabilityHelper;


################################################################################
# Status variables
#
my $C3POwillStart;
my $C3POisDownloading;

################################################################################
# required methods
################################################################################

sub getDisplayName {
	return 'PLUGIN_C3PO_MODULE_NAME';
}
	
sub initPlugin {
	$class = shift;

	$class->SUPER::initPlugin(@_);

	if (main::INFOLOG && $log->is_info) {
		$log->info('initPlugin');
	}
	
	$EnvironmentHelper = Plugins::C3PO::EnvironmentHelper->new(\%logger, $C3POfolder, $serverFolder);	
	my $preferences = $class->getPreferences();

	$preferences->set('serverFolder', $EnvironmentHelper->serverFolder());
	$preferences->set('logFolder', $EnvironmentHelper->logFolder());
	$preferences->set('pathToPrefFile', $EnvironmentHelper->pathToPrefFile());
	$preferences->set('pathToFlac', $EnvironmentHelper->pathToFlac());
	$preferences->set('pathToSox', $EnvironmentHelper->pathToSox());
	$preferences->set('pathToFaad', $EnvironmentHelper->pathToFaad());
	$preferences->set('pathToFFmpeg', $EnvironmentHelper->pathToFFmpeg());
	$preferences->set('pathToC3PO_pl', $EnvironmentHelper->pathToC3PO_pl());
	$preferences->set('pathToC3PO_exe', $EnvironmentHelper->pathToC3PO_exe());
	$preferences->set('C3POfolder', $EnvironmentHelper->C3POfolder());
	$preferences->set('pathToPerl', $EnvironmentHelper->pathToPerl());
	$preferences->set('pathToHeaderRestorer_pl', $EnvironmentHelper->pathToHeaderRestorer_pl());
	$preferences->set('pathToHeaderRestorer_exe', $EnvironmentHelper->pathToHeaderRestorer_exe());
	$preferences->set('soxVersion', $EnvironmentHelper->soxVersion());
	$preferences->set('isSoxDsdCapable', $EnvironmentHelper->isSoxDsdCapable());
	
	$preferences->writeAll();
	$preferences->savenow();
	
	$C3POwillStart=0;
	$C3POisDownloading=0;
	
	$CapabilityHelper = Plugins::C3PO::CapabilityHelper->new(\%logger,
							$EnvironmentHelper->isSoxDsdCapable(),
							$preferences->get('unlimitedDsdRate')
						);
						
	if ( main::WEBUI ) {
		Plugins::C3PO::Settings->new($class);
		Plugins::C3PO::PlayerSettings->new($class);
	}

	_initCodecs();
	
	$C3POwillStart=$class->_testC3PO();

	_disableProfiles();

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
	
	return _clientCalback($client,"new");
}

sub clientReconnectCallback {
	my $request = shift;
	my $client  = $request->client() || return;
	
	return _clientCalback($client,"reconnect");
}

###############################################################################
## Public methods
##
sub getLogger{
	return \%logger;
}

sub getPreferences{
	my $self = shift;
	my $client = shift;
	
	my $PreferencesHelper= Plugins::C3PO::PreferencesHelper->new(\%logger, preferences('plugin.C3PO'), $client);
	my $preferences= $PreferencesHelper->preferences();
	
	return $preferences;
}

sub getSharedPrefNameList(){
	return Plugins::C3PO::Shared::getSharedPrefNameList();
}
sub getMaxSupportedSampleRate{
	my $class = shift;
	my $client = shift;
	
	return $CapabilityHelper->maxSupportedSamplerate($client);
}
sub getMaxSupportedDsdRate{
	my $class = shift;
	my $client = shift;
	
	return $CapabilityHelper->maxSupportedDsdRate($client);
}
sub getSampleRates{
	my $class = shift;
	
	return $CapabilityHelper->samplerates();
}
sub getDsdRates{
	my $class = shift;
	
	return $CapabilityHelper->dsdrates();
}
sub translateSampleRates{
	my $class = shift;
	my $in = shift;

	my $ref=$CapabilityHelper->samplerates();
	return _translateRates($in, $ref);
}
sub translateDsdRates{
	my $class = shift;
	my $in = shift;

	my $ref=$CapabilityHelper->dsdrates();
	return _translateRates($in, $ref);
}

sub getSupportedCodecs{
	my $class = shift;
	
	return $CapabilityHelper->supportedCodecs();
}
sub initClientCodecs{
	my $class = shift;
	my $client = shift;
	
	if (main::DEBUGLOG && $log->is_debug) {
		my ($package, $filename, $line) = caller;
		$log->debug('initClientCodecs '.$package. ' ' .$filename.' '.$line );	
	}
	
	my $prefs= $class->getPreferences($client);
	
	my $codecList="";
	
	my $supportedCli;
	my $prefCodecs;
	my $prefEnableSeek;
	my $prefEnableStdin;
	my $prefEnableConvert;
	my $prefEnableResample;

	if (!defined($prefs->client($client)->get('codecs'))){
	
		($supportedCli, $prefCodecs, $prefEnableSeek,$prefEnableStdin,
		 $prefEnableConvert,$prefEnableResample) = _defaultClientCodecs($client);

	} else {
		
		($supportedCli, $prefCodecs, $prefEnableSeek,$prefEnableStdin,
		 $prefEnableConvert,$prefEnableResample) = _refreshClientCodecs($client);
	}
	#build the complete list string
	for my $codec (keys %$prefCodecs){

		if (length($codecList)>0) {

			$codecList=$codecList." ";
		}
		$codecList=$codecList.$codec;
	}
	$prefs->client($client)->set('codecsCli', $supportedCli);
	$prefs->client($client)->set('codecs', $prefCodecs);
	$prefs->client($client)->set('enableSeek', $prefEnableSeek);
	$prefs->client($client)->set('enableStdin', $prefEnableStdin);
	$prefs->client($client)->set('enableConvert', $prefEnableConvert);
	$prefs->client($client)->set('enableResample', $prefEnableResample);
	
	$prefs->writeAll();
	$prefs->savenow();
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("New codecs: ".dump($prefCodecs));
			  $log->debug("New Cli:   ".dump($supportedCli));
	}
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("New pref codec: ".dump($prefs->client($client)->get('codecs')));
			 $log->debug("New pref cli    ".dump($prefs->client($client)->get('codecsCli')));
	}
	
	return ($codecList);
}

sub settingsChanged{
	my $class = shift;
	my $client=shift;
	
	
	my $prefs= $class->getPreferences();
	
	$CapabilityHelper = Plugins::C3PO::CapabilityHelper->new(\%logger,
							$EnvironmentHelper->isSoxDsdCapable(),
							$prefs->get('unlimitedDsdRate')
						);
	
	if (main::DEBUGLOG && $log->is_debug) {	
			my $conv = Slim::Player::TranscodingHelper::Conversions();
			my $caps = \%Slim::Player::TranscodingHelper::capabilities;
			$log->debug("STATUS QUO ANTE: ");
			$log->debug("LMS conversion Table:   ".dump($conv));
			$log->debug("LMS Capabilities Table: ".dump($caps));
	}
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug("preferences:");
		$log->debug(dump Plugins::C3PO::Shared::prefsToHash($prefs));
	}
	
	if ($client){
		_disableProfiles($client);
	} else {
		_disableProfiles();
	}
	
	if (main::DEBUGLOG && $log->is_debug) {	
			my $conv = Slim::Player::TranscodingHelper::Conversions();
			my $caps = \%Slim::Player::TranscodingHelper::capabilities;
			$log->debug("AFTER PROFILES DISABLING: ");
			$log->debug("LMS conversion Table:   ".dump($conv));
			$log->debug("LMS Capabilities Table: ".dump($caps));
	}
	if ($client){
		
		_playerSettingChanged($client);
		
	} else{
	
		my @clientList = Slim::Player::Client::clients();

		for my $c (@clientList){
		
			_playerSettingChanged($c);
		
		}
	}
	
	if (main::DEBUGLOG && $log->is_debug) {	
			my $conv = Slim::Player::TranscodingHelper::Conversions();
			my $caps = \%Slim::Player::TranscodingHelper::capabilities;
			$log->debug("RESULT: ");
			$log->debug("LMS conversion Table:   ".dump($conv));
			$log->debug("LMS Capabilities Table: ".dump($caps));
	}
}
sub getStatus{
	my $class = shift;
	my $client=shift;
	
	my $displayStatus;
	my $status;
	my $message;
	
	my $in = _calcStatus();
	my %statusTab=();
	my %details=();
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("In status : ".dump($in));
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
			 $log->debug("Status Tab: ".dump(%statusTab));
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
				$seen=1;
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
			 $log->debug("Status is: ".dump(%out));
	}
	
	return \%out;
}
#callback for windows downloader
sub setWinExecutablesStatus{
	my $class = shift;
	my $status= shift;
	
	if (main::INFOLOG && $log->is_info) {
			 $log->info(dump('Win Executables Status: '));
			 $log->info(dump($status));
	}
	if ($status->{'code'} > 0){ #Error
	
		$C3POisDownloading=0;

	} elsif ($status->{'code'} == 0){ #download Ok;
	
		$class->initPlugin();
		settingsChanged();
		
	} # else is downloading.
	
	if ( main::WEBUI ) {
			Plugins::C3PO::Settings->refreshStatus();
			Plugins::C3PO::PlayerSettings->refreshStatus();
	}

}
################################################################################
## Private 
##

sub _clientCalback{
	my $client = shift;
	my $type = shift;
	
	my $preferences = $class->getPreferences($client);
	
	my $id= $client->id();
	my $macaddress= $client->macaddress();
	my $modelName= $client->modelName();
	my $model= $client->model();
	my $name= $client->name();
	my $maxSupportedSamplerate= $CapabilityHelper->maxSupportedSamplerate($client);
	my $maxSupportedDsdrate= $CapabilityHelper->maxSupportedDsdRate($client);
	
	my $samplerateList= _initSampleRates($client);
	my $dsdrateList= _initDsdRates($client);
	
	my $clientCodecList= $class->initClientCodecs($client);
	
	if (main::INFOLOG && $log->is_info) {
			 $log->info("$type ClientCallback received from \n".
						"id:                     $id \n".
						"mac address:            $macaddress \n".
						"modelName:              $modelName \n".
						"model:                  $model \n".
						"name:                   $name \n".
						"max samplerate:         $maxSupportedSamplerate \n".
						"max dsdrate:			 $maxSupportedDsdrate \n".
						"supported sample rates: $samplerateList \n".
						"supported dsd rates:    $dsdrateList \n".
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
	$preferences->client($client)->set('maxSupportedDsdrate',$maxSupportedDsdrate);

	if ($preferences->client($client)->get('enable')) {
	
		_setupTranscoder($client);
		
	} elsif (main::INFOLOG && $log->is_info){
		
		 $log->info("C-3PO disabled for client: $id");
	}
	
	return 1;
}

sub _initSampleRates{
	my $client = shift;
	
	my $sampleRateList="";
	my $prefSampleRates;
	
	my $prefs= $class->getPreferences($client);
	my $maxSupportedSamplerate= $CapabilityHelper->maxSupportedSamplerate($client);

	if (!defined($prefs->client($client)->get('sampleRates'))){
	
		$prefSampleRates = $CapabilityHelper->defaultSampleRates($client);
		
		if (main::DEBUGLOG && $log->is_debug) {
				 $log->debug("Default Sample Rates: ".dump($prefSampleRates));
		}
	
	} else {
		
		
		my $capSamplerates = $CapabilityHelper->samplerates();
		my $prefRef = $class->translateSampleRates($prefs->client($client)->get('sampleRates'));

		$prefSampleRates = _refreshRates($capSamplerates, $maxSupportedSamplerate, $prefRef);
		
		if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("Refreshed SampleRates: ".dump($prefSampleRates));
		}
	}

	$sampleRateList= $CapabilityHelper->guessSampleRateList($maxSupportedSamplerate);

	$prefs->client($client)->set('sampleRates', $class->translateSampleRates($prefSampleRates));

	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("New sampleRates: ".dump($prefSampleRates));
	}
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("New sampleRates preferences: ".dump($prefs->client($client)->get('sampleRates')));
	}
	
	return ($sampleRateList);
}
sub _initDsdRates{
	my $client = shift;

	my $dsdRateList="";
	my $prefDsdRates;
		
	my $prefs= $class->getPreferences($client);
	my $maxSupportedDsdrate= $CapabilityHelper->maxSupportedDsdRate($client);

	if (!defined($prefs->client($client)->get('dsdRates'))){
	
		$prefDsdRates = $CapabilityHelper->defaultDsdRates($client);
		
		if (main::DEBUGLOG && $log->is_debug) {
			$log->debug("Default DSD Rates: ".dump($prefDsdRates));
		}
	
	} else {

		my $capDsdRates = $CapabilityHelper->dsdrates();	
		my $prefRef =  $class->translateDsdRates($prefs->client($client)->get('dsdrates'));
	
		$prefDsdRates = _refreshRates($capDsdRates, $maxSupportedDsdrate, $prefRef);
		
		if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("Refreshed DSD Rates: ".dump($prefDsdRates));
		}
		
	}

	$dsdRateList= $CapabilityHelper->guessDsdRateList($maxSupportedDsdrate);

	$prefs->client($client)->set('dsdRates', $class->translateDsdRates($prefDsdRates));

	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("New dsdRates: ".dump($prefDsdRates));
	}
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("New dsdrate preferences: ".dump($prefs->client($client)->get('dsdRates')));
	}
	
	return ($dsdRateList);
}

sub _initCodecs{
	my $client = shift;
	
	if ($client){
	
		return $class->initClientCodecs($client)
	}
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug('_initCodecs');	
	}
	my $prefs= $class->getPreferences();
	my $codecList="";
	my $prefCodecs;
	
	if (!defined($prefs->get('codecs'))){
	
		$prefCodecs= $CapabilityHelper->defaultCodecs();

	} else {
		
		if (main::DEBUGLOG && $log->is_debug) {
			$log->debug('_refreshCodecs');	
		}

		my $prefRef = $prefs->get('codecs');
		my $codecs= $CapabilityHelper->codecs();

		$prefCodecs = _refreshCodecs($prefRef,$codecs);
		
		if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("Refreshed codecs       : ".dump($prefCodecs)); 
		}
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

sub _defaultClientCodecs{
	my $client=shift;
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug('_defaultClientCodecs');	
	}

	my $C3POprefs	= $class->getPreferences();
	my $codecs		= $C3POprefs->get('codecs');

	my $caps= $CapabilityHelper->codecs();
	
	my $prefCodecs =();
	my $prefEnableSeek =();
	my $prefEnableStdin =();
	my $prefEnableConvert =();
	my $prefEnableResample =();
	
	my $supportedCli=();
	my $supported=();
	
	#add all the codecs supported by the client.
	for my $codec ($CapabilityHelper->clientSupportedFormats($client)) {
		$supported->{$codec} = 0;
		$supportedCli->{$codec}=1;
		
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
			 $log->debug("Client supported codecs  : ".dump($supportedCli));
			 $log->debug("Default codecs  : ".dump($prefCodecs));
			 $log->debug("Enable Seek for : ".dump($prefEnableSeek));
			 $log->debug("Enable Stdin for : ".dump($prefEnableStdin));
			 $log->debug("Enable Convert for : ".dump($prefEnableConvert));
			 $log->debug("Enable Resample for : ".dump($prefEnableResample));
	}
	return ($supportedCli, $prefCodecs, $prefEnableSeek, $prefEnableStdin,
	        $prefEnableConvert,$prefEnableResample);
}

sub _refreshClientCodecs{
	my $client=shift;
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug('_refreshClientCodecs');	
	}
	
	my $prefs= $class->getPreferences($client);
	
	my $prefCli = $prefs->client($client)->get('codecsCli');
	my $prefRef = $prefs->client($client)->get('codecs');
	my $prefEnableSeekRef = $prefs->client($client)->get('enableSeek');
	my $prefEnableStdinRef = $prefs->client($client)->get('enableStdin');
	my $prefEnableConvertRef = $prefs->client($client)->get('enableConvert');
	my $prefEnableResampleRef = $prefs->client($client)->get('enableResample');
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("pref cli              : ".dump($prefCli));
			 $log->debug("pref codecs           : ".dump($prefRef));
			 $log->debug("ptef seek enabled     : ".dump($prefEnableSeekRef));
			 $log->debug("ptef stdin enabled    : ".dump($prefEnableStdinRef));
			 $log->debug("ptef convert enabled  : ".dump($prefEnableConvertRef));
			 $log->debug("pref resample enabled : ".dump($prefEnableResampleRef));			 
	}

	my $caps= $CapabilityHelper->codecs();
	
	my $C3POprefs	= $class->getPreferences();
	my $codecs		= $C3POprefs->get('codecs');
	
	my $prefCodecs =();
	my $prefEnableSeek=();
	my $prefEnableStdin=();
	my $prefEnableConvert =();
	my $prefEnableResample =();
	
	my $supported=();
	my $supportedCli=();
	
	#add all the codecs supported by the client.
	for my $codec ($CapabilityHelper->clientSupportedFormats($client)) {
		$supported->{$codec} = 0;
		$supportedCli->{$codec} = 1;
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
			 $log->debug("Client supported codecs   : ".dump($supportedCli));
			 $log->debug("Refreshed codecs          : ".dump($prefCodecs));
			 $log->debug("Refreshed seek enabled    : ".dump($prefEnableSeek));
			 $log->debug("Refreshed stdin enabled:  : ".dump($prefEnableStdin));
			 $log->debug("Refreshed Convert enabled : ".dump($prefEnableConvert));
			 $log->debug("Refreshed Resample enable : ".dump($prefEnableResample));			 
	}
	return ($supportedCli, $prefCodecs,$prefEnableSeek, $prefEnableStdin,
	        $prefEnableConvert,$prefEnableResample);
}

sub _testC3PO{
	my $self = shift;
	
	my $exe			= $EnvironmentHelper->testC3POEXE();
	my $pl			= 0;
	
	if (!$exe){

		if (main::ISWINDOWS){

			require Plugins::C3PO::WindowsDownloader;
			Plugins::C3PO::WindowsDownloader->download($self);
			$C3POisDownloading=1;
		}
				
		$pl= $EnvironmentHelper->testC3POPL();
	}
	
	if ($exe){
	
		if (main::INFOLOG && $log->is_info) {
			 $log->info('using C-3PO executable: '.$EnvironmentHelper->pathToC3PO_exe());
		}
		return 'exe';
		
	} elsif ($pl) {
	
		if (main::INFOLOG && $log->is_info) {
			 $log->info('using installed perl to run C-3PO.pl');
			 $log->info('perl    : '.$EnvironmentHelper->pathToPerl());
			 $log->info('C-3PO.Pl: '.$EnvironmentHelper->pathToC3PO_pl());
		}
		return 'pl';
		
	} elsif ($C3POisDownloading){
	
		if (main::INFOLOG && $log->is_info) {
			
			$log->info('Please wait for C-3PO.exe to download: ');
		}
		return 0;
	}
	
	$log->warn('WARNING: C3PO will not start on call: ');
	$log->warn('WARNING: Perl path: '.$EnvironmentHelper->pathToPerl());
	$log->warn('WARNING: C-3PO.pl path: '.$EnvironmentHelper->pathToC3PO_pl());
	$log->warn('WARNING: C-3PO path: '.$EnvironmentHelper->pathToC3PO_exe());
	
	return 0;
}
sub _calcStatus{
	
	# Error/Warning/Info conditions, see Strings for descrptions.

	my $status;
	my $message;
	my %statusTab=();
	my $ref= \%statusTab;
	
	my $prefs= $class->getPreferences();
		
	if (!$C3POwillStart && !$C3POisDownloading){
		
		$ref = _getStatusLine('001','all',$ref);

	}elsif ($C3POwillStart && $C3POwillStart eq 'pl' && !$C3POisDownloading){
		
		$ref = _getStatusLine('101','all',$ref);

	}elsif ($C3POwillStart && $C3POwillStart eq 'pl' && $C3POisDownloading){
		
		$ref = _getStatusLine('701','all',$ref);

	}elsif (!$C3POwillStart){ #Downloading
		
		$ref = _getStatusLine('601','all',$ref);

	}

	if (!$EnvironmentHelper->pathToFaad()){
		
		$ref = _getStatusLine('014','all',$ref);

	}
	if (!$EnvironmentHelper->pathToFlac()){
		
		$ref = _getStatusLine('013','all',$ref);

	}
	if (!$EnvironmentHelper->pathToSox()){
		
		$ref = _getStatusLine('012','all',$ref);

	}
	if (($prefs->get('extra_before_rate') && !($prefs->get('extra_before_rate') eq "") ) ||
		($prefs->get('extra_after_rate') && !($prefs->get('extra_after_rate') eq "") )) {
		
		$ref = _getStatusLine('905','server',$ref);
	
	}
	
	if ($EnvironmentHelper->soxVersion() < 140400){
	
		$ref = _getStatusLine('951','all',$ref);
		
	} 
	
	if (!$EnvironmentHelper->isSoxDsdCapable){
		
		$ref = _getStatusLine('952','server',$ref);
	}
	
	###########################################################################
	# Client
	#
	
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
		
		$prefs= $class->getPreferences($client);
		
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

			if (($prefs->client($client)->get('extra_before_rate') && !($prefs->client($client)->get('extra_before_rate') eq "")) ||
				($prefs->client($client)->get('extra_after_rate') && !($prefs->client($client)->get('extra_after_rate') eq ""))) {
		
				$ref = _getStatusLine('905',$client,$ref);
			}
			
			if ($CapabilityHelper->isDsdCapable($client) && !$EnvironmentHelper->isSoxDsdCapable ){
		
				$ref = _getStatusLine('952',$client,$ref);
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

#################################################################################
# React to settings change and setup transcoder
#
sub _playerSettingChanged{
	my $client = shift;
	
	#refresh preferences.
	$class->getPreferences($client);
				
	#refresh the codec list.
	$class->initClientCodecs($client);

	#refresh transcoderTable.
	_setupTranscoder($client);
}

# store values before preferences change.
my %previousCodecs=();
my %previousenabled=();

sub _disableProfiles{
	my $client = shift;
	
	my %codecs=();
	my %players=();
	
	my %newEnabled=();
	if ($client){
	
		$players{$client->id()}=1;
	
	} else {
	
		%newEnabled = %{_getEnabledPlayers()};
		for my $p (keys %previousenabled){

			if ($previousenabled{$p}) {$players{$p}=1;}
		}
		for my $p (keys %newEnabled){

			if ($newEnabled{$p}) {$players{$p}=1;}
		}
	}

	my %newCodecs = %{$class->getPreferences()->get('codecs')};
	for my $c (keys %previousCodecs){
	
		if ($previousCodecs{$c}) {$codecs{$c}=1;}
	}
	for my $c (keys %newCodecs){
		
		if ($newCodecs{$c}) {$codecs{$c}=1;}
	}

	if (main::DEBUGLOG && $log->is_debug) {		
		$log->debug("New codecs: ");
		$log->debug(dump(%newCodecs));
		$log->debug("previous codecs: ");
		$log->debug(dump(%previousCodecs));
		$log->debug("codecs: ");
		$log->debug(dump(%codecs));
		$log->debug("New enabled players: ");
		$log->debug(dump(%newEnabled));
		$log->debug("Previously enabled players: ");
		$log->debug(dump(%previousenabled));
		$log->debug("players: ");
		$log->debug(dump(%players));
	}
	
	my $conv = Slim::Player::TranscodingHelper::Conversions();
	
	if (main::DEBUGLOG && $log->is_debug) {		
		$log->debug("transcodeTable: ".dump($conv));
	}
	
	for my $profile (keys %$conv){
		
		#flc-pcm-*-00:04:20:12:b3:17
		#aac-aac-*-*
		
		my ($inputtype, $outputtype, $clienttype, $clientid) = _inspectProfile($profile);
		
		if ($codecs{$inputtype} && $players{$clientid}){
		
			if (main::DEBUGLOG && $log->is_debug) {		
				$log->debug("disable: ". $profile);
			}
			
			_disableProfile($profile);

			delete $Slim::Player::TranscodingHelper::commandTable{ $profile };
			delete $Slim::Player::TranscodingHelper::capabilities{ $profile };

		}
	}
	
	if (main::DEBUGLOG && $log->is_debug) {		
				my $conv = Slim::Player::TranscodingHelper::Conversions();
				$log->debug("transcodeTable: ".dump($conv));
	}
	
	%previousCodecs	 = %newCodecs;
	%previousenabled = %newEnabled;
}
sub _getEnabledPlayers{

	my @clientList= Slim::Player::Client::clients();
	my %enabled=();
	
	for my $client (@clientList){
		
		my $prefs= $class->getPreferences($client);
		if ($prefs->client($client)->get('enable')){
			
			$enabled{$client->id()} = 1;
		}
	}
	return \%enabled;
}
sub _inspectProfile{
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
sub _enableProfile{
	my $profile = shift;
	my @out = ();
	
	my @disabled = @{ $serverPreferences->get('disabledformats') };
	for my $format (@disabled) {

		if ($format eq $profile) {next;}
		push @out, $format;
	}
	$serverPreferences->set('disabledformats', \@out);
	$serverPreferences->writeAll();
	$serverPreferences->savenow();
}
sub _disableProfile{
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
		$serverPreferences->savenow();
	}
}
sub _setupTranscoder{
	my $client=shift;
	
	my $transcodeTable=_buildTranscoderTable($client);
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("TranscoderTable:");
			 $log->debug(dump($transcodeTable));
	}
	
	if (main::DEBUGLOG && $log->is_debug){
		$log->debug("logger: ".dump(\%logger));
	}
	
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
		_enableProfile($profile);
		$Slim::Player::TranscodingHelper::commandTable{ $cmd->{'profile'} } = $cmd->{'command'};
		$Slim::Player::TranscodingHelper::capabilities{ $cmd->{'profile'} } = $cmd->{'capabilities'};
	} 
}
sub _buildTranscoderTable{
	my $client=shift;
	
	#make sure codecs are up to date for the client:
	my $clientCodecList=$class->initClientCodecs($client);
	
	my $prefs= $class->getPreferences($client);
	
	my $transcoderTable= Plugins::C3PO::Shared::getTranscoderTableFromPreferences($prefs,$client);
	
	#add the path to the preference file itself.
	#$transcoderTable->{'pathToPrefFile'}=$EnvironmentHelper->pathToPrefFile();
	
	return $transcoderTable;
}

################################################################################
# Utilities
#

sub _refreshRates{
	my $capsRates = shift;
	my $maxSupportedRate = shift;
	my $prefRef = shift;
	
	my $prefRates =();

	for my $rate (keys %$prefRef){
	
		if (!exists $capsRates->{$rate}){
			next;
		}
		if ($capsRates->{$rate} <= $maxSupportedRate){
			$prefRates->{$rate} = $prefRef->{$rate};
		} else {
			$prefRates->{$rate} = 0;
		}
	}
	for my $rate (keys %$capsRates){
		
		# rate is new added in supported
		if (!exists $prefRates->{$rate}){
				$prefRates->{$rate}=undef;
		} 
	}
	return $prefRates
}

sub _translateRates{
	my $in = shift;
	my $ref = shift;
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("in rates:  ".dump($in));
			 $log->debug("ref rates: ".dump($ref));
	}
	
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
sub _refreshCodecs{
	my $prefRef = shift;
	my $codecs= shift;

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

	return ($prefCodecs);
}
################################################################################
# tobe deletes
#
1;
