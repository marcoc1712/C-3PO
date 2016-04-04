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

package Utils::Log;

use strict;	
use Carp qw<longmess>;
use Data::Dumper;
	
#use File::Spec::Functions qw(:ALL);
#print ( (caller(1))[3] )."\n";
#print "\n";

sub evalLog{
	my $logLevel= shift;
	my $msgLevel= shift;
	
	my $level={
		'verbose'	=> 0,
		'debug'		=> 1,
		'info'		=> 3,
		'warn'		=> 5,
		'error'		=> 7,
		'trace'		=> 8,
		'die'		=> 9,
	};
	
	if ($level->{$logLevel} > $level->{$msgLevel}){
		
		return 0;
	}
	return 1;
}

sub writeLog {
	my $logfile=shift;
	my $msg = shift;
	my $isDebug = shift;
	my $logLevel = shift || 'warn';
	my $msgLevel= shift || 'warn';
	
	my $now = localtime;
	my $line = qq([$now] $msg);
	
	if (evalLog($logLevel, $msgLevel)){
                
                
		if (open(my $fh, ">>", qq($logfile))){
                
			print $fh "$line \n";
			close $fh;

		} else{
		
			warn "$line \n";
		   #die ("can't write logFile ".qq($logfile));
		   #do nothing at the moment.

		   #TODO: Beter handle logs.

		}

		if ($isDebug){

			print $line."\n";
		}  
	}
}
sub dieMessage{
	my $logfile=shift;
	my $msg=shift;
	my $isDebug = shift;
	my $logLevel = shift|| 'warn';
	
	writeLog($logfile, qq(ERROR: $msg),$isDebug,$logLevel,'die');
	die ($msg);
}
sub errorMessage{
	my $logfile=shift;
	my $msg=shift;
	my $isDebug = shift;
	my $logLevel = shift|| 'warn';
	
	writeLog($logfile, qq(ERROR: $msg),$isDebug,$logLevel, 'error');
}
sub warnMessage{
	my $logfile=shift;
	my $msg=shift;
	my $isDebug = shift;
	my $logLevel = shift|| 'warn';
	
	writeLog($logfile, qq(WARNING: $msg),$isDebug,$logLevel, 'warn');
}
sub infoMessage{
	my $logfile=shift;
	my $msg=shift;
	my $isDebug = shift;
	my $logLevel = shift|| 'warn';
	
	writeLog($logfile, qq(INFO: $msg),$isDebug,$logLevel, 'info');
}
sub debugMessage{
	my $logfile=shift;
	my $msg=shift;
	my $isDebug = shift;
	my $logLevel = shift|| 'warn';
	
	writeLog($logfile, qq(DEBUG: $msg),$isDebug,$logLevel, 'debug');
}
sub verboseMessage{
	my $logfile=shift;
	my $msg=shift;
	my $isDebug = shift;
	my $logLevel = shift|| 'warn';
	
	writeLog($logfile, qq(VERBOSE: $msg),$isDebug,$logLevel, 'verbose');
}
sub traceMessage{
	my $logfile=shift;
	my $msg=shift;
	my $isDebug = shift;
	my $logLevel = shift|| 'warn';
	
	my $trace = Dumper longmess();
	
	writeLog($logfile, qq(TRACE: $msg)."\n".$trace,$isDebug,$logLevel, 'trace');
}

1;