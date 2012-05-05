package Import::Into;

use strict;
use warnings FATAL => 'all';

our $VERSION = '1.000002'; # 1.0.2

my %importers;

sub import::into {
  my ($class, $target, @args) = @_;
  $class->${\(
    $importers{$target} ||= eval qq{
      package $target;
      sub { shift->import(\@_) };
    } or die "Couldn't build importer for $target: $@"
  )}(@args);
}

1;
 
=head1 NAME

Import::Into - import packages into other packages 

=head1 SYNOPSIS

  package My::MultiExporter;

  use Import::Into;

  use Thing1 ();
  use Thing2 ();

  sub import {
    my $target = caller;
    Thing1->import::into($target);
    Thing2->import::into($target, qw(import arguments));
  }

Note: you don't need to do anything more clever than this provided you
document that people wanting to re-export your module should also be using
L<Import::Into>. In fact, for a single module you can simply do:

  sub import {
    ...
    Thing1->import::into(scalar caller);
  }

Notably, this works:

  use base qw(Exporter);

  sub import {
    shift->export_to_level(1);
    Thing1->import::into(scalar caller);
  }

=head1 DESCRIPTION

Writing exporters is a pain. Some use L<Exporter>, some use L<Sub::Exporter>,
some use L<Moose::Exporter>, some use L<Exporter::Declare> ... and some things
are pragmas.

If you want to re-export other things, you have to know which is which.
L<Exporter> subclasses provide export_to_level, but if they overrode their
import method all bets are off. L<Sub::Exporter> provides an into parameter
but figuring out something used it isn't trivial. Pragmas need to have
their C<import> method called directly since they affect the current unit of
compilation.

It's ... annoying.

However, there is an approach that actually works for all of these types.

  eval "package $target; use $thing;"

will work for anything checking caller, which is everything except pragmas.
But it doesn't work for pragmas - pragmas need:

  $thing->import;

because they're designed to affect the code currently being compiled - so
within an eval, that's the scope of the eval itself, not the module that
just C<use>d you - so

  sub import {
    eval "use strict;"
  }

doesn't do what you wanted, but

  sub import {
    strict->import;
  }

will apply L<strict> to the calling file correctly.

Of course, now you have two new problems - first, that you still need to
know if something's a pragma, and second that you can't use either of
these approaches alone on something like L<Moose> or L<Moo> that's both
an exporter and a pragma.

So, the complete solution is:

  my $sub = eval "package $target; sub { shift->import(\@_) }";
  $sub->($thing, @import_args);

which means that import is called from the right place for pragmas to take
effect, and from the right package for caller checking to work - and so
behaves correctly for all types of exporter, for pragmas, and for hybrids.

Remembering all this, however, is excessively irritating. So I wrote a module
so I didn't have to anymore. Loading L<Import::Into> will create a method
C<import::into> which you can call on a package to import it into another
package. So now you can simply write:

  use Import::Into;

  $thing->import::into($target, @import_args);

Just make sure you already loaded C<$thing> - if you're receiving this from
a parameter, I recommend using L<Module::Runtime>:

  use Import::Into;
  use Module::Runtime qw(use_module);

  use_module($thing)->import::into($target, @import_args);

And that's it.

=head1 AUTHOR

mst - Matt S. Trout (cpan:MSTROUT) <mst@shadowcat.co.uk>

=head1 CONTRIBUTORS

None yet - maybe this software is perfect! (ahahahahahahahahaha)

=head1 COPYRIGHT

Copyright (c) 2010-2011 the Import::Into L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself.