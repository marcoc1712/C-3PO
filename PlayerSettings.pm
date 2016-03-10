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

package Plugins::C3PO::PlayerSettings;

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Data::Dump qw(dump);

my $log   = logger('plugin.C3PO');

my $plugin;

sub new {
	my $class = shift;
	$plugin   = shift;

	$class->SUPER::new;
}
sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_C3PO_MODULE_NAME');
}

sub needsClient {
	return 1;
}

sub page {
	return return Slim::Web::HTTP::CSRF->protectURI('plugins/C3PO/settings/player.html');
}
sub refreshStatus{

	#find a way to refresh the status lines.
}

#my %showDetails=();

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;
	
	#refresh the codec list.
	my $clientCodecList=$plugin->initClientCodecs($client);
	
	my @prefList=$plugin->getSharedPrefNameList();
	
	$plugin->refreshClientPreferences($client);
	my $prefs=$plugin->getPreferences($client);
	
	my $prefCodecs = $prefs->client($client)->get('codecs');
	my $prefSeeks  = $prefs->client($client)->get('enableSeek');
	my $prefStdin  = $prefs->client($client)->get('enableStdin');
	my $prefConvert  = $prefs->client($client)->get('enableConvert');
	my $prefResample = $prefs->client($client)->get('enableResample');
	
	my $prefSampleRates = $plugin->translateSampleRates(
							$prefs->client($client)->get('sampleRates'));

	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug("Inizio Handler: ");
		$log->debug("showDetails: ");		
		$log->debug(dump($params->{'pref_showDetails'}));
		
		$log->debug("useGlogalSettings - prefs: ".
		            $prefs->client($client)->get('useGlogalSettings').
					" - param: ". $params->{'prefs'}->{'useGlogalSettings'}.
					" - param: ". $params->{'pref_useGlogalSettings'});

	}							

	if (main::DEBUGLOG && $log->is_debug) {
			$log->debug(dump("PREF CODECS before: "));
			$log->debug(dump($prefCodecs));
	}
	
	my $status= $plugin->getStatus($client);
	
	$params->{'displayStatus'}	= $status->{'display'};
	$params->{'status'}			= $status->{'status'};
	$params->{'status_msg'}		= $status->{'message'};
	$params->{'status_details'}	= $status->{'details'};
		
	# SaveSettings pressed #####################################################	
	if ($params->{'saveSettings'}){
	
		# Don't copy into prefs from disabled or not showed  parameters, 
		# it will result in a complete erasure of preferences.
		
		if ($params->{'pref_showDetails'} && $params->{'pref_resampleWhen'}){

			for my $item (@prefList){
				_copyParamsToPrefs($client,$params,$item);
			}
		}
		_copyParamsToPrefs($client,$params,'useGlogalSettings');
		_copyParamsToPrefs($client,$params,'showDetails');
			
		for my $codec (keys %$prefSeeks){
			
			my $selected = $params->{'pref_enableSeek'.$codec};
			$prefSeeks->{$codec} = $selected ? 'on' : undef;
		}
		$prefs->client($client)->set('enableSeek', $prefSeeks);
		
		for my $codec (keys %$prefStdin){
			
			my $selected = $params->{'pref_enableStdin'.$codec};
			$prefStdin->{$codec} = $selected ? 'on' : undef;
		}
		$prefs->client($client)->set('enableStdin', $prefStdin);
		
		for my $codec (keys %$prefConvert){
			
			my $selected = $params->{'pref_enableConvert'.$codec};
			$prefConvert->{$codec} = $selected ? 'on' : undef;
		}
		$prefs->client($client)->set('enableConvert', $prefConvert);
		
		for my $codec (keys %$prefResample){
			
			my $selected = $params->{'pref_enableResample'.$codec};
			$prefResample->{$codec} = $selected ? 'on' : undef;
		}
		$prefs->client($client)->set('enableResample', $prefResample);
		
		for my $rate (keys %$prefSampleRates){
			
			my $selected = $params->{'pref_sampleRates'.$rate};
			$prefSampleRates->{$rate} = $selected ? 'on' : undef;
		}
		$prefs->client($client)->set( 'sampleRates', 
				$plugin->translateSampleRates($prefSampleRates));

		$prefs->writeAll( );
		$plugin->refreshClientPreferences($client);
		$class->SUPER::handler( $client, $params );
		$plugin->settingsChanged($client);
	}
	# END SaveSettings ########################################################
	
	if (main::DEBUGLOG && $log->is_debug) {
			$log->debug(dump("PREF CODECS after: "));
			$log->debug(dump($prefCodecs));
	}
	
	for my $item (@prefList){
	
		_ccopyPrefsToParams($client,$params,$item);
	}
	
	# copy here prefs not in prefList
	
	_ccopyPrefsToParams($client,$params,'useGlogalSettings');
	
	_ccopyPrefsToParams($client,$params,'id');
	_ccopyPrefsToParams($client,$params,'macaddress');
	_ccopyPrefsToParams($client,$params,'modelName');
	_ccopyPrefsToParams($client,$params,'model');
	_ccopyPrefsToParams($client,$params,'name');
	_ccopyPrefsToParams($client,$params,'maxSupportedSamplerate');
	_ccopyPrefsToParams($client,$params,'showDetails');

	$params->{'prefs'}->{'codecs'}=$prefCodecs; 
	$params->{'prefs'}->{'enableSeek'}=$prefSeeks; 
	$params->{'prefs'}->{'enableStdin'}=$prefStdin; 
	$params->{'prefs'}->{'enableConvert'}=$prefConvert; 
	$params->{'prefs'}->{'enableResample'}=$prefResample; 
	$params->{'prefs'}->{'sampleRates'}=$prefSampleRates; 
	
	# copy here params that are not preference.
	#$params->{'showDetails'} = $showDetails{$client->id()};
	
	$params->{'disabledCodecs'}= _getdisabledCodecs($prefCodecs);

	if (main::DEBUGLOG && $log->is_debug) {
			$log->debug(dump("disabledCodecs CODECS: "));
			$log->debug(dump($params->{'disabledCodecs'}));
	}
	
	my $caps= $plugin->getCapabilities();
	my $sampleRates = $caps->{'samplerates'};
	
	$params->{'orderedSampleRates'}=$sampleRates; 
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug(dump("orderedSampleRates: "));	
		$log->debug(dump($params->{'orderedSampleRates'}));
	}
	
	$params->{'disabledSampleRates'}=
		_getdisabledSampleRates($client,$prefSampleRates);		
			
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug(dump("disabledSampleRates: "));		
		$log->debug(dump($params->{'disabledSampleRates'}));
	}
	
	#Show or Hide details.
	#if (!exists $showDetails{$client->id()}){
	#	
	#	$showDetails{$client->id()}=
	#			$prefs->client($client)->get('useGlogalSettings') ? 0 : 1;
	#}
	#flip $showDetails
	#if ($params->{'showDetailsButton'}) {
	#	$showDetails{$client->id()} = $showDetails{$client->id()} ? 0 : 1;
	#}	
	return $class->SUPER::handler($client, $params );
}

###############################################################################
## private
##
sub _getdisabledSampleRates{
	my $client=shift;
	my $prefSampleRates = shift;
	
	my $maxSupportedSamplerate= $client->maxSupportedSamplerate();
	my $caps= $plugin->getCapabilities();
	my $sampleRates = $caps->{'samplerates'};
	
	my $out={};
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug(dump("disabled samplerates: ".$sampleRates).
					dump($sampleRates));
	}

	for my $rate (keys %$prefSampleRates){
		
		if (!($sampleRates->{$rate})){
		
			$out->{$rate} = 1; 
			
		} elsif ($sampleRates->{$rate} > $maxSupportedSamplerate){
		
			$out->{$rate} = 1;
		}
	}
	if (main::DEBUGLOG && $log->is_debug) {
		
		$log->debug(dump("disabled samplerates: ".$out).
					dump($out));	
	}	
	return $out;
}
sub _getdisabledCodecs{
	my $prefCodecs = shift;

	my $C3POprefs	= $plugin->getPreferences();
	my $codecs		= $C3POprefs->get('codecs');
	
	my $out={};

	for my $codec (keys %$prefCodecs){
		
		if (!($codecs->{$codec})){
			$out->{$codec} = 1; 
		}
	}
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug(dump("disabled CODECS: ".$out).
					dump($out));	
	}
	
	return $out;
}
sub _ccopyPrefsToParams{
	my $client = shift;
	my $params = shift;
	my $item = shift;
	
	my $prefs=$plugin->getPreferences();
	
	if (main::DEBUGLOG && $log->is_debug){
		$log->debug($item." :".
			"PREFS: ".dump($prefs->client($client)->get($item)).
			" - PARAMS > pref: ".dump($params->{'prefs'}->{$item}));
	}

	$params->{'prefs'}->{$item} = $prefs->client($client)->get($item);	
}
sub _copyParamsToPrefs{
	my $client = shift;
	my $params = shift;
	my $item = shift;

	my $prefs=$plugin->getPreferences();

	if (main::INFOLOG && $log->is_info) {
		$log->info($item." :".
			"PARAMS pref_: ".dump($params->{'pref_'.$item}).
			" - PREFS: ".dump($prefs->client($client)->get($item)));
	}
	$prefs->client($client)->set($item => $params->{'pref_'.$item});	
}
1;