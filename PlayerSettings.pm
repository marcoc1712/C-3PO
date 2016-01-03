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

sub name {
	return Slim::Web::HTTP::CSRF->protectName('PLUGIN_C3PO_MODULE_NAME');
}

sub needsClient {
	return 1;
}

sub page {
	return return Slim::Web::HTTP::CSRF->protectURI('plugins/C3PO/settings/player.html');
}
my %showDetails=();

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;
	
	#refresh the codec list.
	my $clientCodecList=Plugins::C3PO::Plugin::initClientCodecs($client);
		
	my @prefList=Plugins::C3PO::Shared::getSharedPrefNameList();
	
	Plugins::C3PO::Plugin::refreshClientPreferences($client);
	my $prefs=Plugins::C3PO::Plugin::getPreferences($client);
	
	my $prefCodecs = $prefs->client($client)->get('codecs');
	my $prefSeeks  = $prefs->client($client)->get('enableSeek');
	my $prefStdin  = $prefs->client($client)->get('enableStdin');
	my $prefConvert  = $prefs->client($client)->get('enableConvert');
	my $prefResample = $prefs->client($client)->get('enableResample');
	
	my $prefSampleRates = Plugins::C3PO::Plugin::translateSampleRates(
								$prefs->client($client)->get('sampleRates'));

	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug("Inizio Handler: ");
		$log->debug("showDetails: ");		
		$log->debug(dump(%showDetails));
		
		$log->debug("useGlogalSettings - prefs: ".
		            $prefs->client($client)->get('useGlogalSettings').
					" - param: ". $params->{'prefs'}->{'useGlogalSettings'}.
					" - param: ". $params->{'pref_useGlogalSettings'});

	}							

	if (main::DEBUGLOG && $log->is_debug) {
			$log->debug(dump("PREF CODECS before: "));
			$log->debug(dump($prefCodecs));
	}
	
	my $status= Plugins::C3PO::Plugin::getStatus($client);
	
	$params->{'displayStatus'}	= $status->{'display'};
	$params->{'status'}			= $status->{'status'};
	$params->{'status_msg'}		= $status->{'message'};
	$params->{'status_details'}	= $status->{'details'};
		
	###########################################################################	
	
	if ($params->{'saveSettings'}){
	
		# Don't copy into prefs from disabled or not showed  parameters, 
		# it will result in a complete erasure of preferences.
		
		if ($showDetails{$client->id()} && $params->{'pref_resampleWhen'}){

			for my $item (@prefList){
				copyParamsToPrefs($client,$params,$item);
			}
		}
		
		copyParamsToPrefs($client,$params,'useGlogalSettings');
			
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
				Plugins::C3PO::Plugin::translateSampleRates($prefSampleRates));
		
		
		$prefs->writeAll( );
		$class->SUPER::handler( $client, $params );
		Plugins::C3PO::Plugin::settingsChanged($client);
	}
	############################################################################
	
	if (main::DEBUGLOG && $log->is_debug) {
			$log->debug(dump("PREF CODECS after: "));
			$log->debug(dump($prefCodecs));
	}
	
	for my $item (@prefList){
	
		copyPrefsToParams($client,$params,$item);
	}
	
	# copy here prefs not in prefList
	
	copyPrefsToParams($client,$params,'useGlogalSettings');
	
	copyPrefsToParams($client,$params,'id');
	copyPrefsToParams($client,$params,'macaddress');
	copyPrefsToParams($client,$params,'modelName');
	copyPrefsToParams($client,$params,'model');
	copyPrefsToParams($client,$params,'name');
	copyPrefsToParams($client,$params,'maxSupportedSamplerate');

	$params->{'prefs'}->{'codecs'}=$prefCodecs; 
	$params->{'prefs'}->{'enableSeek'}=$prefSeeks; 
	$params->{'prefs'}->{'enableStdin'}=$prefStdin; 
	$params->{'prefs'}->{'enableConvert'}=$prefConvert; 
	$params->{'prefs'}->{'enableResample'}=$prefResample; 
	$params->{'prefs'}->{'sampleRates'}=$prefSampleRates; 
	
	# copy here params that are not preference.
	$params->{'showDetails'} = $showDetails{$client->id()};
	
	$params->{'disabledCodecs'}=getdisabledCodecs($prefCodecs);

	if (main::DEBUGLOG && $log->is_debug) {
			$log->debug(dump("disabledCodecs CODECS: "));
			$log->debug(dump($params->{'disabledCodecs'}));
	}
	
	my $caps= Plugins::C3PO::Plugin::getCapabilities();
	my $sampleRates = $caps->{'samplerates'};
	
	$params->{'orderedSampleRates'}=$sampleRates; 
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug(dump("orderedSampleRates: "));	
		$log->debug(dump($params->{'orderedSampleRates'}));
	}
	
	$params->{'disabledSampleRates'}=
		getdisabledSampleRates($client,$prefSampleRates);		
			
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug(dump("disabledSampleRates: "));		
		$log->debug(dump($params->{'disabledSampleRates'}));
	}
	
	#Show or Hide details.
	if (!exists $showDetails{$client->id()}){
		
		$showDetails{$client->id()}=
				$prefs->client($client)->get('useGlogalSettings') ? 0 : 1;
	}
	#flip $showDetails
	if ($params->{'showDetailsButton'}) {
		$showDetails{$client->id()} = $showDetails{$client->id()} ? 0 : 1;
	}	
	return $class->SUPER::handler($client, $params );
}
sub getdisabledSampleRates{
	my $client=shift;
	my $prefSampleRates = shift;
	
	my $maxSupportedSamplerate= $client->maxSupportedSamplerate();
	my $caps= Plugins::C3PO::Plugin::getCapabilities();
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
sub getdisabledCodecs{
	my $prefCodecs = shift;

	my $C3POprefs	= Plugins::C3PO::Plugin::getPreferences();
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
sub copyPrefsToParams{
	my $client = shift;
	my $params = shift;
	my $item = shift;
	
	my $prefs=Plugins::C3PO::Plugin::getPreferences();
	
	if (main::DEBUGLOG && $log->is_debug){
		$log->debug($item." :".
			"PREFS: ".dump($prefs->client($client)->get($item)).
			" - PARAMS > pref: ".dump($params->{'prefs'}->{$item}));
	}

	$params->{'prefs'}->{$item} = $prefs->client($client)->get($item);	
}
sub copyParamsToPrefs{
	my $client = shift;
	my $params = shift;
	my $item = shift;

	my $prefs=Plugins::C3PO::Plugin::getPreferences();

	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug($item." :".
			"PARAMS pref_: ".dump($params->{'pref_'.$item}).
			" - PREFS: ".dump($prefs->client($client)->get($item)));
	}
	$prefs->client($client)->set($item => $params->{'pref_'.$item});	
}
1;