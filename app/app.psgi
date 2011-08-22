# 

use strict;
use warnings;
use lib qw(. app);

use IO::File;

use Plack::Request;
use Plack::Response;

use NTP2OPML;

use utf8;
use Encode ();

my $app = sub {
	my $req = Plack::Request->new(shift);
	
	my $msg = "";
	if( my $upload = $req->upload('txt') ){
		# convert
		my $fh = IO::File->new( $upload->path );
		my $content = do { local $/; <$fh> };
		$fh->close;
		
		# looks like ntp2 format?
		if( $content =~ /^>>NTP2\-{2,}/o ){
			my $o = NTP2OPML->new;
			$o->content( $content );
			
			my $file_name = sprintf "output_%d.opml", time;
			
			my $res = Plack::Response->new(200);
			$res->content_type("text/xml");
			$res->headers( [ 'Content-Disposition' => sprintf q|attachment; filename=%s|, $file_name ] );
			if( $req->user_agent =~ /MSIE/io ){
				$res->content_type( sprintf q|application/x-download; name=%s|, $file_name );
			}
			else{
				$res->content_type( sprintf q|application/octet-stream; name=%s|, $file_name );
			}
			$res->body( Encode::encode_utf8( $o->opml ) );
			return $res->finalize;
		}
		else{
			$msg = q{<p>NTP2 形式のテキストではないようです。</p>};
		}
	}

	# form
	my $res = Plack::Response->new(200);
	$res->content_type("text/html; charset=utf-8");
	$res->body( Encode::encode_utf8(<<"END") );
<!DOCTYPE html>
<html lang="ja">
	<head>
		<meta charset="UTF-8">
		<title>ntp2 -&gt; opml</title>
	</head>
	<body>
		<h1>NTP2 format text to OPML converter</h1>
		<p>
			NTP2 形式のテキストファイルを、OPML に変換します。
		</p>
		<form action="" method="post" enctype="multipart/form-data">
			<input type="file" name="txt">
			$msg
			<br>
			<input type="submit" value="変換">
		</form>
		<ul>
			<li>指定するファイルの文字コードは Shift_JIS で、改行コードは任意（デフォルトは CR）です。</li>
			<li>出力される OPML ファイルの文字コードは UTF-8 で、改行コードは LF です。</li>
			<li>ソースコードも<a href="https://github.com/ryochin/ntp2opml" target="_blank">公開されています</a>。
		</ul>
	</body>
</html>
END
	return $res->finalize;
};

__END__

