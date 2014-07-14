package Namer;

use strict;
use warnings;

sub genname {
    my $syls = shift;
    $syls = defined $syls ? "$syls" : 'c';
    my @pa = qw( a i u e o ka ki ku ke ko sa shi su se so ta ti tu te to n na ni nu ne no m ma mi mu me mo ya yu yo ra ri ru re ro wa wi we wo ga gi gu ge go da di du de do cha chi chu che cho ba bi bu be bo ja ji ju je jo pa pi pu pe po kya kyu kyo sha shu sho vu );
    my @pb = qw( ba be bi bo bu ca ce ci co cu cha che chi cho chu da de di do du  fa fe fi fo fu ga ge gi go gu ha he hi ho hu ja je ji jo ju ka ke ki ko ku la le li lo lu ma me mi mo mu na ne ni no nu pa pe pi po pu ra re ri ro ru sa se si so su sha she shi sho shu ta te ti to tu va ve vi vo vu wa we wi wo wu ya ye yi yo yu za ze zi zo zu );
    my @pc = qw( war long stone ren still min gar dry win gan stan ol bon bone tin kon dar may small hon le lan bay bow blow  bare sign bel sky mer van pan un lun don yun yon ton tan red bed in on an pur per par bur hon hil sil mil fil ful yor tor gol gil far lor lon tar );
    my @pc2 =  qw( field shore way pole well pin shell flow elm pine finth pod oak flame shoe sow mount fast rock run farm fan cor cen cer shoal mait set pul fir fur for lon lun or heel hole haul hall hail don );
    my @parts;
    my @parts2;
    for ($syls) {
        if (/a/) { @parts = @pa; }
        elsif (/b/) { @parts = @pb; }
        elsif (/c/) { @parts = @pc; @parts2 = @pc2; }
        else { @parts = @pa; }
    }
    my $length = rand(7);
    my $name = '';
    if ($syls eq 'c') {
        $name = $parts[rand($#parts + 1)] . $parts2[rand($#parts2 + 1)]
    } else {
        foreach my $i (0 .. $length) {
            $name = $name . $parts[rand($#parts + 1)];
        }
    }
    return $name;
}

sub unittest {
    foreach my $i (0 .. 100) {
        my @ta = qw( road alley lane street avenue trail rd st );
        my @types = @ta;
        my $name = genname();
        $name = "$name " . $types[rand($#types + 1)];
        print "$i:$name\n";
    }
}

1;