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

package Utils::Config;

use strict;

use Config;
#use Data::Dump;
#use File::Spec::Functions qw(:ALL);

sub expandINC{
	my $libPath = shift;

	my $arch= getArchName();
	my $perlmajorversion = getPerlMajorVersion();
	   
	#Data::Dump::dump ($arch, $perlmajorversion);
	
	my @newINC = (
		
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$perlmajorversion, $arch)),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$perlmajorversion, $arch, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$arch)),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$arch, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$Config{'version'}, $Config::Config{'archname'})),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$Config{'version'}, $Config::Config{'archname'}, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$perlmajorversion, $Config::Config{'archname'})),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$perlmajorversion, $Config::Config{'archname'}, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$Config::Config{'archname'})),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$Config::Config{'archname'}, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$Config{'version'})),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$Config{'version'}, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$perlmajorversion)),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','arch',$perlmajorversion, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib')), 
		File::Spec->canonpath(File::Spec->catdir($libPath,'lib','auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$perlmajorversion, $arch)),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$perlmajorversion, $arch, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$arch)),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$arch, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$Config{'version'}, $Config::Config{'archname'})),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$Config{'version'}, $Config::Config{'archname'}, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$perlmajorversion, $Config::Config{'archname'})),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$perlmajorversion, $Config::Config{'archname'}, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$Config::Config{'archname'})),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$Config::Config{'archname'}, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$Config{'version'})),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$Config{'version'}, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$perlmajorversion)),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','arch',$perlmajorversion, 'auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN')), 
		File::Spec->canonpath(File::Spec->catdir($libPath,'CPAN','auto')),
		File::Spec->canonpath(File::Spec->catdir($libPath)),
	);
	my @out=();
	for my $p (@newINC){
		
		if (-e $p){
			unshift @INC, $p;
		}
	}
	return @out;
}

sub getPerlMajorVersion{

	my $perlmajorversion = $Config{'version'};
	   $perlmajorversion =~ s/\.\d+$//;
	
	return $perlmajorversion;
}
sub getArchName{

	my $arch = $Config::Config{'archname'};
	
	#Data::Dump::dump($arch);
	
	# NB: The user may be on a platform who's perl reports a
	# different x86 version than we've supplied - but it may work
	# anyways.
	
	   $arch =~ s/^i[3456]86-/i386-/;
	   $arch =~ s/gnu-//;
	
	# Check for use64bitint Perls
	my $is64bitint = $arch =~ /64int/;
	
	# Some ARM platforms use different arch strings, just assume any arm*linux system
	# can run our binaries, this will fail for some people running invalid versions of Perl
	# but that's OK, they'd be broken anyway.
	if ( $arch =~ /^arm.*linux/ ) {
		$arch = $arch =~ /gnueabihf/ 
			? 'arm-linux-gnueabihf-thread-multi' 
			: 'arm-linux-gnueabi-thread-multi';
		$arch .= '-64int' if $is64bitint;
	}
	
	# Same thing with PPC
	if ( $arch =~ /^(?:ppc|powerpc).*linux/ ) {
		$arch = 'powerpc-linux-thread-multi';
		$arch .= '-64int' if $is64bitint;
	}
	
	return $arch;
}
1;