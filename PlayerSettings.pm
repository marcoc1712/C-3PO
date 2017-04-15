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

my $log;
my $logger;

my $plugin;

sub new {
	my $class = shift;
	$plugin   = shift;
	
	$logger= $plugin->getLogger();
	if ($logger && $logger->{'log'}) {$log=$logger->{'log'};}
	
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

	#find a way to refresh only the status lines.
}

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;
	
    #return early if not $client;
    #if (!$client) {return $class->SUPER::handler($client, $params );}
    if (!$client) {return undef;}
    
	#refresh capabilities, to see chamge in the global options.
	#refresh the codec list.
	$plugin->initClientCodecs($client);
	
    my @prefList=$plugin->getSharedPrefNameList();
	my $prefs=$plugin->getPreferences($client);
    
    $params->{'clientCodecList'} =join ' ', sort keys %{$prefs->client($client)->get('codecsCli')};
    
	$params->{'soxVersion'} =$prefs->get('soxVersion');
	$params->{'isSoxDsdCapable'} =$prefs->get('isSoxDsdCapable');
       
	my $codecsCli    = $prefs->client($client)->get('codecsCli');
	my $prefCodecs   = $prefs->client($client)->get('codecs');
	my $prefSeeks    = $prefs->client($client)->get('enableSeek');
	my $prefStdin    = $prefs->client($client)->get('enableStdin');
	my $prefConvert  = $prefs->client($client)->get('enableConvert');
	my $prefResample = $prefs->client($client)->get('enableResample');
    my $prefEffects  = $prefs->client($client)->get('enableEffects');
   
   my $prefSampleRates = $plugin->translateSampleRates(
							$prefs->client($client)->get('sampleRates'));
	my $prefDsdRates = $plugin->translateDsdRates(
							$prefs->client($client)->get('dsdRates'));

	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug("Inizio Handler: ");
		$log->debug("showDetails: ");		
		$log->debug(dump($params->{'pref_showDetails'}));
		
		$log->debug("useGlogalSettings - prefs: ".
		            $prefs->client($client)->get('useGlogalSettings').
					" - param: ". $params->{'prefs'}->{'useGlogalSettings'}.
					" - param: ". $params->{'pref_useGlogalSettings'});

	}		
    
	my $status= $plugin->getStatus($client);
	
	$params->{'displayStatus'}	= $status->{'display'};
	$params->{'status'}			= $status->{'status'};
	$params->{'status_msg'}		= $status->{'message'};
	$params->{'status_details'}	= $status->{'details'};
	
	my $disabledDsdRates=_getdisabledDsdRates($client,$prefDsdRates);
    
    # store the panel shown.
    my $panel = $prefs->client($client)->get('panel');
    if (!$panel) {
         $prefs->client($client)->set('panel', 'settings');
    }
    
    # restart playback only if settings where changed.
    my $restart=0;
    my $modified=0;
	############################################################################
	# SaveSettings pressed
    #
    if ($params->{'saveSettings'}){
        
        # Don't copy into prefs from disabled or not shown  parameters, 
        # it will result in a complete erasure of preferences.
        
        if ($panel eq 'settings'){
            
            #$restart=1;
            my $modified=0;
            
            if ($params->{'pref_enable'} && ($params->{'pref_resampleWhen'})){

                for my $item (@prefList){
                   $modified = _copyParamsToPrefs($client,$params,$item);
                   $restart = $modified ? $modified : $restart;
                }
                
                my $modified=0;
                
                ($prefSeeks,$modified) = $class->_copyParamToPrefsBooleanHash($params,'enableSeek',$prefSeeks);
                $prefs->client($client)->set('enableSeek', $prefSeeks);
                
                $restart = $modified ? $modified : $restart;
                
                ($prefStdin,$modified) =  $class->_copyParamToPrefsBooleanHash($params,'enableStdin',$prefStdin);
                $prefs->client($client)->set('enableStdin', $prefStdin);
                                
                $restart = $modified ? $modified : $restart;
                
                ($prefConvert,$modified) =  $class->_copyParamToPrefsBooleanHash($params,'enableConvert',$prefConvert);
                $prefs->client($client)->set('enableConvert', $prefConvert);
                                
                $restart = $modified ? $modified : $restart;
                
                ($prefResample,$modified) = $class->_copyParamToPrefsBooleanHash($params,'enableResample',$prefResample);
                $prefs->client($client)->set('enableResample', $prefResample);
                                
                $restart = $modified ? $modified : $restart;
                
                ($prefEffects,$modified) = $class->_copyParamToPrefsBooleanHash($params,'enableEffects',$prefEffects);
                $prefs->client($client)->set('enableEffects', $prefEffects);
                
                $restart = $modified ? $modified : $restart;
                
                ($prefSampleRates,$modified) = $class->_copyParamToPrefsBooleanHash($params,'sampleRates',$prefSampleRates);
                $prefs->client($client)->set( 'sampleRates', $plugin->translateSampleRates($prefSampleRates));
                                
                $restart = $modified ? $modified : $restart;
                
                ($prefDsdRates,$modified) = $class->_copyParamToPrefsBooleanHash($params,'dsdRates',$prefDsdRates);
                $prefs->client($client)->set( 'dsdRates', $plugin->translateDsdRates($prefDsdRates));
                                
                $restart = $modified ? $modified : $restart;
                
            }   
            $modified = _copyParamsToPrefs($client,$params,'enable');
            $restart = $modified ? $modified : $restart;
        } 
        _copyParamsToPrefs($client,$params,'panel');

        $prefs->writeAll();
        $prefs->savenow();

        $plugin->getPreferences($client);
        $class->SUPER::handler( $client, $params );
        $plugin->settingsChanged($client,$restart);

        $prefs->savenow();
    }
	# END SaveSettings ########################################################
    
	$params->{'fileTypeTable'}= $plugin->getHtmlConversionTable(0,$client);
    $params->{'resultingCommands'}= $plugin->getHtmlConversionTable(1,$client);
    
    my $lastCommand=$plugin->getLastCommand($client->id());
    
    $params->{'lastCommand_time'}=$lastCommand->{'time'};
    $params->{'lastCommand_profile'}=$lastCommand->{'profile'};
    $params->{'lastCommand_command'}=$lastCommand->{'command'};
    $params->{'lastCommand_tokenized'}=$lastCommand->{'tokenized'};
    $params->{'lastCommand_C3PO'}=$lastCommand->{'C-3PO'};

	for my $item (@prefList){
	
		_copyPrefsToParams($client,$params,$item);
	}
	
	# copy here prefs not in prefList
	
	# sanity check after 2.00.06 changes.
	#_copyPrefsToParams($client,$params,'useGlogalSettings');
	$prefs->client($client)->set('useGlogalSettings',undef);
	$params->{'pref_useGlogalSettings'}=0;
	$prefs->client($client)->set('showDetails','on');
	$params->{'pref_showDetails'}=1;
	
	_copyPrefsToParams($client,$params,'id');
	_copyPrefsToParams($client,$params,'macaddress');
	_copyPrefsToParams($client,$params,'modelName');
	_copyPrefsToParams($client,$params,'model');
	_copyPrefsToParams($client,$params,'name');
	_copyPrefsToParams($client,$params,'maxSupportedSamplerate');
	_copyPrefsToParams($client,$params,'showDetails');

	$params->{'prefs'}->{'codecsCli'}=$codecsCli; 
	$params->{'prefs'}->{'codecs'}=$prefCodecs; 
	$params->{'prefs'}->{'enableSeek'}=$prefSeeks; 
	$params->{'prefs'}->{'enableStdin'}=$prefStdin; 
	$params->{'prefs'}->{'enableConvert'}=$prefConvert; 
	$params->{'prefs'}->{'enableResample'}=$prefResample; 
    $params->{'prefs'}->{'enableEffects'}=$prefEffects;
	$params->{'prefs'}->{'sampleRates'}=$prefSampleRates; 
	$params->{'prefs'}->{'dsdRates'}=$prefDsdRates; 
	
	# copy here params that are not preference.
	
	$params->{'disabledCodecs'}= _getdisabledCodecs($client, $prefCodecs);

	if (main::DEBUGLOG && $log->is_debug) {
			$log->debug(dump("disabledCodecs CODECS: "));
			$log->debug(dump($params->{'disabledCodecs'}));
	}
	
	my $sampleRates = $plugin-> getSampleRates();
	my $dsdRates = $plugin-> getDsdRates();
	
	$params->{'OrderedPcmSampleRates'}=$sampleRates; 
	$params->{'OrderedDsdRates'}=$dsdRates; 
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug(dump("OrderedPcmSampleRates: "));	
		$log->debug(dump($params->{'OrderedPcmSampleRates'}));
		$log->debug(dump("OrderedDsdRates: "));	
		$log->debug(dump($params->{'OrderedDsdRates'}));
	}
	
	$params->{'disabledSampleRates'}=
		_getdisabledSampleRates($client,$prefSampleRates);		
		
	$params->{'disabledDsdRates'}=
		_getdisabledDsdRates($client,$prefDsdRates);
			
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug(dump("disabledSampleRates: "));		
		$log->debug(dump($params->{'disabledSampleRates'}));
		$log->debug(dump("disabledDsdRates: "));		
		$log->debug(dump($params->{'disabledDsdRates'}));
	}
	
	return $class->SUPER::handler($client, $params );
}

###############################################################################
## private
##
sub _getdisabledSampleRates{
	my $client=shift;
	my $prefSampleRates = shift;
	
	my $maxSupportedSamplerate= $plugin->getMaxSupportedSampleRate($client);
	
	my $sampleRates = $plugin-> getSampleRates();

	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug(dump("samplerates: ".$sampleRates).
					dump($sampleRates));
	}
	my $out;
	my $enabledRates = _getEnabledRates($prefSampleRates,$sampleRates,$maxSupportedSamplerate);
	
	for my $rate (keys %$enabledRates){
		
		if (!$enabledRates->{$rate}){
		
			$out->{$rate} = 1;	
		}
	
	} 
	
	if (main::DEBUGLOG && $log->is_debug) {
		
		$log->debug(dump("disabled samplerates: ".$out).
					dump($out));	
	}	
	return $out;
}
sub _getdisabledDsdRates{
	my $client=shift;
	my $prefDsdRates = shift;

	my $maxSupportedDsdRate= $plugin->getMaxSupportedDsdRate($client);
	my $dsdrates = $plugin-> getDsdRates();

	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug(dump("dsd rates: ".$dsdrates).
					dump($dsdrates));
	}

	my $enabledRates = _getEnabledRates($prefDsdRates,$dsdrates,$maxSupportedDsdRate);
	my $out;
	my $first=1;
	for my $rate (sort keys %$enabledRates){
		
		#disable first enable, so it could not be removed.
		#if ($first && $enabledRates->{$rate}){
		#	$first=0;
		#	$out->{$rate} = 1;	
		#} elsif (!($enabledRates->{$rate})){
            
		if (!($enabledRates->{$rate})){
			$out->{$rate} = 1;
		}
	} 
	if (main::DEBUGLOG && $log->is_debug) {
		
		$log->debug(dump("disabled dsd rates: ".$out).
					dump($out));	
	}	
	return $out;
}
sub _getEnabledRates{
	my $prefRates = shift;
	my $capsRates = shift;
	my $maxSupportedRate = shift || 0;
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug("max rate: ".$maxSupportedRate);	
		$log->debug(dump("prefs rates: ").
					dump($prefRates));	
		$log->debug(dump("caps rates: ").
					dump($prefRates));	
	}
	my $out={};

	for my $rate (keys %$prefRates){
		
		if (!($capsRates->{$rate})){
		
			$out->{$rate} = 0; 
			
		} elsif ($capsRates->{$rate} > $maxSupportedRate){
		
			$out->{$rate} = 0;	
		} else {
			
			$out->{$rate} = 1;	
		}
	}

	return $out;
}
sub _getdisabledCodecs{
	my $client= shift;
	my $inCodecs = shift;

	my $C3POprefs	= $plugin->getPreferences();
	my $codecs		= $C3POprefs->get('codecs');
	#my $codecCli	= $C3POprefs->client($client)->get('codecsCli');

	if (main::DEBUGLOG && $log->is_debug) {
	
		$log->debug(dump("in    Codecs: ").dump($inCodecs));
		$log->debug(dump("Prefs Codecs: ").dump($codecs));	
		#$log->debug(dump("Cli   Codecs: ").dump($codecCli));	
	}
	
	my $out={};
	#if (!$codecs || !$codecCli) {}
	if (!$codecs){
		return $inCodecs;
	}
	for my $codec (keys %$inCodecs){
		
		if (main::DEBUGLOG && $log->is_debug) {
			$log->debug(dump("in    Codec: ").dump($codec));
			$log->debug(dump("Prefs Codec: ").dump($codecs->{$codec}));	
			#$log->debug(dump("Cli   Codec: ").dump($codecCli->{$codec}));	
		}

		#if ( !$codecs->{$codec} || !$codecCli->{$codec}) {}
		if ( !$codecs->{$codec}) {
		
			$out->{$codec} = 1; 

		} 
	}
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug(dump("disabled CODECS: ").
					dump($out));	
	}
	
	return $out;
}
sub _copyPrefsToParams{
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

	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug($item." :".
			"PARAMS pref_: ".dump($params->{'pref_'.$item}).
			" - PREFS: ".dump($prefs->client($client)->get($item)));
	}
    
    my $old= $prefs->client($client)->get($item);
    my $new = $params->{'pref_'.$item};

	$prefs->client($client)->set($item => $new);
    
    #never restart if only the panel change.
    if ($item eq 'panel')   {return 0;}
    
    if (!$old && !$new)     {return 0;}
    if (!$old || !$new)     {return 1;}
    if ($old eq $new)       {return 0;}
    
    return 1;
    
}
sub _copyParamToPrefsBooleanHash{
    my $self    = shift;
    my $params  = shift;
    my $name    = shift;
	my $item    = shift;
    
    my $modified=0;
    
    for my $k (keys %$item){
        
        my $old = $item->{$k};
        my $new = $params->{'pref_'.$name.$k} ? 'on' : undef;
        
        $item->{$k} = $new;
        
        if (($old && (!$new || !($old eq $new) )) || 
            ($new && (!$old || !($new eq $old) ))) {
           
            $modified = 1;  
        }   
    }
    return ($item, $modified);
}
1;
