#!./perl -Tw

BEGIN {
	chdir 't' if -d 't';
	@INC = '../lib';
}

BEGIN {
	1 while unlink 'ecmdfile';
	# forcibly remove ecmddir/temp2, but don't import mkpath
	use File::Path ();
	File::Path::rmtree( 'ecmddir' );
}

BEGIN {
	use Test::More tests => 21;
	use File::Spec;
}

{
	use vars qw( *CORE::GLOBAL::exit );

	# bad neighbor, but test_f() uses exit()
	*CORE::GLOBAL::exit = sub { return @_ };

	use_ok( 'ExtUtils::Command' );

	# get a file in the current directory, replace last char with wildcard 
	my $file;
	{
		local *DIR;
		opendir(DIR, File::Spec->curdir());
		while ($file = readdir(DIR)) {
			$file =~ s/\.\z// if $^O eq 'VMS';
			last if $file =~ /^\w/;
		}
	}

	# this should find the file
	($ARGV[0] = $file) =~ s/.\z/\?/;
	ExtUtils::Command::expand_wildcards();

	is( scalar @ARGV, 1, 'found one file' );
	like( $ARGV[0], qr/$file/, 'expanded wildcard ? successfully' );

	# try it with the asterisk now
	($ARGV[0] = $file) =~ s/.{3}\z/\*/;
	ExtUtils::Command::expand_wildcards();

	ok( (grep { qr/$file/ } @ARGV), 'expanded wildcard * successfully' );

	# concatenate this file with itself
	# be extra careful the regex doesn't match itself
	my $out = tie *STDOUT, 'TieOut';
	my $self = $0;
	unless (-f $self) {
	    my ($vol, $dirs, $file) = File::Spec->splitpath($self);
	    my @dirs = File::Spec->splitdir($dirs);
	    unshift(@dirs, File::Spec->updir);
	    $dirs = File::Spec->catdir(@dirs);
	    $self = File::Spec->catpath($vol, $dirs, $file);
	}
	@ARGV = ($self, $self);

	cat();
	is( scalar( $$out =~ s/use_ok\( 'ExtUtils::Command'//g), 2, 
		'concatenation worked' );

	# the truth value here is reversed -- Perl true is C false
	@ARGV = ( 'ecmdfile' );
	ok( test_f(), 'testing non-existent file' );

	@ARGV = ( 'ecmdfile' );
	cmp_ok( ! test_f(), '==', (-f 'ecmdfile'), 'testing non-existent file' );

	# these are destructive, have to keep setting @ARGV
	@ARGV = ( 'ecmdfile' );
	touch();

	@ARGV = ( 'ecmdfile' );
	ok( test_f(), 'now creating that file' );

	@ARGV = ( 'ecmdfile' );
	ok( -e $ARGV[0], 'created!' );

	my ($now) = time;
	utime ($now, $now, $ARGV[0]);
    sleep 2;

	# Just checking modify time stamp, access time stamp is set
	# to the beginning of the day in Win95.
    # There's a small chance of a 1 second flutter here.
    my $stamp = (stat($ARGV[0]))[9];
	ok( abs($now - $stamp) <= 1, 'checking modify time stamp' ) ||
      print "# mtime == $stamp, should be $now\n";

	# change a file to read-only
	@ARGV = ( 0600, 'ecmdfile' );
	ExtUtils::Command::chmod();

	is( ((stat('ecmdfile'))[2] & 07777) & 0700, 0600, 'change a file to read-only' );

	# mkpath
	@ARGV = ( File::Spec->join( 'ecmddir', 'temp2' ) );
	ok( ! -e $ARGV[0], 'temp directory not there yet' );

	mkpath();
	ok( -e $ARGV[0], 'temp directory created' );

	# copy a file to a nested subdirectory
	unshift @ARGV, 'ecmdfile';
	cp();

	ok( -e File::Spec->join( 'ecmddir', 'temp2', 'ecmdfile' ), 'copied okay' );

	# cp should croak if destination isn't directory (not a great warning)
	@ARGV = ( 'ecmdfile' ) x 3;
	eval { cp() };

	like( $@, qr/Too many arguments/, 'cp croaks on error' );

	# move a file to a subdirectory
	@ARGV = ( 'ecmdfile', 'ecmddir' );
	mv();

	ok( ! -e 'ecmdfile', 'moved file away' );
	ok( -e File::Spec->join( 'ecmddir', 'ecmdfile' ), 'file in new location' );

	# mv should also croak with the same wacky warning
	@ARGV = ( 'ecmdfile' ) x 3;

	eval { mv() };
	like( $@, qr/Too many arguments/, 'mv croaks on error' );

	# remove some files
	my @files = @ARGV = ( File::Spec->catfile( 'ecmddir', 'ecmdfile' ),
	File::Spec->catfile( 'ecmddir', 'temp2', 'ecmdfile' ) );
	rm_f();

	ok( ! -e $_, "removed $_ successfully" ) for (@ARGV);

	# rm_f dir
	@ARGV = my $dir = File::Spec->catfile( 'ecmddir' );
	rm_rf();
	ok( ! -e $dir, "removed $dir successfully" );
}

END {
	1 while unlink 'ecmdfile';
	File::Path::rmtree( 'ecmddir' );
}

package TieOut;

sub TIEHANDLE {
	bless( \(my $text), $_[0] );
}

sub PRINT {
	${ $_[0] } .= join($/, @_);
}
