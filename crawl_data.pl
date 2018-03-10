use v5.24;
use warnings;

use DBIx::Simple;
use HTML::TreeBuilder;
use utf8;
use WWW::Mechanize;

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
    $hash->{$key} = undef if $hash->{$key} eq ' ' || $hash->{$key} eq '';
  }
  $hash->{medie} = undef if $hash->{medie} =~ qr/[A-Za-z]/;
}

my $db = DBIx::Simple->connect('dbi:Pg:dbname=bac_stats')
    or die DBIx::Simple->error;

my %row;
sub parse_row {
  my ($tr) = @_;
  my @tds = $tr->look_down(_tag => 'td');

  if (scalar @tds == 22) {
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
    use Data::Dumper;
    clean_hash(\%row);
    #say Dumper \%row;
    $db->iquery('INSERT INTO results', \%row);
    undef %row;
  }
}

my $mechanize = WWW::Mechanize->new(autocheck => 1);
$mechanize->cookie_jar(HTTP::Cookies->new);

my $num_pages = 13552;

# for my $page_idx (1..$num_pages) {
for my $page_idx (1..$num_pages) {
  say "Crawling page $page_idx";
  my $url = "http://static.bacalaureat.edu.ro/2017/rapoarte/rezultate/" .
    "alfabetic/page_$page_idx.html";

  $mechanize->get($url);
  my $root = HTML::TreeBuilder->new_from_content($mechanize->content);
  my $table = $root->look_down(id => 'mainTable');#->look_down(_tag => 'tbody');
  #say $table->as_HTML;
  for my $tr ($table->look_down(_tag => 'tr', class => qr/tr[1|2]/)) {
    parse_row($tr);
  }
}
