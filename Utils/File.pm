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


package Utils::File;

use strict;

#use File::Spec::Functions;

sub getAncestor{
	my $folder=shift;
	my $lev=shift || 1;
	
	#print $folder."\n";
	
	my ($volume,$directories,$file) =
                       File::Spec->splitpath( $folder, 1 );
	
	my @dirs = File::Spec->splitdir( $directories );

	my $dirs= @dirs;

	@dirs= splice @dirs, 0, $lev*-1;

	return File::Spec->catfile($volume, File::Spec->catdir( @dirs ), $file);
}
sub getParentFolder{
	my $folder=shift;
	return getAncestor($folder,1);
}
1;