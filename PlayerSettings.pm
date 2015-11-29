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
my %showDetails={};

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;
	
	my @prefList=Plugins::C3PO::Shared::getSharedPrefNameList();
	
	Plugins::C3PO::Plugin::refreshClientPreferences($client);
	my $prefs=Plugins::C3PO::Plugin::getPreferences($client);
	
	my $prefCodecs = $prefs->client($client)->get('codecs');
	my $prefSeeks  = $prefs->client($client)->get('enableSeek');
	
	my $prefSampleRates = Plugins::C3PO::Plugin::translateSampleRates(
								$prefs->client($client)->get('sampleRates'));

	#Show or Hide details.
	if (!defined $showDetails{$client->id()}){
		
		$showDetails{$client->id()}=
				$prefs->client($client)->get('useGlogalSettings') ? 0 : 1;
	}

	if ($params->{'saveSettings'}){

		# Don't copy into prefs from disabled or not showed  parameters, 
		# it will result in a complete erasure of preferences.
		
		if ($showDetails{$client->id()} && $params->{'pref_resampleWhen'}){

			for my $item (@prefList){
				copyParamsToPrefs($client,$params,$item);
			}
		}
		copyParamsToPrefs($client,$params,'useGlogalSettings');
		
		for my $codec (keys %$prefCodecs){
			
			my $selected = $params->{'pref_codecs'.$codec};
			$prefCodecs->{$codec} = $selected ? 'on' : undef;
		}
		$prefs->client($client)->set('codecs', $prefCodecs);
		
		for my $codec (keys %$prefSeeks){
			
			my $selected = $params->{'pref_enableSeek'.$codec};
			$prefSeeks->{$codec} = $selected ? 'on' : undef;
		}
		$prefs->client($client)->set('enableSeek', $prefSeeks);
		
		for my $rate (keys %$prefSampleRates){
			
			my $selected = $params->{'pref_sampleRates'.$rate};
			$prefSampleRates->{$rate} = $selected ? 'on' : undef;
		}
		$prefs->client($client)->set(
				'sampleRates', 
				Plugins::C3PO::Plugin::translateSampleRates($prefSampleRates));
		
		Plugins::C3PO::Plugin::setupTranscoder($client);
	}	
	if ($params->{'showDetailsButton'}) {
		$showDetails{$client->id()} = $showDetails{$client->id()} ? 0 : 1;
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
	$params->{'prefs'}->{'sampleRates'}=$prefSampleRates; 
	
	
	# copy here params that are not preference.
	$params->{'showDetails'} = $showDetails{$client->id()};
	
	$params->{'disabledCodecs'}=getdisabledCodecs($prefCodecs);

	if (main::DEBUGLOG && $log->is_debug) {$log->debug(
			dump("disabledCodecs CODECS: ".$params->{'disabledCodecs'}));		
	}
	
	if (main::DEBUGLOG && $log->is_debug) {$log->debug(
			dump($params->{'disabledCodecs'}));
	}
	
	my $caps= Plugins::C3PO::Plugin::getCapabilities();
	my $sampleRates = $caps->{'samplerates'};
	
	$params->{'orderedSampleRates'}=$sampleRates; 
	
	if (main::DEBUGLOG && $log->is_debug) {$log->debug(
			dump("orderedSampleRates: ".$params->{'orderedSampleRates'}));	
	}
	
	if (main::DEBUGLOG && $log->is_debug) {$log->debug(
			dump($params->{'orderedSampleRates'}));
	}
	
	$params->{'disabledSampleRates'}=
		getdisabledSampleRates($client,$prefSampleRates);		
			
	if (main::DEBUGLOG && $log->is_debug) {$log->debug(
			dump("disabledSampleRates: ".$params->{'disabledSampleRates'}));		
	}
	if (main::DEBUGLOG && $log->is_debug) {$log->debug(
			dump($params->{'disabledSampleRates'}));
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
	my $caps= Plugins::C3PO::Plugin::getCapabilities();
	my $codecs = $caps->{'codecs'};
	my $out={};
	
	if (main::DEBUGLOG && $log->is_debug) {
	
		$log->debug(dump("capabilities: ".$caps).
					dump($caps));
	}
	
	for my $codec (keys %$prefCodecs){
		
		if (!($codecs->{$codec}->{'supported'})){
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