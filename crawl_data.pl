use v5.24;
use warnings;

use DBIx::Simple;
use HTML::TreeBuilder;
use MIME::Base64;
use Mojo::UserAgent;
use utf8;
use WWW::Mechanize;

my $AN = 2017;
my $num_pages = 13552;
my ($start_page, $end_page) = (@ARGV);

sub get_name {
  my ($html) = @_;
  #say $html;
  $html =~ qr/LuatDePeBacalaureatEduRo\["([a-zA-Z <>\.\-\(\)]+)/;
  my ($surname, $firstname) = split '<br>', $1;
  return ($surname, $firstname);
}

# Converts characters to utf8
# Replaces spaces with undef
sub clean_hash {
  my ($hash) = @_;
  while (my ($key, $value) = each %$hash) {
    utf8::encode($hash->{$key});
    $hash->{$key} = undef unless $hash->{$key} =~ qr/[A-Za-z0-9]/;
  }
  $hash->{medie} = undef if $hash->{medie} =~ qr/[A-Za-z]/;

  if ($hash->{nota_materna} && !defined $hash->{nota_materna_final}) {
    $hash->{nota_materna_final} = $hash->{nota_materna};
  }

  if ($hash->{nota_romana} && !defined $hash->{nota_romana_final}) {
    $hash->{nota_romana_final} = $hash->{nota_romana};
  }

  if ($hash->{nota_obligatorie} && !defined $hash->{nota_obligatorie_final}) {
    $hash->{nota_obligatorie_final} = $hash->{nota_obligatorie};
  }

  if ($hash->{nota_alegere} && !defined $hash->{nota_alegere_final}) {
    $hash->{nota_alegere_final} = $hash->{nota_alegere};
  }
}

my $db = DBIx::Simple->connect('dbi:Pg:dbname=bac_stats')
    or die DBIx::Simple->error;

my %row;
sub parse_row {
  my ($tr) = @_;
  my @tds = $tr->look_down(_tag => 'td');

  if (scalar @tds == 22) {
    $row{id} = substr $tds[1]->as_text, 1;
    ($row{nume}, $row{prenume}) = get_name($tds[2]->as_HTML);
    $row{scoala} = substr $tds[5]->as_text, 1;
    $row{judet} = substr $tds[6]->as_text, 1;
    $row{promotie_anterioara} = substr $tds[7]->as_text, 1;
    $row{forma_invatamant} = substr $tds[8]->as_text, 1;
    $row{specializare} = substr $tds[9]->as_text, 1;
    $row{calificativ_competente_romana} = substr $tds[10]->as_text, 1;
    $row{nota_romana} = substr $tds[11]->as_text, 1;
    $row{nota_romana_contestatie} = substr $tds[12]->as_text, 1;
    $row{nota_romana_final} = substr $tds[13]->as_text, 1;
    $row{limba_materna} = substr $tds[14]->as_text, 1;
    $row{limba_moderna} = substr $tds[15]->as_text, 1;
    $row{nota_limba_moderna} = substr $tds[16]->as_text, 1;
    $row{disciplina_obligatorie} = substr $tds[17]->as_text, 1;
    $row{disciplina_alegere} = substr $tds[18]->as_text, 1;
    $row{competente_digitale} = substr $tds[19]->as_text, 1;
    $row{medie} = substr $tds[20]->as_text, 1;
    $tds[0]->as_HTML =~ /(REUSIT|RESPINS|NEPREZENTAT|ELIMINAT DIN EXAMEN)/;
    $row{rezultat_final} = $1;
    $tds[0]->as_HTML =~ /([0-9]?[0-9]\.[0-9][0-9])/;
    $row{medie} = $1;
  } elsif (scalar @tds == 10) {
    $row{calificativ_competente_materna} = substr $tds[0]->as_text, 1;
    $row{nota_materna} = substr $tds[1]->as_text, 1;
    $row{nota_materna_contestatie} = substr $tds[2]->as_text, 1;
    $row{nota_materna_final} = substr $tds[3]->as_text, 1;

    $row{nota_obligatorie} = substr $tds[4]->as_text, 1;
    $row{nota_obligatorie_contestatie} = substr $tds[5]->as_text, 1;
    $row{nota_obligatorie_final} = substr $tds[6]->as_text, 1;

    $row{nota_alegere} = substr $tds[7]->as_text, 1;
    $row{nota_alegere_contestatie} = substr $tds[8]->as_text, 1;
    $row{nota_alegere_final} = substr $tds[9]->as_text, 1;
    $row{an} = $AN;
    clean_hash(\%row);
    $db->iquery('INSERT INTO results', \%row);
    use Data::Dumper;
    undef %row;
  }
}

sub crawl_sync {
  my $mechanize = WWW::Mechanize->new(autocheck => 1);
  $mechanize->cookie_jar(HTTP::Cookies->new);
  my ($urls_ref) = @_;
  my @urls = @$urls_ref;
  for (my $i = 0; $i < scalar @urls; ++$i) {
    my $url = $urls[$i];
    say "Crawling $url";
    $mechanize->get($url);
    my $root = HTML::TreeBuilder->new_from_content($mechanize->content);
    my @trs;
    eval {
      my $table = $root->look_down(id => 'mainTable');
      #say $table->as_HTML;
      @trs = $table->look_down(_tag => 'tr', class => qr/tr[1|2]/);
    };
    if ($@) {
      say $@;
      --$i;
      next;
    }
    for my $tr (@trs) {
      parse_row($tr);
    }
  }
}

my @aux_urls;
sub crawl_async {
  my $ua = Mojo::UserAgent->new->with_roles('+Queued');
  $ua->max_redirects(3);
  $ua->max_active(5);

  my ($urls_ref) = @_;
  my @urls = @$urls_ref;
  my @p = map {
    my $url = $_;
    $ua->get_p($_)->then(sub {
      say "Crawling $url  ";
      my $content = pop->res->dom->to_string;
      if ($AN != 2017) {
        my $begin_pattern = 'function ged(){return "';
        my $start_pos = index($content, $begin_pattern) + length $begin_pattern;
        my $end_pos = index $content, '"', $start_pos;
        $content = substr $content, $start_pos, $end_pos - $start_pos + 1;
        $content =~ y/0O1l5Sms/O0l1S5sm/;
        $content =~ y/a-zA-Z/A-Za-z/;
        $content = decode_base64($content);
      }
      my $root = HTML::TreeBuilder->new_from_content($content);
      my $table = $root->look_down(id => 'mainTable');#->look_down(_tag => 'tbody');
      my @trs = $table->look_down(_tag => 'tr', class => qr/tr[1|2]/);
      for my $tr (@trs) {
        parse_row($tr);
      }
    })->catch(sub {
      say "Error: ", @_;
      push @aux_urls, $url;
    })
  } @urls;
 Mojo::Promise->all(@p)->wait;
}

my @urls;

for (my $page_idx = $start_page; $page_idx <= $end_page; ++$page_idx) {
  push @aux_urls, "http://static.bacalaureat.edu.ro/$AN/rapoarte/rezultate/" .
    "alfabetic/page_$page_idx.html";
}

# crawl_sync(\@urls);
while (scalar @aux_urls) {
  @urls = @aux_urls;
  @aux_urls = [];
  crawl_async(\@urls);
}
