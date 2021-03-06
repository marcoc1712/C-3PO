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
        $log->debug( $self->prettyPrintConversionCapabilities(1,"STATUS QUO ANTE: ") );
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
         $log->debug( $self->prettyPrintConversionCapabilities(1,"AFTER PROFILES DISABLING: "));
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
        
		#if (!$self->isProfileEnabled($profile)){next;}
        
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
        
      $log->debug( $self->prettyPrintConversionCapabilities(1,"AFTER RESTORE PROFILES : "));
	}
}
sub enableProfile{
    my $self = shift;
	my $profile = shift;
	my @out = ();
	
    my $found; 
    
	my @disabled = @{$self->get_disabledProfiles()};
	for my $format (@disabled) {

		if ($format eq $profile) {
            
            $found=1;
            next;
        }
        
		push @out, $format;
	}
    if ($found){
        
       	$serverPreferences->set('disabledformats', \@out);
        $serverPreferences->writeAll();
        $serverPreferences->savenow(); 
    }

}
sub getBinaries{
    my $self = shift;
    my $profile = shift;
    
    my %backup      = %Slim::Player::TranscodingHelper::binaries;
    %Slim::Player::TranscodingHelper::binaries=();
    my $binOK       = Slim::Player::TranscodingHelper::checkBin($profile,0);
    my %binaries    = %Slim::Player::TranscodingHelper::binaries;
    %Slim::Player::TranscodingHelper::binaries = %backup;
    
    return ($binOK, %binaries);
}

sub prettyPrintConversionCapabilities{
    my $self = shift;
    my $details = shift || 0;
    my $message = shift || "";
    my $client = shift || undef;

    my $out="";
    if ($message && !($message eq '')){
        
        $out="\n\n".$message."\n";
    }

    if (!$details){
    
        my $line = sprintf("%-5s %-5s %-30s %-20s %-20s\n", 'in', 'out', "[transcoder]", 'model', 'player');
        $out = $out."\n".$self->_getPrintConversionCapabilitiesHeader($details)."\n";
    }
    
    $out = $out.$self->_getPrintConversionCapabilitiesBody($details, $client)."\n";
    
    return $out;
}
sub getHtmlConversionTable {
    my $self = shift;
    my $details = shift || 0;
    my $client = shift || undef;
    
    my $out="";
    
    my $conversionTable =$self->_getConversionTable($client);
    my $prevInputtype="";
    
    if (!$details){
    
        $out=$out.'<tr>'.
                    '<td width="10%"><b>In</b></td>'.
                    '<td width="10%"><b>Out</b></td>'.
                    '<td width="40%"><b>[Transcoder]</b></td>'.
                    '<td width="20%"><b>Model</b></td>'.
                    '<td width="20%"><b>Player Id</b></td>'.
                   '</tr>'."\n";
    }
    
    for my $profile (sort keys %$conversionTable){
        
        my $inputtype           = $conversionTable->{$profile}->{'inputtype'};
        my $outputtype          = $conversionTable->{$profile}->{'outputtype'};
        my $command             = $conversionTable->{$profile}->{'command'};
        my $clienttype          = $conversionTable->{$profile}->{'clienttype'};
        my $clientid            = $conversionTable->{$profile}->{'clientid'};                
        my $enabled             = $conversionTable->{$profile}->{'enabled'};
        my $binOK               = $conversionTable->{$profile}->{'binOK'};
        my $bynaryString        = $conversionTable->{$profile}->{'bynaryString'};
        my $c3poString          = $conversionTable->{$profile}->{'c3poString'};
        my $capLine             = $conversionTable->{$profile}->{'capLine'};
        my $status              = $conversionTable->{$profile}->{'status'};
        my $transcoderString    = $conversionTable->{$profile}->{'transcoderString'};

        if ($details){

            my $line1= qq($inputtype $outputtype $clienttype $clientid $status);
            my $line2= qq(  $capLine);
            my $line3= qq(  $command);
        
            $out=$out.'<b>'.$line1.'</b>'.
                            '<p class="tab">'.$line2.'</p>'.
                            '<p class="tab">'.$line3.'</p>'.
                       '<p>&nbsp;</p>';
           
        } else{
            
            $out=$out.'<tr>';
            if ($prevInputtype eq $inputtype){
                
                $out=$out.'<td>'.''.'</td>';

            } else{
                
                $out=$out.'<tr>'.
                            '<td>'.'<p>&nbsp;</p>'.'</td>'.
                            '<td>'.'<p>&nbsp;</p>'.'</td>'.
                            '<td>'.'<p>&nbsp;</p>'.'</td>'.
                            '<td>'.'<p>&nbsp;</p>'.'</td>'.
                          '</tr>'."\n"; 
                  
                $out=$out.'<td><b>'.$inputtype.'</b></td>';
                $prevInputtype = $inputtype;
            }
            if (!$transcoderString){
                
                dump $conversionTable->{$profile};
            }
            $out=$out.'<td>'.$outputtype.'</td>'.
                            '<td>'.$transcoderString.'</td>'.
                            '<td>'.$clienttype.'</td>'.
                            '<td>'.$clientid.'</td>'.
                      '</tr>'."\n";
        }
    }
    return $out;
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
sub _getConversionTable{
    my $self = shift;
    my $client = shift || undef;
    
    my $conv    = $self->get_conversions();
    my $caps    = $self->get_capabilities();
    my %players = %{_getEnabledPlayers()};
    my %codecs  = %{$plugin->getPreferences()->get('codecs')};
    
    my %out=();

    for my $profile (sort keys %$conv){
    
        my ($inputtype, $outputtype, $clienttype, $clientid) = _inspectProfile($profile);

        if ($client ){
            
            if (!($clientid eq '*') && !($client->id() eq $clientid)) {next}
            if (!($clienttype eq '*') && !($client->model() eq $clienttype)) {next}
        }
        
        $out{$profile}{'inputtype'}     =$inputtype;
        $out{$profile}{'outputtype'}    =$outputtype;
        $out{$profile}{'clienttype'}    =$clienttype;
        $out{$profile}{'clientid'}      =$clientid;
        $out{$profile}{'command'}       =$conv->{$profile};
        
        my $enabled = $self->isProfileEnabled($profile);
        $out{$profile}{'enabled'} = $enabled;
         
        my ($binOK, %binaries) =$self->getBinaries($profile);
        $out{$profile}{'binOK'} = $binOK;
        $out{$profile}{'binaries'} = %binaries;
        
        my $bynaryString="[";
        my $separator="";
        
        for my $p (keys %binaries){
            
            $bynaryString = $bynaryString.$separator.$p;
            $separator= "|";
        }
        $bynaryString=$bynaryString."]";
        $out{$profile}{'bynaryString'} = $bynaryString;

        $out{$profile}{'c3po'} = ($players{$clientid} && $codecs{$inputtype});
        $out{$profile}{'c3poString'} = $out{$profile}{'c3po'} ? '[SET BY C-3PO PLUGIN]' : '';
        
        my %caps= %{$caps->{$profile}};
        $out{$profile}{'caps'}=  %caps;
        
        my $capLine="" ;
        $separator= "# ";
        for my $c (keys %caps){
            $capLine = $capLine.$separator.$c." ". $caps->{$profile}->{$c};
            $separator= ", ";
        }
        $out{$profile}{'capLine'}= $capLine;
        
        my $status = $enabled ? $binOK ? '' : '[UNAVAILABLE]' : '[DISABLED]';
        $out{$profile}{'status'}= $status;
        
        my $transcoderString = $status ? $status : $bynaryString eq '[]' ? '[Native]' : $bynaryString;
        $out{$profile}{'transcoderString'}= $transcoderString;
    }
    return \%out;
}
sub _getPrintConversionCapabilitiesHeader{
    my $self = shift;
    my $details = shift || 0;
    
    my $line="";
     
    if (!$details){
    
        $line = sprintf("%-5s %-5s %-30s %-20s %-20s\n", 'in', 'out', "[transcoder]", 'model', 'player');
       
    }
    return $line;
}
sub _getPrintConversionCapabilitiesBody{
    my $self = shift;
    my $details = shift || 0;
    my $client = shift || undef;
    
    my $out="";
    
    my $conversionTable =$self->_getConversionTable($client);
    my $prevInputtype="";
    for my $profile (sort keys %$conversionTable){
        
        my $inputtype           = $conversionTable->{$profile}->{'inputtype'};
        my $outputtype          = $conversionTable->{$profile}->{'outputtype'};
        my $command             = $conversionTable->{$profile}->{'command'};
        my $clienttype          = $conversionTable->{$profile}->{'clienttype'};
        my $clientid            = $conversionTable->{$profile}->{'clientid'};                
        my $enabled             = $conversionTable->{$profile}->{'enabled'};
        my $binOK               = $conversionTable->{$profile}->{'binOK'};
        my $bynaryString        = $conversionTable->{$profile}->{'bynaryString'};
        my $c3poString          = $conversionTable->{$profile}->{'c3poString'};
        my $capLine             = $conversionTable->{$profile}->{'capLine'};
        my $status              = $conversionTable->{$profile}->{'status'};
        my $transcoderString    = $conversionTable->{$profile}->{'transcoderString'};

        if ($details){

            my $line1= qq($inputtype $outputtype $clienttype $clientid $status);
            my $line2= qq(  $capLine);
            my $line3= qq(  $command);
        
            $out=$out.("\n".$line1."\n".$line2."\n".$line3."\n");
           
        } else{
            
            if ($prevInputtype eq $inputtype){
                
                my $line = sprintf("%-5s %-5s %-30s %-20s %-20s\n", "", $outputtype, $transcoderString, $clienttype, $clientid);
                $out = $out.$line;
                
            } else{
            
                my $line = sprintf("%-5s %-5s %-30s %-20s %-20s\n", $inputtype, $outputtype, $transcoderString, $clienttype, $clientid);
                $out = $out."\n".$line;
                $prevInputtype = $inputtype;
            }
        }
    }
    return $out;
}

1;