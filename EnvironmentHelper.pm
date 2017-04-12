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
package Plugins::C3PO::EnvironmentHelper;

use strict;
use warnings;

use File::Spec::Functions qw(:ALL);
use File::Basename;
use Data::Dump qw(dump pp);

my $class;
my $log;

my $soxVersion;
my $SoxFormats;
my $SoxEffects;
	
sub new {
    $class = shift;
	my $logger = shift;
	my $C3POfolder = shift;
	my $serverFolder = shift;
	
	if ($logger && $logger->{'log'}) {$log=$logger->{'log'};}
 
	my $self = bless {
		C3POfolder => $C3POfolder,
		serverFolder => $serverFolder,
    }, $class;
    
    $soxVersion =$self->_getSoxVersion();
	($SoxFormats, $SoxEffects) =$self->_getSoxDetails();
    
    return $self;
}
sub C3POfolder {
    my $self = shift;  
    return $self->{C3POfolder};
}
sub serverFolder {
    my $self = shift;  
    return $self->{serverFolder};
}
sub logFolder {
    my $self = shift;  
    return Slim::Utils::OSDetect::dirsFor('log');
}
sub pathToPrefFile{
    my $self = shift;  
    return catdir(Slim::Utils::OSDetect::dirsFor('prefs'), 'plugin', 'C3PO.prefs');
}
sub pathToPerl {
    my $self = shift;  
    return Slim::Utils::Misc::findbin("perl");
}
sub pathToC3PO_pl {
    my $self = shift;  
    return catdir($self->C3POfolder(), 'C-3PO.pl');
}
sub pathToC3PO_exe {
    my $self = shift;  
    return Slim::Utils::Misc::findbin("C-3PO");
}
sub pathToFlac {
    my $self = shift;  
    return Slim::Utils::Misc::findbin("flac");
}
sub pathToSox {
    my $self = shift;  
    return Slim::Utils::Misc::findbin("sox");
}
sub pathToFaad {
    my $self = shift;  
    return Slim::Utils::Misc::findbin("faad");
}
sub pathToFFmpeg {
    my $self = shift;  
    return Slim::Utils::Misc::findbin("ffmpeg");
}
sub pathToHeaderRestorer_pl {
    my $self = shift;  
    return catdir($self->C3POfolder(), 'HeaderRestorer.pl');
}
sub pathToHeaderRestorer_exe {
    my $self = shift;  
    return Slim::Utils::Misc::findbin("HeaderRestorer");
}
sub testC3POEXE{
	my $self = shift;  
	
	#test if C3PO.PL will start on LMS calls
	
	my $pathToC3PO_exe = $self->pathToC3PO_exe();
	my $logFolder = $self->logFolder();
	my $serverFolder = $self->serverFolder();
	
	if  (! $pathToC3PO_exe || ! (-e $pathToC3PO_exe)){
		#$log->warn('WARNING: wrong path to C-3PO.exe, will not start - '.$pathToC3PO_exe);
		return 0;
	}
		
	my $command= qq("$pathToC3PO_exe" -h hello -l "$logFolder" -x "$serverFolder");
	
	if (! (main::DEBUGLOG && $log->is_debug)) {
	
		$command = $command." --nodebuglog";
	}
	
	if (! (main::INFOLOG && $log->is_info)){
	
		$command = $command." --noinfolog";
	}
	
	$command= Plugins::C3PO::Shared::finalizeCommand($command);
	
	
	if (main::DEBUGLOG && $log->is_debug) {
			 $log->info("command: ".$command);
	}
	
	my $ret= `$command`;
	my $err=$?;
	
	if (!$err==0){
		$log->warn('WARNING: '.$err.$ret);
		return 0;}
	
	if (main::INFOLOG && $log->is_info) {
			 $log->info($ret);
	}
	return 1;
}
sub testC3POPL{
	my $self = shift;
	
	#test if C3PO.PL will start on LMS calls
	
	my $pathToPerl = $self->pathToPerl();
	my $pathToC3PO_pl = $self->pathToC3PO_pl();
	my $logFolder = $self->logFolder();
	my $serverFolder = $self->serverFolder();
	
	if  (!(-e $pathToPerl)){
		#$log->warn('WARNING: wrong path to perl, C-3PO.pl, will not start - '.$pathToPerl);
		return 0;
	}
	
	if  (!(-e $pathToC3PO_pl)){
		#$log->warn('WARNING: wrong path to C-3PO.pl, will not start - '.$pathToC3PO_pl);
		return 0;
	}

	my $command= qq("$pathToPerl" "$pathToC3PO_pl" -h hello -l "$logFolder" -x "$serverFolder");
	
	if (! main::DEBUGLOG || ! $log->is_debug) {
	
		$command = $command." --nodebuglog";
	}
	
	if (! main::INFOLOG || ! $log->is_info){
	
		$command = $command." --noinfolog";
	}
	$command= Plugins::C3PO::Shared::finalizeCommand($command);
	
	if (main::INFOLOG && $log->is_info) {
			 $log->info('command: '.$command);
	}
	
	my $ret= `$command`;
	my $err=$?;
	
	if (!$err==0){
		$log->warn('WARNING: '.$err.$ret);
		return 0;}
	
	if (main::INFOLOG && $log->is_info) {
			 $log->info($ret);
	}
	return 1;
}
sub soxVersion {
    my $self = shift;  
    return $soxVersion;
}
sub isFormatSupportedBySox{
	my $self = shift; 
	my $format =shift;
	
	if($format && exists($SoxFormats->{$format})) { return 1 }
	return 0;
}
sub isEffectSupportedBySox{
	my $self = shift; 
	my $effect =shift;
	
	if($effect && exists($SoxEffects->{$effect})) { return 1 }
	return 0;
}
sub isSoxDsdCapable{
	my $self = shift; 
	my $effect =shift;
	
	my $dsf = $self->isFormatSupportedBySox("dsf");
	my $dff = $self->isFormatSupportedBySox("dff");
	my $sdm = $self->isEffectSupportedBySox("sdm");
	
	if ($dsf && $dff && $sdm){
		return 1;
	}
	return 0;
}

sub soxInputFormats{
	my $self = shift;
	# should check the read format attribute in sox?
	return	$SoxFormats;

}

sub soxOutputFormats{
	my $self = shift;
	# should check the write format attribute in sox?
	return	$SoxFormats;
}
sub soxEffects{
	my $self = shift;
	
	return	$SoxEffects;
}

sub getC3POcommand{
    my $self    = shift;
    my $command = shift;
    
    $command= qq($command -d --nodebuglog  --noinfolog);
	$command= Plugins::C3PO::Shared::finalizeCommand($command);
	
	my $ret= `$command`;
	my $err=$?;
	
	if (!$err==0){
		$log->warn('WARNING: '.$err.$ret);
    
    }elsif (main::DEBUGLOG && $log->is_debug) {
			 $log->debug($ret);
	}
	return ($err, $ret);
    
}
####################################################################################################
# Private
#
sub _getSoxVersion{
	my $self = shift;  
	
	my $pathToSox = $self->pathToSox();
	
	if  (! $pathToSox || ! (-e $pathToSox)){
		$log->warn('WARNING: wrong path to SOX  - '.$pathToSox);
		return undef;
	}
	my $command= qq("$pathToSox" --version);
	$command= Plugins::C3PO::Shared::finalizeCommand($command);
	
	my $ret= `$command`;
	my $err=$?;
	
	if (!$err==0){
		$log->warn('WARNING: '.$err.' '.$ret);
		return undef;
	}
	
	my $i = index($ret, "SoX v");
	my $versionString= substr($ret,$i+5);
	
	my ($version, $extra) = Plugins::C3PO::Shared::unstringVersion($versionString,$log);
	
	if (main::INFOLOG && $log->is_info) {
		$log->info("Sox path  is: ".$pathToSox);
		$log->info("Sox version is: ".$version.($extra ? $extra : ''));
	}
	return $version;
}
sub _getSoxDetails{
	my $self = shift;  
	
	my $pathToSox = $self->pathToSox();
	
	if  (! $pathToSox || ! (-e $pathToSox)){
		$log->warn('WARNING: wrong path to SOX  - '.$pathToSox);
		return undef,undef;
	}
	my $command= qq("$pathToSox" --help);
	$command= Plugins::C3PO::Shared::finalizeCommand($command);
	
	my @ret= `$command`;
	my $err=$?;
	
	if (!$err==0){
		$log->warn('WARNING: '.$err);
		return undef,undef;
	}

	my $formatsHeader= "AUDIO FILE FORMATS: ";
	my $effectsHeader= "EFFECTS: ";

	my $formats="";
	my $effects="";

	foreach my $row (@ret) { 
		chomp ($row);

		#print $row."\n";;

		if (index($row, $formatsHeader)>-1){

			$formats= substr($row,index($row, $formatsHeader)+length($formatsHeader));

		} elsif (index($row, $effectsHeader)>-1) {

			$effects= substr($row,index($row, $effectsHeader)+length($effectsHeader));
		} 
	} 
	my %SoxFormats = map { $_ => 1 } split(/ /, $formats);
	my %SoxEffects = map { $_ => 1 } split(/ /, $effects);
	
	return (\%SoxFormats, \%SoxEffects);
}


1;