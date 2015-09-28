package Brieftaube::Pager;
use strict;
use warnings;
use Moo;
use Data::Page;

has 'array' => ( is => 'ro',   required => 1 );
has 'page'  => ( is => 'lazy', handles  => [qw(current_page total_entries)] );
has 'current_index' => ( is => 'rw', default  => 0 );
has 'page_size'     => ( is => 'rw', required => 1 );

sub _build_page {
    my $self = shift;
    my $page = Data::Page->new();
    $page->entries_per_page( $self->page_size );
    $page->total_entries( scalar @{ $self->array } );
    return $page;
}

sub current_element {
    my $self = shift;
    return $self->array->[ $self->current_index ];
}

sub next_element {
    my ($self) = @_;
    my $next_index = $self->current_index + 1;
    if ( $next_index < $self->total_entries ) {
        $self->current_index($next_index);
        if ( $next_index + 1 > $self->page->last ) {
            $self->current_page( $self->page->next_page );
        }
    }
    return $self->array->[$next_index];
}

sub prev_element {
    my ($self) = @_;
    my $next_index = $self->current_index - 1;
    if ( $next_index >= 0 ) {
        $self->current_index($next_index);
        if ( $next_index < $self->page->first ) {
            $self->current_page( $self->page->previous_page );
        }
    }
    return $self->array->[$next_index];
}

sub current_elements {
    my $self = shift;
    return $self->page->splice( $self->array );
}

sub position_on_page {
    my $self = shift;
    return $self->current_index % $self->page->entries_per_page;
}

sub first_page {
    my $self = shift;
    $self->current_index(0);
    $self->page->current_page(1);
    return;
}

sub prev_page {
    my $self = shift;
    $self->page->current_page( $self->page->previous_page || 1 );
    $self->current_index( $self->page->last - 1 );
    return;
}

sub next_page {
    my $self = shift;
    $self->page->current_page( $self->page->next_page
          || $self->page->last_page );
    $self->current_index( $self->page->first - 1 );
    return;
}

sub last_page {
    my $self = shift;
    $self->page->current_page( $self->page->last_page );
    $self->current_index( $self->page->last - 1 );
    return;
}

1;
