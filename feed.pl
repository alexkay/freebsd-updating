#!/usr/bin/env perl

# Copyright (c) 2010 Alexander Kojevnikov. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
# OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
# SUCH DAMAGE.

use strict;
use warnings;

use Digest::SHA qw (sha256_hex);
use HTML::Entities;
use LWP::Simple;
use POSIX;
use XML::Atom::SimpleFeed;

my $site = 'http://updating.versia.com/';
# File to keep the last CVS revision.
my $rev = 'UPDATING.rev';
# Generated Atom feed.
my $atom = 'UPDATING.atom';

# Check for a new revision at most once per hour.
unless (-e $rev and -M $rev < 1/24) {
    my $url = 'http://www.freebsd.org/cgi/cvsweb.cgi/ports/UPDATING';
    my $data = get ($url) || die "Could not fetch $url";

    # Get the new revision from HTML.
    unless ($data =~ /Revision <b>(\d+\.\d+)<\/b>/) {
        die "Could not parse $url";
    }

    my $newrev = $1;
    my $currev = open (REV, "< $rev") ? <REV> : '';

    if ($currev ne $newrev) {
        open REV, "> $rev";
        print REV $newrev;

        # Fetch the new UPDATING file.
        $data = get ("$url?rev=$newrev;content-type=text%2Fplain");
        open ATOM, "> $atom";
        print ATOM get_feed ($data);
    }
}

open ATOM, "< $atom" || die "Could not find the feed";
print <ATOM>;

sub get_feed {
    my $data = shift;
    my $feed = XML::Atom::SimpleFeed->new (
        title   => 'FreeBSD ports/UPDATING',
        link    => $site,
        link    => { rel => 'self', href => "${site}atom" },
        updated => strftime ('%Y-%m-%dT%H:%M:%SZ', gmtime),
        author  => 'Alexander Kojevnikov',
        id      => $site,
    );

    # Remove the description header.
    my $trim = 1;
    # Number of entries in the feed.
    my $entries = 40;
    # State variables.
    my ($date, $title, $content);

    foreach my $line (split ("\n", $data)) {
        if ($line =~ /^(\d{8}):/) {
            if (not $trim) {
                # Add the previous entry.
                $feed->add_entry (
                    title   => $title,
                    content => "<pre>$content</pre>",
                    updated => $date,
                    id      => "${site}entry/" . sha256_hex ($date, $title, $content),
                );
                # Stop if we have enough entries.
                if (!$entries--) {
                    last;
                }
                $title = $content = '';
            }
            $trim = 0;
            $date = substr ($1, 0, 4) . '-' . substr ($1, 4, 2);
            $date .= '-' . substr ($1, 6, 2) . 'T00:00:00Z';
        } elsif ($trim) {
            next;
        } elsif ($line =~ /^\s*(AFFECTS:.*)/) {
            $title = encode_entities ($1);
            $content = encode_entities ($line);
        } else {
            $content .= "\n" . encode_entities ($line);
        }
    }

    return $feed->as_string;
}
