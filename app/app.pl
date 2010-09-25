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

# This script assumes that CVS/SVN checkouts are already set up:
#
# Ports:
# % cvs -d anoncvs@anoncvs1.FreeBSD.org:/home/ncvs co ports/UPDATING
#
# Stable 7/8
# % svn co --depth empty http://svn.freebsd.org/base/stable/X/ stable-X
# % cd stable-X && svn up UPDATING
#
# Current:
# % svn co --depth empty http://svn.freebsd.org/base/head head
# % cd head && svn up UPDATING
#
# Also set up the crontab to update these repositories, e.g.:
#
# @hourly     cd $HOME/updating/app/ports && cvs up
# @hourly     cd $HOME/updating/app/head && svn up
#             etc...

use strict;
use warnings;

use Digest::SHA qw (sha256_hex);
use FCGI;
use FindBin qw ($Bin);
use HTML::Entities;
use POSIX;
use XML::Atom::SimpleFeed;

my $request = FCGI::Request ();

while ($request->Accept () >= 0) {
    print "Content-type: application/atom+xml\r\n\r\n";
    print_feed ();
}

sub print_feed {
    my $type = 'ports';
    my $data = "$Bin/$type/UPDATING";
    my $atom = "$data.atom";

    # Update and re-generate the feed at most once per hour.
    $^T = time;
    unless (-e $atom and -M $atom < 1/24) {
        `touch $atom`;
        open ATOM, "> $atom";
        print ATOM get_feed ($data);
        close ATOM;
    }

    open ATOM, "< $atom" || die "Could not find the feed";
    print <ATOM>;
    close ATOM;
}

sub get_feed {
    my $data = shift;
    my $site = 'http://updating.versia.com/';
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
    my $entries = 5;
    # State variables.
    my ($date, $title, $content);

    open DATA, $data;
    while (<DATA>) {
        if (/^(\d{8}):/) {
            if (not $trim) {
                # Add the previous entry.
                my $updated = substr ($date, 0, 4) . '-' . substr ($date, 4, 2);
                $updated .= '-' . substr ($date, 6, 2) . 'T00:00:00Z';
                $feed->add_entry (
                    title   => $title,
                    content => "<pre>$content</pre>",
                    updated => $updated,
                    id      => "${site}entry/" . sha256_hex ($date, $title),
                );
                # Stop if we have enough entries.
                if (!--$entries) {
                    last;
                }
                $title = $content = '';
            }
            $trim = 0;
            $date = $1;
        } elsif ($trim) {
            next;
        } elsif (!$title) {
            $content = "$date:\n" . encode_entities ($_);
            s/^\s+|\s+$//g;
            $title = encode_entities ($_);
        } else {
            $content .= encode_entities ($_);
        }
    }
    close DATA;

    return $feed->as_string;
}
