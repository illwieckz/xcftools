#! /usr/bin/perl
# This script extracts option strings, longopt arrays and
# manpage fragments for xcftools
# Copyright (C) 2006  Henning Makholm
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of version 2 of the GNU General Public License as
# published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict ; use warnings ;

my $mastersource = "options.i" ;

my $target = shift ;
my @defines = ( "\U$target" ) ;
push @defines, "\U$1foo" if $target =~ /^(xcf(2|to))/ ;

open INFILE, "-|", join(" ","cpp -imacros config.h",
                        (map "-D$_",@defines),
                        "-DTHISPROGRAM=$target",$mastersource)
    or die "Cannot preprocess options." ;

open OUTFILE, ">", "$target.oi"
    or die "Cannot write $target.oi" ;
print OUTFILE "/* Autogenerated by $0 $target */\n" ;
print OUTFILE "#define $_\n" for @defines ;
print OUTFILE "#define OPTIONGROUP(a,b)\n" ;

my %manstrings ;
my $mansection = '1i' ;
my @desc ;
my $optstring = "" ;

print OUTFILE "#ifdef HAVE_GETOPT_LONG\n" ;
print OUTFILE "static const struct option longopts[] = {\n" ;

my $manref = undef ;
my $parskip ;
while( <INFILE> ) {
    next if /^#/ ;
    if( /^OPTION\(([^,]+),([^,]+),(.*),\s*/ ) {
        my ($short,$long,$desc) = ($1,$2,$3) ;
        my $hasarg = '' ;
        if( $desc =~ s/^\s*\(([^()]+)\)\s*// ) {
            $hasarg = $1 ;
        }
        my @long = split / /,$long ;
        my $longfordesc = $long[0] ;
        for my $l ( @long ) {
            my $long = $l ;
            $long =~ s/^--//
                or print STDERR "Long option $long should have dashes\n" ;
            print OUTFILE "\t{ \"$long\", ",$hasarg ? 1 : 0,", 0, $short},\n" ;
        }
        if( $short =~ s/^\s*'(.)'\s*$/-$1/ ) {
            unshift @long, $short ;
            $optstring .= $1 . ($hasarg && ':') ;
        } else {
            undef $short ;
        }
        if( @long ) {
            (my $descarg = $hasarg ) =~ s/\"//g ;
            $manref = \$manstrings{$mansection}{$long[0]} ;
            $long[0] =~ s/^(-[^-])/\\$1/ ;
            $$manref = "" ;
            my $next = ".TP 8\n" ;
            $hasarg =~ s/"([^\"]*)"/\\fB$1\\fI/g ;
            $hasarg = " \\fI$hasarg\\fR" if $hasarg ;
            for my $long ( @long ) {
                $$manref .= $next . "\\fB$long\\fR$hasarg" ;
                $next = ", " ;
            }
            $$manref .= "\n" ;
            $parskip = 1 ;
            push @desc, [$short || $long[0],
                         $descarg,
                         $desc,
                         $short && $long[1] ] ;
        }
    } elsif( /^\s*\)\);/ ) {
        $manref = undef ;
    } elsif( defined $manref ) {
        s/^\s*// ;
        s/''/\'/g ;
        s/^\(\s*// if $parskip ;
        $$manref .= $_ ;
        $parskip = 0 ;
    } elsif( /^OPTIONGROUP\(([^(,)]+),([^(,)]*)\)/ ) {
        push @desc,$2 unless $mansection eq $1 ;
        $mansection = $1 ;
    }
}
print OUTFILE "{0}};\n" ;
print OUTFILE "#define LONGALT(s) \" (\" s \")\"\n" ;
print OUTFILE "#else\n" ;
print OUTFILE "#define LONGALT(s) \"\"\n" ;
print OUTFILE "#endif\n" ;
close INFILE ;

print OUTFILE "static void\nopt_usage(FILE *f)\n{\n" ;
my %d15plus ;
my $longest = 2 ;
for my $desc ( @desc ) {
    next unless ref $desc ;
    my $l = length $$desc[0] ;
    my $x = $$desc[1] ;
    if( $x ) {
        next if exists($d15plus{$x}) && $d15plus{$x} >= $l+1 ;
        $d15plus{$x} = $l+1 ;
    } else {
        $longest = $l if $longest < length $l ;
    }
}
print OUTFILE "  int i = $longest;\n  int j;\n" ;

for my $d15 ( sort keys %d15plus ) {
    print OUTFILE "  j=strlen(_(\"$d15\"))+$d15plus{$d15}; if( j>i ) i=j;\n" ;
}
for my $desc ( @desc ) {
    unless( ref $desc ) {
        print OUTFILE "  fprintf(f,\"%s:\\n\",_(\"$desc\"));\n"
            if $desc ;
        next ;
    }
    my ($optname,$d15,$helptext,$alternative) = @$desc ;
    my $d1l = length($optname) ;
    print OUTFILE ("  fprintf(f,\"  ",$optname);
    my $f2a = "i-$d1l,\"\"" ;
    if( $d15 ) {
        print OUTFILE " " ;
        $f2a = "i-".($d1l+1).",_(\"$d15\")" ;
    }
    print OUTFILE "%-*s %s" ;
    if( $alternative ) {
        print OUTFILE "\" LONGALT(\"$alternative\") \"";
    }
    print OUTFILE "\\n\",$f2a,\n    _(\"$helptext\"));\n" ;
}
print OUTFILE "}\n" ;
print OUTFILE "#undef LONGALT\n" ;
print OUTFILE "#define OPTSTRING \"$optstring\"\n" ;
close OUTFILE
    or die "Problems closing $target.oi" ;

for $mansection ( keys %manstrings ) {
    my $hash = $manstrings{$mansection} ;

    open OUTFILE,">","$target.$mansection"
        or die "Cannot write $target.$mansection" ;
    print OUTFILE @$hash{sort { "\U$a" cmp "\U$b" or $b cmp $a }
                         keys %$hash} ;
    close OUTFILE or die "Problems closing $target.$mansection" ;
}
    
                