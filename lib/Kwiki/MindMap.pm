package Kwiki::MindMap;

=head1 NAME

Kwiki::MindMap - Display what's on your mind.

=head1 DESCRIPTION

Display what's on your mind.

=head1 COPYRIGHT

Copyright 2004 by Kang-min Liu <gugod@gugod.org>.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

See <http://www.perl.com/perl/misc/Artistic.html>

=cut

use strict;
use warnings;
use Kwiki::Plugin '-Base';
use YAML;

our $VERSION = '0.01';

const class_id => 'mindmap';
const class_title => 'MindMap Blocks';
const screen_template => 'site_mindmap_screen.html';

sub register {
    my $registry = shift;
    $registry->add(wafl => mindmap => 'Kwiki::MindMap::Wafl');
}

package Kwiki::MindMap::Wafl;
use base 'Spoon::Formatter::WaflBlock';
use Digest::MD5;
use GraphViz::Data::Grapher;

sub to_html {
    $self->cleanup;
    $self->render_mindmap($self->units->[0]);
}

# XXX: I think cleanup should be called ony once per-page.
# (If a page is modified, re-generate all the mindmap inside)
# but put it in here will make it be called once per-mindmap-block.
sub cleanup {
    my $path = $self->hub->mindmap->plugin_directory;
    my $page =$self->hub->pages->current;
    my $page_id = $page->id;
    for(<$path/$page_id/*.png>) {
	my $mt = (stat($_))[9];
	unlink($_) if $mt < $page->modified_time;
    }
}

# use md5 as filename because I don't want to regenerate all the graphs
# on every page rendering. That's totally a waste of time.
sub render_mindmap {
    my $reldump = shift;
    my $page = $self->hub->pages->current->id;
    my $digest = Digest::MD5::md5_hex($reldump);
    my $path = $self->hub->mindmap->plugin_directory;
    my ($title,$tree) = $self->load_mindmap($reldump);
    my $file = io->catfile($path,$page,"$digest.png")->assert;
    unless(-f "$file") {
        $file->lock;
	my $grvz = $self->hash2graph($tree,$title);
	$grvz->as_png() > $file;
	$file->unlock;
    }
    return qq{<img src="$file">};
}


sub hash2graph {
    my ($tree,$title) = @_;
    my $g = GraphViz->new(layout => 'neato');
    $self->hash2graph_recur($tree,$g,$title);
    return $g;
}

sub hash2graph_recur {
    my ($tree,$graph,$parent) = @_;
    return unless(ref($tree) eq 'HASH');
    for my $node (keys %$tree) {
	$graph->add_node("$parent/$node",
			 label => "$node",
			 shape => 'plaintext',
			 weight => 0, height => 0);
	$graph->add_edge("$parent","$parent/$node");
	$self->hash2graph_recur($tree->{$node},$graph,"$parent/$node");
    }
}


sub load_mindmap {
    my $dump = shift;
    my @lines = split/\n/,$dump;
    my $title = shift @lines;
    my $tree = $self->load_mindmap_subtree(@lines);
    return ($title,$tree);
}

sub load_mindmap_subtree {
    my @lines = @_;

    return '' unless(defined(@lines[0]));

    my $tree = {};
    my @scope = $self->subtree_scopes(@lines);
    my $i = 0;
    while($i < @scope) {
	my $node = $lines[$i]; $node =~ s/^=+\s*//;
	$tree->{$node} = $self->load_mindmap_subtree(@lines[$i+1..$scope[$i]]);
	$i = $scope[$i] + 1;
    }
    return $tree;
}

sub subtree_scopes {
    my @lines = @_;
    my @levels = $self->all_node_level(@lines);
    my @scope;

    # O(n^2). Could be better.
    for my $i (0..$#lines) {
	@scope[$i] = $i;
	for my $j ($i+1..$#lines) {
	    if($levels[$j] > $levels[$i]) {
		$scope[$i] = $j
	    } else {
		last;
	    }
	}
    }
    return @scope;
}

sub all_node_level {
    my @lines = @_;
    my @levels;
    for(@lines) {
	push @levels, $self->node_level($_);
    }
    return @levels;
}

sub node_level {
    my $line = shift;
    if ($line =~ /^(=+)/) {
	return length($1);
    } else {
	return -1;
    }
}


1;
