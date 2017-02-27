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
package Plugins::C3PO::PreferencesHelper;

use strict;
use warnings;

use Slim::Utils::Prefs;

my $class;
my $log;

sub new {
    $class = shift;
	my $logger = shift;
	my $preferences = shift;
	my $client = shift;
	
	if ($logger && $logger->{'log'}) {$log=$logger->{'log'};}
    
	my $self = bless {
		preferences => $preferences,
		
    }, $class;
    
    $self->_init($client);
    return $self;
}
sub preferences {
    my $self = shift;  
    return $self->{preferences};
}

####################################################################################################
# Private
#
sub _init{
	my $self = shift;
	my $client	= shift || undef;

	my $curentVersion	= $self->_getCurrentVersion();
	my $prefVersion;
	
	if ($client){
	
		$prefVersion = $self->{preferences}->client($client)->get('version');
		
	} else {
	
		$prefVersion =  $self->{preferences}->get('version');
	}
	
	if (!$prefVersion){$prefVersion = 0};
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug("Prefs version: ".$prefVersion);
	}
	
	if ($curentVersion > $prefVersion){
		
		 $self->_migratePrefs($curentVersion, $prefVersion, $client);
		
	} elsif ($prefVersion > $curentVersion){
	
		$log->warn("C-3PO version is: ".$curentVersion.", preference Version is: ".$prefVersion." Could not migrate back");
	}
	
	if  ($client && $self->{preferences}->client($client)->get('useGlogalSettings')){

		for my $item (Plugins::C3PO::Shared::getSharedPrefNameList()){
			$self->{preferences}->client($client)->set($item, $self->{preferences}->get($item));
		}
	}
}

sub _migratePrefs{
	my $self = shift;
	my $curentVersion	= shift;
	my $prefVersion		= shift;
	my $client			= shift;
	
	if (main::INFOLOG && $log->is_info) {
	
		if ($client){
			$log->info("_migratePrefs for client: ".$client." from: ".$prefVersion." to: ".$curentVersion);
		} else{
			$log->info("_migratePrefs from: ".$prefVersion." to: ".$curentVersion);
		}
	}
	
	if ((!$client && $prefVersion == 0 && !($self->{preferences}->get('outCodec'))) ||
		($client && $prefVersion == 0 && !($self->{preferences}->client($client)->get('outCodec')))){

		#C-3PO is running for the first time
		$self->_initDefaultPrefs($client);

	} elsif ($prefVersion == 0){
	
		 #C-3PO was running prior v. 1.1.03
		 
		if ($client){
		
			if  (! $self->{preferences}->client($client)->get('useGlogalSettings')){

				# some adjustement from version 1.0 to 1.1

				if ($self->{preferences}->client($client)->get('extra')){
					$self->{preferences}->client($client)->set('extra_after_rate', 
					$self->{preferences}->client($client)->get('extra'));
				}
				
				if (!($self->{preferences}->client($client)->get('ditherType')) || 
					 $self->{preferences}->client($client)->get('ditherType') eq "X" ){

					if (!$self->{preferences}->client($client)->get('dither')){
						$self->{preferences}->client($client)->set('ditherType', -1);
					} else {
						$self->{preferences}->client($client)->set('ditherType', 1);
					}
					
					$self->{preferences}->set('ditherPrecision', -1);
				}
				
				# some adjustement for 1.1.2

				if (! $self->{preferences}->client($client)->get('loudnessRef')){
					$self->{preferences}->client($client)->set('headroom', $self->{preferences}->get('headroom'));
					$self->{preferences}->client($client)->set('loudnessGain', $self->{preferences}->get('loudnessGain'));
					$self->{preferences}->client($client)->set('loudnessRef', $self->{preferences}->get('loudnessRef'));
					$self->{preferences}->client($client)->set('remixLeft', $self->{preferences}->get('remixLeft'));
					$self->{preferences}->client($client)->set('remixRight', $self->{preferences}->get('remixRight'));
					$self->{preferences}->client($client)->set('flipChannels', $self->{preferences}->get('flipChannels'));			
				}
			}
			
			$self->{preferences}->client($client)->remove( 'outEncoding' );
			$self->{preferences}->client($client)->remove( 'outChannels' );
			$self->{preferences}->client($client)->remove( 'extra' );
			$self->{preferences}->client($client)->remove( 'dither' );

		} else { #server
		 
			$self->{preferences}->init({				
			   headroom					=> "1",
			   gain						=> 0,
			   loudnessGain				=> 0,
			   loudnessRef				=> 65,
			   remixLeft				=> 100,
			   remixRight				=> 100,
			   flipChannels				=> "0",
			   extra_before_rate		=> "",
			   extra_after_rate			=> "",
		   });

			# some adjustement from version 1.0 to 1.1

		   if ($self->{preferences}->get('extra')){
			   $self->{preferences}->set('extra_after_rate', $self->{preferences}->get('extra'));
		   }
		   if (! $self->{preferences}->get('ditherType')){
		   
			   if (!$self->{preferences}->get('dither')){
				   $self->{preferences}->set('ditherType', -1);
			   } else {
				   $self->{preferences}->set('ditherType', 1);
			   }
			  $self->{preferences}->set('ditherPrecision', -1);
		   }
		   		   
		   $self->{preferences}->remove( 'outEncoding' );
		   $self->{preferences}->remove( 'outChannels' );
		   $self->{preferences}->remove( 'extra' );
		   $self->{preferences}->remove( 'dither' );
	    } 
		
	} #here specifIc advancements from versions greather than 1.1.02

	if ($prefVersion < 10106){
		
		if (!$client){
		
			$self->{preferences}->set('enable', 'on');
			$self->{preferences}->set('unlimitedDsdRate', '');
			
			$self->{preferences}->set('noIOpt','');
			$self->{preferences}->set('highPrecisionClock','');
			$self->{preferences}->set('smallRollOff','on');
			$self->{preferences}->set('sdmFilterType','auto');
		
			$self->{preferences}->set('dsdLowpass1Value',22);
			$self->{preferences}->set('dsdLowpass1Order',2);
			#$self->{preferences}->set('dsdLowpass1Active','on');

			$self->{preferences}->set('dsdLowpass2Value',33);
			$self->{preferences}->set('dsdLowpass2Order',2);
			$self->{preferences}->set('dsdLowpass2Active','');


			$self->{preferences}->set('dsdLowpass3Value',44);
			$self->{preferences}->set('dsdLowpass3Order',2);
			$self->{preferences}->set('dsdLowpass3Active','');
			
			$self->{preferences}->set('dsdLowpass4Value',48);
			$self->{preferences}->set('dsdLowpass4Order',2);
			$self->{preferences}->set('dsdLowpass4Active','');

		} else{
		
			$self->{preferences}->client($client)->set('enable', 'on');
			
			if  ($self->{preferences}->get('noIOpt')){
				$self->{preferences}->client($client)->set('noIOpt','on');
			} else{
				$self->{preferences}->client($client)->set('noIOpt','');
			}
			
			if  ($self->{preferences}->get('highPrecisionClock')){
				$self->{preferences}->client($client)->set('highPrecisionClock','on');
			} else{
				$self->{preferences}->client($client)->set('highPrecisionClock','');
			}
			
			if  ($self->{preferences}->get('smallRollOff')){
				$self->{preferences}->client($client)->set('smallRollOff','on');
			} else{
				$self->{preferences}->client($client)->set('smallRollOff','');
			}
			
			if  ($self->{preferences}->get('sdmFilterType')){
				$self->{preferences}->client($client)->set('sdmFilterType',
								$self->{preferences}->get('sdmFilterType'));
			} else{
				$self->{preferences}->client($client)->set('sdmFilterType','auto');
			}
			
			if  ($self->{preferences}->get('dsdLowpass1Value')){
				$self->{preferences}->client($client)->set('dsdLowpass1Value',
								$self->{preferences}->get('dsdLowpass1Value'));
				$self->{preferences}->client($client)->set('dsdLowpass1Order',
								$self->{preferences}->get('dsdLowpass1Order'));
				#$self->{preferences}->client($client)->set('dsdLowpass1Active',
				#				$self->{preferences}->get('dsdLowpass1Active'));
								
				$self->{preferences}->client($client)->set('dsdLowpass2Value',
								$self->{preferences}->get('dsdLowpass2Value'));
				$self->{preferences}->client($client)->set('dsdLowpass2Order',
								$self->{preferences}->get('dsdLowpass2Order'));
				$self->{preferences}->client($client)->set('dsdLowpass2Active',
								$self->{preferences}->get('dsdLowpass2Active'));
								
				$self->{preferences}->client($client)->set('dsdLowpass3Value',
								$self->{preferences}->get('dsdLowpass3Value'));
				$self->{preferences}->client($client)->set('dsdLowpass3Order',
								$self->{preferences}->get('dsdLowpass3Order'));
				$self->{preferences}->client($client)->set('dsdLowpass3Active',
								$self->{preferences}->get('dsdLowpass3Active'));
								
				$self->{preferences}->client($client)->set('dsdLowpass4Value',
								$self->{preferences}->get('dsdLowpass4Value'));
				$self->{preferences}->client($client)->set('dsdLowpass4Order',
								$self->{preferences}->get('dsdLowpass4Order'));
				$self->{preferences}->client($client)->set('dsdLowpass4Active',
								$self->{preferences}->get('dsdLowpass4Active'));
								
			} else{
				$self->{preferences}->client($client)->set('dsdLowpass1Value','22');
				$self->{preferences}->client($client)->set('dsdLowpass1Order',2);
				#$self->{preferences}->client($client)->set('dsdLowpass1Active','on');

				$self->{preferences}->client($client)->set('dsdLowpass2Value',33);
				$self->{preferences}->client($client)->set('dsdLowpass2Order',2);
				$self->{preferences}->client($client)->set('dsdLowpass2Active','');

				$self->{preferences}->client($client)->set('dsdLowpass3Value',44);
				$self->{preferences}->client($client)->set('dsdLowpass3Order',2);
				$self->{preferences}->client($client)->set('dsdLowpass3Active','');

				$self->{preferences}->client($client)->set('dsdLowpass4Value',48);
				$self->{preferences}->client($client)->set('dsdLowpass4Order',2);
				$self->{preferences}->client($client)->set('dsdLowpass4Active','');
			}
		}
	}
	
	if ($prefVersion < 20006){
	
			if (!$client){
			
			} else{
				
				$self->{preferences}->client($client)->set('useGlogalSettings','');
				$self->{preferences}->client($client)->set('showDetails','on');
			}
	}
	
	# upgrade version.
	if ($client){
	
		$self->{preferences}->client($client)->set('version',$curentVersion);
	
	} else{
	
		$self->{preferences}->set('version',$curentVersion);
	}
	$self->{preferences}->writeAll();
	$self->{preferences}->savenow();
	
	if ($client){
	
		$prefVersion = $self->{preferences}->client($client)->get('version');
		
	} else {
	
		$prefVersion = $self->{preferences}->get('version');
	}
	
	if (main::INFOLOG && $log->is_info) {
	
		if ($client){
			$log->info(" Prefs for client: ".$client." migrated to: ".$prefVersion);
		} else{
			$log->info("Prefs migrated to: ".$prefVersion);
		}
	}
}
sub _initDefaultPrefs{
	my $self = shift;
	my $client = shift;

	if (main::INFOLOG && $log->is_info) {
	
		if ($client){
			$log->info("_initDefaultPrefs for client: ".$client);
		} else{
			$log->info("_initDefaultPrefs");
		}
	}
	
	# sets default values for 'real' preferences.
	if ($client){
	
		$self->{preferences}->client($client)->set('enable', 'on');
		$self->{preferences}->client($client)->set('useGlogalSettings', 'on');
	
	} else {
	
		$self->{preferences}->init({
			enable						=> "on",
			unlimitedDsdRate			=> "0",
			resampleWhen				=> "A",
			resampleTo					=> "S",
			outCodec					=> "wav",
			outBitDepth					=> 3,
			#outEncoding				=> undef,
			#outChannels				=> 2,
			headroom					=> "1",
			gain						=> 0,
			loudnessGain				=> 0,
			loudnessRef					=> 65,
			remixLeft					=> 100,
			remixRight					=> 100,
			flipChannels				=> "0",
			quality						=> "v",
			phase						=> "I",
			aliasing					=> "0",
			noIOpt						=> "0",
			smallRollOff				=> "on",
			highPrecisionClock			=> "0",
			bandwidth					=> 907,
			#dither						=> "on",
			ditherType					=> "1",
			ditherPrecision				=> -1,
			sdmFilterType				=> "auto",
			dsdLowpass1Value			=> 22,
			dsdLowpass1Order			=> 2,
			#dsdLowpass1Active			=> "on",
			dsdLowpass2Value			=> 33,
			dsdLowpass2Order			=> 2,
			dsdLowpass2Active			=> "0",
			dsdLowpass3Value			=> 44,
			dsdLowpass3Order			=> 2,
			dsdLowpass3Active			=> "0",
			dsdLowpass4Value			=> 48,
			dsdLowpass4Order			=> 2,
			dsdLowpass4Active			=> "0",
			#extra						=> "",
			extra_before_rate			=> "",
			extra_after_rate			=> "",
		});
	}
}
sub _getCurrentVersion{
	my $self = shift;
	my $plugins = Slim::Utils::PluginManager->allPlugins;
	
	my $currentVersion;
	
	for my $plugin (keys %$plugins) {

		if ($plugin eq 'C3PO'){
			my $entry = $plugins->{$plugin};
			$currentVersion = $entry->{'version'};
			last;
		}
	}
	my ($version, $extra)= Plugins::C3PO::Shared::unstringVersion($currentVersion,$log);

	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug("C-3PO version is: ".$version.($extra ? $extra : ''));
	}
	
	return $version;
}
1;
