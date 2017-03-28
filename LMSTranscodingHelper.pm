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
package Plugins::C3PO::LMSTranscodingHelper;

use strict;
use warnings;

use Data::Dump qw(dump pp);

use Slim::Utils::Prefs;
use Slim::Player::TranscodingHelper;

my $class;
my $plugin;
my $log;
my $serverPreferences;

# store values before preferences change.
my %previousCodecs=();
my %previousenabled=();

sub new {
    $class = shift;
	$plugin = shift;
	
    my $logger = $plugin->getLogger();
	if ($logger && $logger->{'log'}) {$log=$logger->{'log'}};
    
    $serverPreferences = $plugin->getServerPreferences();
    
    my %conv = %{Slim::Player::TranscodingHelper::Conversions()};
    my %caps = %Slim::Player::TranscodingHelper::capabilities;
    my @disabled = @{$serverPreferences->get('disabledformats')};

	my $self = bless {
	_StoredConversions      => \%conv,
    _StoredCapabilities     => \%caps,
    _StoredDisabledProfiles => \@disabled,
     
    }, $class;

    return $self;
}
sub get_disabledProfiles{
    my $self = shift;
    
    return $serverPreferences->get('disabledformats');
}
sub get_conversions{
    my $self = shift;
    
    return Slim::Player::TranscodingHelper::Conversions();
}
sub get_capabilities{
    my $self = shift;

    return \%Slim::Player::TranscodingHelper::capabilities;
}
sub isProfileEnabled{
    my $self = shift;
    my $profile = shift;
    
    return Slim::Player::TranscodingHelper::enabledFormat($profile);
}
sub prettyPrintConversionCapabilities{
    my $self = shift;
    my $message = shift || "";
    my $client = shift || undef;
    
    my $conv    = $self->get_conversions();
    my $caps    = $self->get_capabilities();
    my %players = %{_getEnabledPlayers()};
    my %codecs  = %{$plugin->getPreferences()->get('codecs')};
    
    my $out="\n\n".$message."\n";
    
    for my $profile (sort keys %$conv){
        
        my ($inputtype, $outputtype, $clienttype, $clientid) = _inspectProfile($profile);
        
        if ($client ){
            
            if (!($clientid eq '*') && !($client->id() eq $clientid)) {next}
            if (!($clienttype eq '*') && !($client->model() eq $clienttype)) {next}
        }
                
        my $enabled = $self->isProfileEnabled($profile) ? "" : "DISABLED";
        my $c3po= ($players{$clientid} && $codecs{$inputtype}) ? "SET BY C-3PO PLUGIN" : "";

        my $capLine="" ;
        my $separator= "# ";
        
        for my $c (keys $caps->{$profile}){
            
            $capLine = $capLine.$separator.$c." ". $caps->{$profile}->{$c};
            $separator= ", ";
        }
        
        my $line1= qq($inputtype $outputtype $clienttype $clientid $enabled $c3po);
        my $line2= qq(  $capLine);
        my $line3= qq(  $conv->{$profile});
        
        $out=$out.("\n".$line1."\n".$line2."\n".$line3."\n");
    }
    $out=$out."\n";
    return $out;
}

sub disableProfiles{
    my $self = shift;
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

	my %newCodecs = %{$plugin->getPreferences()->get('codecs')};
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
	
	my $conv = $self->get_conversions();

	if (main::DEBUGLOG && $log->is_debug) {
        $log->debug( $self->prettyPrintConversionCapabilities("STATUS QUO ANTE: ") );
	}
    
	for my $profile (keys %$conv){
        
		#flc-pcm-squeezelite-*
		#flc-pcm-*-00:04:20:12:b3:17
		#aac-aac-*-*
		
		my ($inputtype, $outputtype, $clienttype, $clientid) = _inspectProfile($profile);
		
		if ($codecs{$inputtype} && (($players{$clientid}) || ($clientid eq "*"))){
		
			if (main::DEBUGLOG && $log->is_debug) {		
				$log->debug("disable: ". $profile);
			}
			
			#_disableProfile($profile); will store the profile as disabled, not necessary.

			delete $Slim::Player::TranscodingHelper::commandTable{ $profile };
			delete $Slim::Player::TranscodingHelper::capabilities{ $profile };

		}
	}

    if (main::DEBUGLOG && $log->is_debug) {	
         $log->debug( $self->prettyPrintConversionCapabilities("AFTER PROFILES DISABLING: "));
	}
    
	%previousCodecs	 = %newCodecs;
	%previousenabled = %newEnabled;
}
sub restoreProfiles{
    my $self = shift;
    my $client = shift;
    
    my $inType    = $client ? $client->model() : undef;
	my $inId      = $client ? $client->id() : undef;
    
    my %codecs = %{$plugin->getPreferences()->get('codecs')};
    
    my $stored  = $self->{_StoredConversions};
    my $current = $self->get_conversions();
    
    for my $profile (keys %$stored){
    
        #flc-pcm-squeezelite-*
		#flc-pcm-*-00:04:20:12:b3:17
		#aac-aac-*-*
        
		if (!$self->isProfileEnabled($profile)){next;}
        
		my ($inputtype, $outputtype, $clienttype, $clientid) = _inspectProfile($profile);

        if (!($clientid eq '*')){next;}
        if (!$codecs{$inputtype}){next;}
        if (!($clienttype eq '*') && !($clienttype eq $inType)){next;}

        if ($clienttype eq '*'){
            
            my $newProfile= $inputtype.'-'.$outputtype.'-'.$inType.'-*';

            if ($stored->{$newProfile}){next;}
            if ($current->{$newProfile}){next;}

        } else {
            
            my $newProfile= $inputtype.'-'.$outputtype.'-'.$clienttype.'-*';
            if ($current->{$newProfile}){next;}
        }

        my $newProfile= $inputtype.'-'.$outputtype.'-'.$inType.'-'.$inId;

        if ($current->{$newProfile}){next;}
        
        $newProfile= $inputtype.'-'.$outputtype.'-*-'.$inId;

        if ($current->{$newProfile}){next;}
        
        $Slim::Player::TranscodingHelper::commandTable{ $newProfile } = $stored->{$profile};
		$Slim::Player::TranscodingHelper::capabilities{ $newProfile } = $self->{_StoredCapabilities}->{ $profile };
    }
    if (main::DEBUGLOG && $log->is_debug) {	
        
      $log->debug( $self->prettyPrintConversionCapabilities("AFTER RESTORE PROFILES : "));
	}
}
sub enableProfile{
    my $self = shift;
	my $profile = shift;
	my @out = ();
	
	my @disabled = @{$self->get_disabledProfiles()};
	for my $format (@disabled) {

		if ($format eq $profile) {next;}
		push @out, $format;
	}
	$serverPreferences->set('disabledformats', \@out);
	$serverPreferences->writeAll();
	$serverPreferences->savenow();
}

####################################################################################################
# Private
#

sub _getEnabledPlayers{
	my @clientList= Slim::Player::Client::clients();
	my %enabled=();
	
	for my $client (@clientList){
		
		my $prefs= $plugin->getPreferences($client);
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
1;