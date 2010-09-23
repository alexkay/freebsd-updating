#!/usr/bin/env perl

use strict;
use warnings;

use LWP::Simple;

# File to keep the last CVS revision.
my $rev = 'UPDATING.rev';
# Generated Atom feed.
my $atom = 'UPDATING.atom';

# Check for a new revision at most once per hour.
unless (-e $rev and -M $rev < 1/24) {
    my $url = 'http://www.freebsd.org/cgi/cvsweb.cgi/ports/UPDATING';
    my $content = get ($url) || die "Could not fetch $url";

    # Get the new revision from HTML.
    unless ($content =~ /Revision <b>(\d+\.\d+)<\/b>/) {
        die "Could not parse $url";
    }

    my $newrev = $1;
    my $currev = open (REV, "< $rev") ? <REV> : '';

    if ($currev ne $newrev) {
        open REV, "> $rev";
        print REV $newrev;

        # Fetch the new UPDATING file.
        $content = get ("$url?rev=$newrev;content-type=text%2Fplain");
        open ATOM, "> $atom";
        print ATOM get_atom ($content);
    }
}

open ATOM, "< $atom" || die "Could not find the feed";
print <ATOM>;
print "\n";

sub get_atom {
    my $content = shift;
    return 'test';
}
