#!/usr/bin/env RAKUDO_RAKUAST=1 raku

use v6.*;

# Helper script to update the localized deparse of available
# localizations.
#
# This script assumes that deparsing is correct at time of execution.

my $io  := $*PROGRAM.sibling("sources");
say "Parsing basic code";
my $ast := $io.add("basic").slurp.AST;
say "  Done parsing basic code";

my $REPO = $*REPO;
my $localizations := $*PROGRAM.parent.parent.add("localizations");

for $localizations.dir.map({ .basename if .d }).sort {
    say "  Deparsing $_";

    my $*REPO := CompUnit::Repository::FileSystem.new(
      prefix => $localizations.add($_).add("lib"),
      next-repo => $REPO
    );
    $io.add("basic.$_").spurt($ast.DEPARSE($_));
}

# vim: expandtab shiftwidth=4
