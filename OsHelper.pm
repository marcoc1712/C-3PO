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
#
package Plugins::C3PO::OsHelper;

use strict;

sub getFatalDir{
	
	my $dir;
	if (main::ISWINDOWS || main::ISMAC){

		#require File::HomeDir;

		$dir = File::HomeDir->my_home;

	} else {

		#some sort of linux, in UBUNTU we could not write in the home dir...
		$dir= "/var/log";
	}
	return $dir;
}

sub getTemporaryDir{

	return File::Spec->tmpdir();

}
sub getTemporaryFile{
	my $name=shift;
	
	my $filename = "C3".time.$name;
	
	my $dir=getTemporaryDir();
	my $outfile = File::Spec->catdir($dir, $filename);
	
	unlink $outfile; 
	return $outfile;
}
1;