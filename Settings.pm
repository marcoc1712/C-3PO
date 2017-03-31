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

package Plugins::C3PO::Settings;

use strict;
use warnings;

use base qw(Slim::Web::Settings);

use Digest::MD5 qw(md5_hex);
use File::Spec::Functions qw(:ALL);
use File::Basename;
use URI::Escape;

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

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/C3PO/settings/basic.html');
}

sub prefs {
    
    #avoid erasure of all preference on save.
	#my @list= $plugin->getSharedPrefNameList();
	my @list=();
    push (@list, 'enable', 'unlimitedDsdRate');
	
	return ($plugin->getPreferences(), @list);		  
}
sub refreshStatus{

	#find a way to refresh the status lines.
}

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug('Settings - handler');	
	}
	
	my $prefs = $plugin->getPreferences();
	
	my $logfile= catdir($prefs->get('logFolder'), "C-3PO.log");
	my $logFileURI = uri_escape ($logfile);
		
	#$params->{'logFolder'}			=	$prefs->get('logFolder');
	$params->{'logFile'}				=	$logfile;
	$params->{'logFileURI'}			=	$logFileURI;

	#$log->info('URI '.$logFileURI);	

	$params->{'soxVersion'}			=	$prefs->get('soxVersion');
	$params->{'isSoxDsdCapable'}    =	$prefs->get('isSoxDsdCapable');
	
	
	my $status= $plugin->getStatus();
	
	$params->{'displayStatus'}	= $status->{'display'};
	$params->{'status'}			= $status->{'status'};
	$params->{'status_msg'}		= $status->{'message'};
	$params->{'status_details'}	= $status->{'details'};
	
	my $prefCodecs = $prefs->get('codecs');
	
	if ($params->{'saveSettings'}){
	
		for my $codec (keys %$prefCodecs){
			
			my $selected = $params->{'pref_codecs'.$codec};
			$prefCodecs->{$codec} = $selected ? 'on' : undef;
		}
		$prefs->set('codecs', $prefCodecs);
		
		$prefs->writeAll();
		# BE SURE TO KEEP FOLLOWING LINE; Otherways settings wont apply without
		# a double pressing of applybutton or a restart.
		#
		$class->SUPER::handler( $client, $params );
		$plugin->settingsChanged();

		$prefs->savenow();
		
	}
	$params->{'prefs'}->{'codecs'}	=	$prefCodecs; 
	$params->{'supportedCodecs'}	=	$plugin->getSupportedCodecs();
	

	if (main::DEBUGLOG && $log->is_debug) {
			$log->debug(dump("preference CODECS: ").
						dump($prefs->get('codecs')));
			$log->debug(dump("supported CODECS: ").
						dump($plugin->getSupportedCodecs()));	
	}
	return $class->SUPER::handler( $client, $params );
}
1;