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
package Plugins::C3PO::CapabilityHelper;

use strict;
use warnings;

use Data::Dump qw(dump pp);

my $class;
my $log;

#
# codecs/formats supported or filtered.
#
my %supportedCodecs=();
$supportedCodecs{'wav'}{'supported'}=1;
$supportedCodecs{'wav'}{'defaultEnabled'}=1;
$supportedCodecs{'wav'}{'defaultEnableSeek'}=1;
$supportedCodecs{'wav'}{'defaultEnableStdin'}=0;
$supportedCodecs{'aif'}{'supported'}=1;
$supportedCodecs{'aif'}{'defaultEnabled'}=1;
$supportedCodecs{'aif'}{'defaultEnableSeek'}=0;
$supportedCodecs{'aif'}{'defaultEnableStdin'}=0;
$supportedCodecs{'flc'}{'supported'}=1;
$supportedCodecs{'flc'}{'defaultEnabled'}=1;
$supportedCodecs{'flc'}{'defaultEnableSeek'}=0;
$supportedCodecs{'flc'}{'defaultEnableStdin'}=1;
$supportedCodecs{'alc'}{'supported'}=1;
$supportedCodecs{'alc'}{'defaultEnabled'}=1;
$supportedCodecs{'alc'}{'defaultEnableSeek'}=0;
$supportedCodecs{'alc'}{'defaultEnableStdin'}=0;
$supportedCodecs{'loc'}{'unlisted'}=1;
$supportedCodecs{'pcm'}{'unlisted'}=1;
$supportedCodecs{'dff'}{'supported'}=1;
$supportedCodecs{'dff'}{'defaultEnabled'}=0;
$supportedCodecs{'dff'}{'defaultEnableSeek'}=0;
$supportedCodecs{'dff'}{'defaultEnableStdin'}=0;
$supportedCodecs{'dsf'}{'supported'}=1;
$supportedCodecs{'dsf'}{'defaultEnabled'}=0;
$supportedCodecs{'dsf'}{'defaultEnableSeek'}=0;
$supportedCodecs{'dsf'}{'defaultEnableStdin'}=0;
#
# samplerates
#
# List could be extended if and when some new player with higher capabilities 
# will be introduced, this is from squeezeplay.pm at 10/10/2015.
#
# my %pcm_sample_rates = (
#	  8000 => '5',
# 	 11025 => '0',
#	 12000 => '6',
#	 16000 => '7',
#	 22050 => '1',
#	 24000 => '8',
#	 32000 => '2',
#	 44100 => '3',
#	 48000 => '4',
#	 88200 => ':',
#	 96000 => '9',
#	176400 => ';',
#	192000 => '<',
#	352800 => '=',
#	384000 => '>',
#);
my %OrderedPcmSampleRates = (
	"a" => 8000,
	"b" => 11025,
	"c" => 12000,
	"d" => 16000,
	"e" => 22050,
	"f" => 24000,
	"g" => 32000,
	"h" => 44100,
	"i" => 48000,
	"l" => 88200,
	"m" => 96000,
	"n" => 176400,
	"o" => 192000,
	"p" => 352800,
	"q" => 384000,
	"r" => 705600,
	"s" => 768000,
);
my %OrderedDsdRates = (
	"x01" => 64,
	"x02" => 128,
	"x04" => 256,
	"x08" => 512,
	"x16" => 1024,
);

sub new {
    $class = shift;
	my $logger = shift;
	my $isSoxDsdCapable = shift;
	my $unlimitedDsdRate = shift;
	
	if ($logger && $logger->{'log'}) {$log=$logger->{'log'};}

	if (!$isSoxDsdCapable){
		$supportedCodecs{'dsf'}{'supported'}=0;
		$supportedCodecs{'dff'}{'supported'}=0;
	}
	if (main::DEBUGLOG && $log->is_debug) {
			$log->debug("unlimitedDsdRate  : ".dump($unlimitedDsdRate));
	}
	if (main::DEBUGLOG && $log->is_debug) {
			$log->debug("isSoxDsdCapable  : ".dump($isSoxDsdCapable));
			$log->debug("supported codecs  : ".dump(%supportedCodecs));
			$log->debug("unlimitedDsdRate  : ".dump($unlimitedDsdRate));
	}
	my $self = bless {
		codecs => \%supportedCodecs,
		samplerates => \%OrderedPcmSampleRates,
		dsdrates => \%OrderedDsdRates,
		unlimitedDsdRate => $unlimitedDsdRate,
    }, $class;
    
    $self->_init();
    return $self;
}
sub codecs {
    my $self = shift;  
    return $self->{codecs};
}
sub samplerates {
    my $self = shift;  
    return $self->{samplerates};
}
sub dsdrates {
    my $self = shift;  
    return $self->{dsdrates};
}
sub isDsdCapable{
	my $self = shift;  
	my $client = shift || die;
	
	my $formats = $self->clientSupportedFormats($client);
	
	return $formats->{'dff'} && $formats->{'dsf'} ? 1 : 0;
}
sub maxSupportedSamplerate{
	my $self = shift;  
	my $client = shift;
	
	return $client->maxSupportedSamplerate();
}
sub maxSupportedDsdRate{
	my $self = shift;  
	my $client = shift;
	
	if (!$self->isDsdCapable($client)){
		return 0;
	}
	if ($self->{unlimitedDsdRate}){
		
		return 1024;
	}
	
	my $dsd64Rate= 88200; # Native, DOP is double, could be handled?
    
	if ($self->maxSupportedSamplerate($client) >= $dsd64Rate*16){
		return 1024;
	}
	if ($self->maxSupportedSamplerate($client) >= $dsd64Rate*8){
		return 512;
	}
	if ($self->maxSupportedSamplerate($client) >= $dsd64Rate*4){
		return 256;
	}
	if ($self->maxSupportedSamplerate($client) >= $dsd64Rate*2){
		return 128;
	}
	if ($self->maxSupportedSamplerate($client) >= $dsd64Rate){
		return 64;
	}
    return 0;
}
sub defaultSampleRates{
	my $self = shift; 
	my $client=shift;
	
	my $capSamplerates=$self->samplerates();
	my $maxSupportedSamplerate= $self->maxSupportedSamplerate($client);
	
	return $self->_defaultRates($capSamplerates,$maxSupportedSamplerate);
}

sub defaultDsdRates{
	my $self = shift; 
	my $client=shift;

	my $capDsdrates=$self->dsdrates();
	my $maxSupportedDsdrate= $self->maxSupportedDsdRate($client);
	
	return $self->_defaultRates($capDsdrates,$maxSupportedDsdrate);
	
}
sub guessSampleRateList{
	my $self = shift;
	my $maxrate=shift || 44100;

	# $client only reports the max sample rate of the player, 
	# we here assume that ANY lower sample rate in the player 
	# pcm_sample_rates table is valid.
	#
	my $rates= $self->samplerates();
	
	return $self->_guessRateList($rates,$maxrate);
}
sub guessDsdRateList{
	my $self = shift;
	my $maxrate=shift || 0;

	# we here assume that ANY dsd rate  lower than $maxrate in the player 
	# dsd_rates table is valid.
	#
	my $rates= $self->dsdrates();
	
	return $self->_guessRateList($rates,$maxrate);
	
}
sub defaultCodecs{
	my $self = shift;
	if (main::DEBUGLOG && $log->is_debug) {
		$log->debug('defaultCodecs');	
	}
	
	my $codecs= $self->codecs();
	my $prefCodecs =();
	my $supported=();

	#add all the codecs supported by C-3PO.
	for my $codec (keys %$codecs) {
		$supported->{$codec} = $codecs->{$codec}->{'supported'};
	}
	#set default enabled and remove unlisted.
	for my $codec (keys %$supported){
		
		if (exists $codecs->{$codec}->{'unlisted'}){ next;}
		
		$prefCodecs->{$codec}=undef;
		
		if (exists $codecs->{$codec}->{'supported'}){

			$prefCodecs->{$codec}=$codecs->{$codec}->{'supported'} ? "on" :undef;;
		}	
	}
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->debug("Default codecs  : ".dump($prefCodecs));
	}
	return ($prefCodecs);
}
sub supportedCodecs{
	my $self = shift;
	
	my %out;

	for my $codec (keys %supportedCodecs){
		
		if (exists $supportedCodecs{$codec}{'unlisted'}){next;}
		
		$out{$codec}=0;
		
		if (exists $supportedCodecs{$codec}{'supported'}){

			$out{$codec}=$supportedCodecs{$codec}{'supported'};
		}	
	}
	
	if (main::DEBUGLOG && $log->is_debug) {
			$log->debug("supported codecs MAP : ".dump(\%supportedCodecs));
			$log->debug("supported codecs OUT : ".dump(\%out));
	}
	return \%out;
}

sub clientSupportedFormats{
	my $self = shift;
	my $client = shift;
    
    # my $supported= Slim::Player::CapabilitiesHelper::supportedFormats($client);
    my %formats = map { $_ => 1 } Slim::Player::CapabilitiesHelper::supportedFormats($client);
    
    if (exists $formats{'pcm'} && !exists $formats{'wav'}){
        $formats{'wav'} = $formats{'pcm'};
    }
    if (exists $formats{'aac'} && !exists $formats{'alac'}){
        $formats{'alac'} = $formats{'aac'};
    }
	return \%formats;
}
####################################################################################################
# Private
#
sub _init{
  my $self = shift;
	
}
sub _defaultRates{
	my $self = shift;
	my $capsRates=shift;
	my $maxSupportedRate=shift;

	my $prefRates =();

	for my $rate (keys %$capsRates){
		if ($capsRates->{$rate} <= $maxSupportedRate){
			$prefRates->{$rate} = 1;
		} else {
			$prefRates->{$rate} = 0;
		}
	}

	return $prefRates;
}
sub _guessRateList{
	my $self = shift;
	my $rates = shift;
	my $maxrate=shift || 0;
	
	
	my $rateList="";
	
	for my $k (sort(keys %$rates)){
		my $rate=$rates->{$k};

		if ($rate+1 > $maxrate+1) {next};
		
		if (length($rateList)>0) {
			$rateList=$rateList." "
		}
		$rateList=$rateList.$rate;
	}

	return $rateList;
}

1;