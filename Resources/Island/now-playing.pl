#!/usr/bin/perl
# Ayudante de música de Sintecla (spec «La isla» §4): carga NowPlaying.dylib dentro de /usr/bin/perl, que sí puede
# preguntar a MediaRemote, y le pasa el control. Uso: /usr/bin/perl now-playing.pl /ruta/NowPlaying.dylib
use strict;
use warnings;
use DynaLoader;

my $library = shift @ARGV or die "falta la ruta de NowPlaying.dylib\n";
my $handle = DynaLoader::dl_load_file($library, 0) or die DynaLoader::dl_error() . "\n";
my $symbol = DynaLoader::dl_find_symbol($handle, "sintecla_now_playing_run") or die "NowPlaying.dylib sin su función\n";
DynaLoader::dl_install_xsub("main::run", $symbol);
run();
