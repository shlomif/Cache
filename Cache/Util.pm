package Cache::Util;

use 5.006;
use strict;
use warnings;
use bytes;
  
require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);
our @EXPORT_OK = qw( &compileMAC );
our @EXPORT = @EXPORT_OK;
our $VERSION = 1.83;

use Cache::Routine;
use Cache::Global;
use Cache "CacheEval";

=head1 NAME

Cache::Util - Various utitity functions for Cache

=head1 SYNOPSIS

  use Cache::Util;


=head1 DESCRIPTION
 
This module contains various utility functions.

=head1 FUNCTIONS

The following functions (which are exported) exist:

=over 4

=item compileMAC $name, @lines

 Compiles Routine $name.

 Actually, this function is a good example on Cache-Perl
 programming, so it's included here for reference:

 sub compileMAC($@) {
     my ($rtn, @lines) = @_;
     my $size = length join "", @lines;
     unshift @lines, scalar @lines;
     Gset  "rMAC", $rtn, 0, CacheEval '$h';
     GsetA "rMAC", $rtn, 0, \@lines;
     GsetH "rMAC", $rtn, 0, { LANG =>  "", SIZE => $size };
     Do 'COMPILE', '%RCOMPIL', $rtn, 'MAC';
     die "Routine compilation failed for '$rtn'" unless defined Gget "rOBJ", $rtn;
 }
 

=cut

sub compileMAC($@) {
   my ($rtn, @lines) = @_;
   my $size = length join "", @lines;
   unshift @lines, scalar @lines;
   Gset  "rMAC", $rtn, 0, CacheEval '$h';
   GsetA "rMAC", $rtn, 0, \@lines;
   GsetH "rMAC", $rtn, 0, { LANG => "", SIZE => $size };
   Do 'COMPILE', '%RCOMPIL', $rtn, 'MAC';
   die "Routine compilation failed for '$rtn'" unless defined Gget "rOBJ", $rtn;
}

=back

=head1 EXPORTS

 none.

=head1 BUGS

 Arround version 0.22 I stopped counting.

=head1 SEE ALSO

L<Cache>, L<Cache::ObjectScript>, L<Cache::Global>, L<Cache::Routine>, L<Cache::Bind>.

=head1 AUTHOR

 Stefan Traby <stefan@hello-penguin.com>
 http://hello-penguin.com

=cut

1;
__END__

