#!/usr/bin/env perl

use v5.20;
use strict;
use warnings;

use Pak;


# my $internals = $pak->grep ( sub ($key, $val) { $val->{intro_year} < 100; } );

use Mojolicious::Lite;

use feature qw(signatures);
no warnings qw(experimental::signatures);

app->secrets(['simutrans tool']);

{
    # Because we can't put code in the built-in 'new' function of Mojo::Base, we must
    # force a read of the data file here, using a closure inside which we define the helper.
    # Another possibility would be to put a code callback in the default value for one of the
    # member attributes, but the built-in 'attr' code forces an assignment outside such a callback,
    # whereas we would be depending on building that value and possibly calling $self->... functions
    # inside the callback; chicken-and-egg.
    my $mypak;

    $mypak = Pak->new(path => '~/Documents/games/simutrans/simutrans-pak128.britain');

    print "Reading...";
    $mypak->read_data_files;
    print "\n";

    helper pak => sub { $mypak; };

}

any '/' => sub ($c) {
    my @ot = sort keys %{$c->pak->object_types};
    $c->stash(object_types => [@ot]);
    $c->stash(object_type_names => { map { my $aa = $_; ($aa, $c->pak->translate($aa)) } @ot });
    $c->stash(object_type_count => { map { my $aa = $_; ($aa, $c->pak->object_types->{$aa}) } @ot });
} => 'index';

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

any '/objects/:objname' => sub ($c) {
    my $o = $c->stash('objname');        # variable copied into a closure so we can reference it in sub below.
    $c->stash(objects => $c->pak->grep( sub { $_[1]->{obj} eq $o} ));
    $c->stash(object_type_names => { map { my $aa = $_; ($aa, $c->pak->translate($aa)) } keys %{ $c->stash('objects')}  });
} => 'objects';

any '/object/:objname' => sub ($c) {
    my $o = $c->stash('objname');
    $c->stash(object => $c->pak->objects->{$o});
    $c->stash(objtype => $c->pak->objects->{$o}->{obj});
    $c->stash(objtext => $c->pak->translate($c->stash('objname')));

    # display scalar values with links to /object/with/key/value
    # and then remaining key/value pairs below
    
} => 'object';

any '/objects/with/:key/:value' => sub ($c) {
    my $val = $c->stash('value');        # variable copied into a closure so we can reference it in sub below.
    my $key = $c->stash('key');
    $c->stash(objname => "where $key = $val");
    $c->stash(objects => $c->pak->grep( sub { 
					    my $whatis = $_[1]->{$key};
					    return 0 unless defined $whatis;
					    if (ref $whatis) {
						# For the moment this only searches the top level.
						grep { lc($_) eq lc($val) } values %{$whatis};
					    } else {
						lc($_[1]->{$key}) eq lc($val);
					    }
					} ));
    $c->stash(object_type_names => { map { my $aa = $_; ($aa, $c->pak->translate($aa)) } keys %{ $c->stash('objects')}  });
} => 'objects';

app->start;

__DATA__

@@ index.html.ep
%layout 'default';

Simutrans Pakset Viewer Tool

<ul>
% foreach my $x (@{$object_types}) {
<li>
%= link_to "objects/$x" => begin
<%= %{$object_type_names}{$x}; %><% end %>
<small>(<%= %{$object_type_count}{$x}; %>)</small>
</li>
% }

@@ objects.html.ep
%layout 'default';

Simutrans Pakset Viewer Tool
<a href="/">(Back to front page)</a>
<hr>
<h1>
%= $objname
objects
</h1>

<ul>
% foreach my $x (sort keys %{$objects}) {
<li>
%= link_to "/object/$x" => begin
<%= %{$object_type_names}{$x}; %><% end %>
<small>(<%= $x %>)</small>
</li>
% }
</ul>

@@ object.html.ep
<a href="/">(Back to front page)</a>
<a href="/objects/<%= $objtype %>">(Back to <%= $objtype %>)</a>
<h1><%= $objtext %> <small>(coded as <tt><%= $objname %></tt>)</small></h1>

<ul>
% foreach my $x (sort keys %{$object}) {
%   my $v = $object->{$x};
%     if (!ref $v) {
%       $v ||= '0';
<li>
%= link_to "/objects/with/$x/$v" => begin
<%= $x %> = <%= $v %><% end %>
</li>
%   }
% }
</ul>

<hr>

<pre>
% use Data::Dumper;
%= Dumper($object)
</pre>


@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title>Simutrans Pakset Viewer</title></head>
  <body><%= content %></body>
</html>
