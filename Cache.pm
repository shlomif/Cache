package Cache;

use 5.007;
use strict;
use warnings;

our $xs_loaded = 0;

BEGIN {
}
use XSLoader;
eval {
  XSLoader::load Cache unless $Cache::xs_loaded++; # this is in cacperl.xs :)
};
die "\n\nCan't load Cache-XS.\nThis happen when you use a plain Perl that is not embedded in Cache\n"
    ."Use the cperl script provided in the Cache-Perl distribution, loading Cache-Perl without\n"
    ."that will fail in any case\n\n$@" if $@;

require Exporter;
use AutoLoader qw(AUTOLOAD);

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Cache ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.

our @EXPORT = qw(
	&CacheEval &CacheExecute	&CacheHome
);

our %EXPORT_TAGS = ( 'all' => [ @EXPORT ],
                     'highlevel' => [ qw(
                                         _CacheAbort _CacheContext _CacheConvert _CacheConvert2                                         
                                         _CacheCtrl _CacheCvtIn _CacheCvt_Out _CacheEnd
                                         _CacheError _CacheErrxlate _CacheEval
                                         _CacheExecute _CachePrompt _CacheSignal _CacheStart
                                         _CacheType 
                                      )
                                    ],
                     'lowlevel' => [ qw(
                                         _CacheCloseOref _CacheDoFun _CacheDoRtn _CacheExtFun
                                         _CacheGetProperty _CacheGlobalGet _CacheGlobalSet
                                         _CacheIncrementCountOref _CacheInvokeClassMethod
                                         _CachePop _Cache_PopDbl _CachePopInt _CachePopList
                                         _CachePopOref _CachePopStr _CachePopPtr
                                         _CachePushDbl _CachePushFunc _CachePushFuncX
                                         _CachePushGlobal _CachePushGlobalX _CachePushInt
                                         _CachePushList _CachePushMethod _CachePushOref
                                         _CachePushProperty _CachePushPtr _CachePushRtn
                                         _CachePushRtnX _CachePushStr _CacheSetProperty
                                         _CacheUnPop
                                        )],
      
      );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} }, @{ $EXPORT_TAGS{'highlevel'} }, @{ $EXPORT_TAGS{'lowlevel'} });

our $VERSION = 1.83;


=head1 NAME

Cache - Integration of Intersystems Cache Database into Perl

=head1 SYNOPSIS

  use Cache qw(:lowlevel :highlevel);
  _CacheEval '$ZV'; print _CacheConvert();
  
This module and all modules in the Cache::-Domain
require a perl that has Cache fully embedded.
(such a binary is a dual-binary that is a Perl and a Cache
binary at the same time. Usually there is a softlink
(ln -s cache cperl) so you don't need to use cache --perl
anymore, it works the following way:

use:

  o cache --perl [perl options ]    and you start perl with embedded cache
  o cperl [ perl options ]          and you get perl with embedded cache
  o cache [ cache options ]         and you get cache with embedded perl

For backward compatibility with older versions of Cache-Perl

  o cache -perl [ perl options ]
  
is still supported but this feature is deprecated. Use "--perl" instead
of "-perl". 
  
Note: Most of this stuff is the low-level Interface, you normally don't need it,
except maybe CacheEval and CacheExecute.


  o use Cache::ObjectScript     - for embedded ObjectScript support
  o use Cache::Global           - for high-performance global access (bulk support)
  o use Cache::Routine          - for calling routines and functions
  o use Cache::Bind             - for bidirectional binding of COS Variables to Perl variables
  o use Cache::Util             - for utility functions and helpers


=head1 DESCRIPTION

 * This module provides full access to most Cache call-in functions.
 * You should not use the call-in function without exactly knowing what you are doing
 * These function are not exported by default and prepended by a underscore (that means internal).
 * All functions are perlified - you pass a single string if Cache expects a counted string
 * You don't need to check for errors. Most functions raise exceptions on error: use eval { }; to catch them
 * Only "A" functions are supported, no "W". "W" is NOT Unicode anyway, Intersystems simply lies to you.

=head1 User Interface for Cache Functions

=over 4

=item CacheEval $expr

 Evaluates a ObjectScript expression and returns its result
 Exception: yes
 Note: This function is slow because it has to preserve terminal settings

=item CacheExecute $stmt

 Executes a ObjectScript command and returns nothing.
 Exception: yes
 Note: This function is slow because it has to preserve terminal settings
 
=back

=head1 Cache Call-In High-Level Functions

The high-level functions can be imported by:
use Cache ':highlevel';

=over 4

=item _CacheAbort [ CACHE_CTRLC | CACHE_RESJOB ]

 See Cache specification.
 Exception: Yes
 Note: Don't use it.

=item $ctx = _CacheContext()

 See Cache specification.
 Exception: No

=item $value = _CacheConvert()

 See Cache specification.
 Exception: Yes
 Note: This function calls CacheConvert(CACHE_ASTRING, ...)

=item $value = _CacheConvert2()

 This routine uses CacheType() to ask for the type of TOS and
 tries to get the value the fastest way possible.

 Exception: Yes

=item _CacheCtrl($bitmap)

 See Cache specification
 Exception: Yes

=item $converted = _CacheCvtIn($string, $table)

 See Cache specification
 Exception: Yes

=item $converted = _CacheCvtOut($string, $table)

 See Cache specification
 Exception: Yes

=item _CacheEnd()

 See Cache specification
 Exception: Yes
 Note: You should NEVER EVER call this! even POSIX::_exit(1); is prefered.

=item $error = _CacheError()

 See Cache specification
 Exception: Yes (if a double fault happens)
 Note: No need to call this because every error is reported by croak.

=item $errorstring = _CacheErrxlate($errornum)

 See Cache specification
 Exception: No (if the call to CacheErrxlate fails, undef is returned)

=item _CacheEval $string

 See Cache specification
 Exception: Yes

=item _CacheExecute $string

 See Cache specification
 Exception: Yes

=item $prompt = _CachePrompt()

 See Cache specification
 Exception: Yes
 Note: Experts call this functions only by accident. :)

=item _CacheSignal $number

 See Cache specification
 Exception: Yes
 Note: Think and you will find out that you don't want it in most cases.

=item _CacheStart($flags, $timeout, $princin, $princout)

 See Cache specification
 Exception: Yes
 Note: Don't call it. It's already done. Say simply thanks :)

=item $type = _CacheType()

 See Cache specification
 Exception: No (ahm, check the return value for errors)

=back

=head1 Cache Low-Level Call-In Functions

 The low-level functions can be imported by:
 use Cache ':lowlevel';

Use it only IF:

  * you know how to use gdb
  * you want to corrupt the database
  * you never use a condom anyway :)
  * you know what gmngen/checksum/mdate is made for :)

=over 4

=item _CacheCloseOref $oref

 See Cache specification
 Exception: Yes

=item _CacheDoFun $rflags, $numargs

 See Cache specification
 Exception: Yes, please.

=item _CacheDoRtn $rflags, $numargs

 See Cache specification
 Exception: Oui

=item _CacheExtFun $rflags, $numargs

 See Cache specification
 Exception: Da

=item _CacheGetProperty()

 See Cache specification
 Exception: Yes, sir.

=item _CacheGlobalGet $numsubscipt, $die_or_empty

 See Cache specification
 Exception: yup

=item _CacheGlobalSet $numsubscript

 See Cache specification
 Exception: yup, on weekends only.

=item _CacheIncrementCountOref $oref

 See Cache specification
 Exception: ja

=item _CacheInvokeClassMethod $numarg

 See Cache specification
 Exception: si

=item _CachePop $arg

 Not implemented
 Exception: yes

=cut

sub _CachePop($) {
   die "_CachePop not implemented.";
}

=item $val = _CachePopDbl()

 See Cache specification
 Exception: yes

=item $val = _CachePopInt()

 See Cache specification
 Exception: yes

=item $string = _CachePopList()

 Currently not implemented
 Exception: yes

=cut

sub _CachePopList()
{
  die "_CachePopList is currently not implemented - sorry.";
}

=item $oref = _CachePopOref()

 See Cache specification
 Exception: yes

=item $str = _CachePopStr()

 See Cache specification
 Exception: yes

=item $ptr = CachePopPtr()

 Not Implemented
 Exception: yes

=cut

sub _CachePopPtr() {
   die "_CachePopPtr is currently not implemented";
}

=item _CachePushClassMethod $classname, $methodname, [$flag]/

 See Cache specification
 Exception: /bin/true
 Note: flag defaults to 0

=item _CachePushDbl $double

 See Cache specification
 Exception: yes

=item $rflags = _CachePushFunc $tag, $routine;

 See Cache specification
 Exception: yes

=item $rflags = _CachePushFuncX $tag, $offset, $env, $routine;

 See Cache specification
 Exception: yes

=item _CachePushGlobal $global

 See Cache specification
 Exception: yes

=item _CachePushGlobalX $global, $env

 See Cache specification
 Exception: yes

=item _CachePushInt $i

 See Cache specification
 Exception: yes

=item _CachePushList $string

 See Cache specification
 Exception: yes

=item _CachePushMethod $oref, $methodname, [$flag]

 See Cache specification
 Exception: yes
 Note: $flag defaults to 0

=item _CachePushOref $oref

 See Cache specification
 Exception: yes

=item _CachePushProperty $oref, $property

 See Cache specification
 Exception: yes

=item _CachePushPtr $value

 See Cache specification
 Exception: yes

=item $rflags = _CachePushRtn $tag, $routine

 See Cache specification
 Exception: yes

=item $rflags = _CachePushRtnX $tag, $offset, $env, $routine

 See Cache specification
 Exception: yes

=item _CachePushStr $string

 See Cache specification
 Exception: yes

=item _CacheSetProperty()

 See Cache specification
 Exception: yes

=item _CacheUnPop()

 See Cache specification
 Exception: yes

=back

=head1 SEE ALSO

L<Cache::ObjectScript>, L<Cache::Global>, L<Cache::Routine>, L<Cache::Util>, L<Cache::Bind>.

=head1 AUTHOR

 Stefan Traby <stefan@hello-penguin.com>
 http://hello-penguin.com

=head1 COPYRIGHT

 Copyright 2001,2003,2004 by KW-Computer Ges.m.b.H Graz, Austria
 Copyright 2001,2002,2003,2004 by Stefan Traby <stefan@hello-penguin.com>

=head1 LICENSE

 This module is licenced under LGPL
 (GNU LESSER GENERAL PUBLIC LICENSE)
 see the LICENSE-file in the toplevel directory of this distribution.

=cut

1;
__END__
