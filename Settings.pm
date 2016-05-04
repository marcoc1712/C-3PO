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

use Slim::Utils::Log;
use Slim::Utils::Prefs;
use Data::Dump qw(dump);

my $prefs = preferences('plugin.C3PO');
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

sub page {
	return Slim::Web::HTTP::CSRF->protectURI('plugins/C3PO/settings/basic.html');
}

sub prefs {
	return ($prefs, $plugin->getSharedPrefNameList());		  
}
sub refreshStatus{

	#find a way to refresh the status lines.
}

sub handler {
	my ($class, $client, $params, $callback, @args) = @_;
	
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug('Settings - handler');	
	}
	
	$params->{'logFolder'} =$prefs->get('logFolder');
	$params->{'soxVersion'} =$prefs->get('soxVersion');
	
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
		$prefs->savenow();
		
		$class->SUPER::handler( $client, $params );
		$plugin->settingsChanged();
	}
	$params->{'prefs'}->{'codecs'}=$prefCodecs; 
	$params->{'disabledCodecs'}=getdisabledCodecs($prefCodecs);

	if (main::DEBUGLOG && $log->is_debug) {
			$log->debug(
				dump("preference CODECS: ").
				dump($prefs->get('codecs')));	
	}
	return $class->SUPER::handler( $client, $params );
}
sub getdisabledCodecs{
	my $prefCodecs = shift;
	my $capabilities= $plugin->getCapabilities();
	my $caps = $capabilities->{'codecs'};
	my $out={};
	
	if (main::DEBUGLOG && $log->is_debug) {
	
		$log->debug(dump("capabilities: ").
					dump($capabilities));
	}
	
	for my $codec (keys %$prefCodecs){
		
		if (!($caps->{$codec}->{'supported'})){
			$out->{$codec} = 1; 
		}
	}
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug(dump("disabled CODECS: ".$out).
					dump($out));	
	}
	return $out;
}
1;