package NTP2OPML;

use Any::Moose;

use utf8;
use Encode ();

has 'content' => ( is => 'rw', isa => 'Str' );
has 'logic' => ( is => 'rw', isa => 'ArrayRef', default => sub { +[] } );

sub parse {
	my $self = shift;
	
	# preprocess
	do {
		my $content = Encode::decode('shift-jis', $self->content );
		
		$content =~ tr/\r\n/\n/;
		$content =~ tr/\r/\n/;
		
		$self->content( $content );
	};
	
	# set mode
	for( split "\n", $self->content ){
		my $mode;
		if( /^>>NOTE\-{40,}/o ){
			$mode = 'note';
		}
		elsif( /^>>GROUP\={40,}/o ){
			$mode = 'group';
		}
		elsif( /^>>GROUPEND\-{30,}/o ){
			$mode = 'groupend';
		}
		
		push @{ $self->logic }, { mode => $mode } if $mode;
	}
	
	# set depth
	do {
		my $depth = 0;
		my $prev = '';
		my @stack;
		for my $data( @{ $self->logic } ){
			if( $data->{mode} eq 'note' ){
				$data->{depth} = $depth;
				
				if( $prev eq 'group' ){
					push @stack, 1;
				}
			}
			elsif( $data->{mode} eq 'group' ){
				$data->{depth} = $depth;
				$depth++;
				
			}
			elsif( $data->{mode} eq 'groupend' ){
				$depth--;
				$data->{depth} = $depth;
				
				if( $prev eq 'note' ){
					pop @stack;
				}
			}
		}
	};
	
	my $content = $self->content;
	$content =~ s@\n>>\-{30,}\n@\n@goms;
	
	# note
	do {
		my $note = [ grep { $_->{mode} eq 'note' } @{ $self->logic } ];
		my $cnt = 0;
		( my $str = $content ) =~ s!>>NOTE\-{30,}\n\Qタイトル\E:(.*?)\n(.*?)\n*(?=>>)!
			my ($title, $content) = ($1, $2);
			$title =~ s/\n+$//o;
			$content =~ s/\n+$//o;
			my $hash = $note->[$cnt++];
			$hash->{title} = $title;
			$hash->{content} = $content;
		!goesm;
	};
	
	# group
	do {
		my $group = [ grep { $_->{mode} eq 'group' } @{ $self->logic } ];
		my $cnt = 0;
		( my $str = $content ) =~ s!>>GROUP\={30,}\n\Qグループ\E:(.*?)(\n)!
			my $title= $1;
			$title =~ s/\n+$//o;
			my $hash = $group->[$cnt++];
			$hash->{title} = $title;
		!goesm;
	};
	
	# cleanup
	for my $data( @{ $self->logic } ){
		if( $data->{mode} eq 'note' ){
			$data->{title} = q/（タイトル無し）/ if $data->{title} eq '';
			$data->{content} = "" if $data->{content} eq '';
		}
	}
}

sub opml {
	my $self = shift;
	
	$self->parse;
	
	my @opml;
	my @stack = ();
	
	my $add_padding = sub {
		my $n = shift // 0;
		return sprintf "%s%s", "\t\t", "\t" x $n;
	};
	
	for my $cnt( 0 .. $#{ $self->logic } ){
		my $data = $self->logic->[$cnt];
		my $depth = $data->{depth};
		
		# end tag
		while( scalar @stack > $depth ){
			pop @stack;
			push @opml, sprintf "%s</outline>", $add_padding->(scalar @stack);
		}
		
		# start tag
		while( scalar @stack < $depth ){
			push @stack, 1;
		}
		
		# ul の処理をしてから next すること。最後の行できちんと閉じるため
		next if $data->{mode} eq 'groupend';
		
		my $title = '';
		my $content = $self->escape_html( $data->{content} );
		if( $data->{mode} eq 'note' ){
			$title = $self->escape_html( $data->{title} );
			push @opml, sprintf q|%s<outline text="%s" _note="%s" />|, $add_padding->( $depth ), $title, $content;
		}
		elsif( $data->{mode} eq 'group' ){
			$title = sprintf "%s", $self->escape_html( $data->{title} );
			push @stack, 1;
			push @opml, sprintf q|%s<outline text="%s">|, $add_padding->( $depth ), $title;
		}
	}
	
	my $opml = join "\n", map { s/\n/&#10;/go; $_ } @opml;
	
	return <<"END";
<?xml version="1.0" encoding="utf-8"?>
<opml version="1.1">
	<head>
		<title>no title</title>
		<dateCreated>@{[ scalar localtime ]}</dateCreated>
		<expansionState></expansionState>
		<vertScrollState></vertScrollState>
	</head>
	<body>
$opml
	</body>
</opml>
END
}

sub escape_html {
	my $self = shift;
	my $str = shift // "";
	
	$str =~ s{&}{&amp;}gso;
	$str =~ s{<}{&lt;}gso;
	$str =~ s{>}{&gt;}gso;
	$str =~ s{"}{&quot;}gso;    # "
	
	return $str;
}

1;

__END__
