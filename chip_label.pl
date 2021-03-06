#!/usr/bin/perl
use strict;
use warnings;

use GD;
use Getopt::Long qw/:config auto_help gnu_getopt bundling/;
use Pod::Usage;
use List::Util qw/max min/;
use Data::Dumper;

use GdUtil qw/:all/;
use PTouch qw/pixels PIX_PER_MM/;
use YAML;

my $outfile;

# tape width in mm
my $tapewidth = 6;
my $pin_spacing = 2.54; # mm
my $offset = 1.0; # mm
my $force = 0;
my $all = 0;
my $chip;

GetOptions(
    "w=n" => \$tapewidth,  # width of tape
    "o=s" => \$outfile,
    "force" => \$force,
    "c=s" => \$chip,
    "a" => \$all,
    ) or die "invalid options";

my $yaml = YAML::LoadFile("chips.yaml") or die "couldn't read chips.yaml";
my $height = pixels($tapewidth);

sub genchip {
    my ($ch) = @_;

    my @pins = @{$yaml->{$ch}{pins}};
    my $name = $yaml->{$ch}{name} || $ch;
    return if defined $yaml->{$ch}{status} && 
        $yaml->{$ch}{status} eq 'disable';

    my $canvas = GD::Image->new(PIX_PER_MM*($offset*2 + $pin_spacing * (@pins/2 - 1)), $height);
    $canvas->useFontConfig(1);
    my $bg = $canvas->colorAllocate(255,255,255);
    my $fg = $canvas->colorAllocate(0,0,0);

# pin 0
    $canvas->filledRectangle(0,$height / 2 - 3, 2, $height / 2 + 3,$fg);
    $canvas->filledEllipse(2,$height / 2,7,7,$fg);

    my $nc = drawtext2($name, font => GD::Font->Tiny);
    my ($tw,$th) = $nc->getBounds();
    $canvas->copy($nc,11,($height - $th) / 2,0,0,$tw,$th);

    my $cx = $offset * PIX_PER_MM;
    for my $pl (1 .. @pins / 2) {
        my $pr = @pins - $pl + 1;

        sub dpin {
            my ($cx,$canvas,$pn,$lr) = @_;
            my $bar = $pn =~ s/^\///;
            my $t = drawtext2($pn, font => GD::Font->Tiny, overbar => $bar );
            $t = $t->copyRotate270();
            my ($tw,$th) = $t->getBounds();
            $canvas->copy($t,$cx - $tw / 2 ,$lr ? ($height - $th) : 0,0,0,$tw,$th);
        }

        dpin $cx,$canvas,$pins[$pl - 1],1;
        dpin $cx,$canvas,$pins[$pr - 1],0;

        $cx += $pin_spacing * PIX_PER_MM;
    }

    writepng($canvas , lc "out/$ch.png");
}

genchip($chip) if $chip;
if ($all) {
    genchip($_) foreach keys %$yaml;
}

__END__

=head1 SYNOPSIS

 Options:
   --help            brief help message
   -w n              specify tape width in mm
   -c chip           chip name as specified in chips.yaml
   -a                generate pngs for all chips in the file

output placed in out/ directory.
