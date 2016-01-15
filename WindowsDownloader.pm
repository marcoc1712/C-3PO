package Plugins::C3PO::WindowsDownloader;

# Windows specifc - check for *.exe and download from site if it not available in the Bin folder
# It runs every time plugin is updated, becouse it delete all the folder installing the new version.

use File::Spec::Functions qw(:ALL);
use Digest::MD5;
use Archive::Zip qw(:ERROR_CODES);
use Data::Dump qw(dump pp);

use Slim::Utils::Log;
use Slim::Utils::Prefs;

sub download {
	my $class  = shift;
	my $plugin = shift;
	
	my $log= $plugin->getLog();
	my %status=(); 
	
	my $bindir		= catdir($plugin->_pluginDataFor('basedir'), 'Bin', 'MSWin32-x86-multi-thread');
	my $zipUrl		= $plugin->_pluginDataFor('zipUrl');
	my $md5			= $plugin->_pluginDataFor('md5');
	my $files       = $plugin->_pluginDataFor('file');

	if (main::INFOLOG && $log->is_info) {

			 $log->info('Files: size: '.scalar(@files).' elements: ');
			 $log->info(dump(@files));
	}

	if (! -w $bindir) {
		
		$status->{'code'}=1;
		$status->{'message'}=("$bindir is not writable");
		
		$plugin->setWinExecutablesStatus($status);
		return 0;
	}

	my $cache = preferences('server')->get('cachedir');

	my $data = {
		bindir => $bindir,
		plugin => $plugin,
		zip    => catdir($cache, 'C-3PO.zip'),
		md5	   => $md5,
		files  => $files,
		remaining => 1,#set=2 to get md5 from file
	};
	
	$status->{'code'}=-1;
	$status->{'message'}=("downloading");
		
	$plugin->setWinExecutablesStatus($status);

	Slim::Networking::SimpleAsyncHTTP->new(\&_gotFile, \&_downloadError, { saveAs => $data->{'zip'}, data => $data } )->get($zipUrl);
	#Slim::Networking::SimpleAsyncHTTP->new(\&_gotMD5,  \&_downloadError, { data => $data } )->get($md5Url);
}

sub _gotFile {
	my $http = shift;
	
	my $data	= $http->params('data');
	my $plugin  = $data->{'plugin'};
	my $log		= $plugin->getLog();
	
	if (main::INFOLOG && $log->is_info) {

			 $log->info('_gotFile');
			 $log->info(dump($data));
	}
	
	if (! --$data->{'remaining'}) {
	
		$status->{'code'}=-2;
		$status->{'message'}=("extracting");
		
		$data->{'plugin'}->setWinExecutablesStatus($status);
	
		_extract($data);
	}
}
#to get md5 from file
sub _gotMD5 {
	my $http = shift;
	my $data = $http->params('data');

	($data->{'md5'}) = $http->content =~ /(\w+)\s/;

	if (! --$data->{'remaining'}) {
		_extract($data);
	}
}

sub _downloadError {
	my $http  = shift;
	my $error = shift;
	my $data = $http->params('data');
	my $plugin  = $data->{'plugin'};
	
	$status->{'code'}=2;
	$status->{'message'}=($http->url . " - " . $error);
		
	$plugin->setWinExecutablesStatus($status);
}

sub _extract {
	my $data	= shift;
	
	my $zipfile	= $data->{'zip'};
	my $plugin  = $data->{'plugin'};
	my @files   = @{$data->{'files'}};
	my $log		= $plugin->getLog();
	
	my $md5 = Digest::MD5->new;

	open my $fh, '<', $zipfile;

	binmode $fh;

	$md5->addfile($fh);

	close $fh;
		
	if ($data->{'md5'} ne $md5->hexdigest) {

		$status->{'code'}=3;
		$status->{'message'}=('bad md5 checksum');
		
		$plugin->setWinExecutablesStatus($status);
		return 0;
	}

	my $arch = Archive::Zip->new();

	if ($arch->read($zipfile) != AZ_OK) {

		$status->{'code'}=4;
		$status->{'message'}=("error reading zip file $file");
		
		$plugin->setWinExecutablesStatus($status);
		return 0;

	} 
	my $fileHash= ();
	for my $file (@files){
	
		if (main::INFOLOG && $log->is_info) {
				 $log->info('File: '.$file);
		}
		
		$fileHash->{$file}->{'found'}=0;

		my @inZip = $arch->membersMatching($file);	

		if ($arch->extractMember($inZip[0], catdir($data->{'bindir'}, $file)) != AZ_OK) {
			
			$status->{'code'}=5;
			$status->{'message'}=("error extracting $file from $dwl");

			$plugin->setWinExecutablesStatus($status);
			return 0;
		}
		$fileHash->{$file}->{'found'}=1;

	}
	
	for my $file (keys %$fileHash) {

		if (! $fileHash->{$file}->{'found'}){
			
			$status->{'code'}=6;
			$status->{'message'}=('one or more files missing');

			$plugin->setWinExecutablesStatus($status);
			return 0;
		}
		if (! Slim::Utils::Misc::findbin($file)) {
			
			$status->{'code'}=7;
			$status->{'message'}=("$file extracted but not found by findbin");

			$plugin->setWinExecutablesStatus($status);
			return 0;
		}
	}
	$status->{'code'}=0;
	$status->{'message'}=('download_ok');

	$plugin->setWinExecutablesStatus($status);
	unlink $zipfile;
	
	return 1;
}
1;
