package Brieftaube::Folder;
use strict;
use warnings;
use Moo;
use String::Format qw(stringf);
use Data::Page;
use Mail::IMAPClient::BodyStructure;
use Encode qw(encode decode);
use Curses;

has 'folder' => ( is => 'ro', required => 1 );
has 'imap'   => ( is => 'ro', required => 1 );
has 'win'    => ( is => 'ro', required => 1 );

has 'index_format' => ( is => 'rw', default => "%-20.20d %-20.20f %-s" );

has 'bodystructure' => ( is => 'lazy' );
has 'page'          => ( is => 'lazy', handles => [qw( entries_on_this_page)] );
has 'uids'          => ( is => 'lazy' );

sub _build_uids {
    my $self  = shift;
    my $inbox = $self->imap->select( $self->folder );
    return $self->imap->sort( 'DATE', 'UTF-8', 'ALL' );
}

sub _build_page {
    my $self = shift;
    my $page = Data::Page->new();
    $self->win->getmaxyx( my ( $lines, $cols ) );
    $page->entries_per_page($lines);
    $page->total_entries( scalar @{ $self->uids } );
    return $page;
}

sub _build_bodystructure {
    my $self = shift;
    return $self->imap->fetch_hash( $self->imap->Range( $self->uids ),
        'ENVELOPE', 'BODYSTRUCTURE' );
}


sub display_page {
    my ( $self, $highlight ) = @_;
    $highlight ||= 0;
    $self->win->getmaxyx( my ( $lines, $cols ) );
    $self->win->erase;
    $self->win->move( 0, 0 );
    for my $uid ( $self->page->splice( $self->uids ) ) {
        my $line = $self->_format_index_line($uid);
        $self->win->addstring( substr( $line, 0, $cols - 1 ) . "\n" );
    }
    if ( $highlight == -1 ) {
        $self->win->move( $self->page->entries_on_this_page - 1, 0 );
    }
    else {
        $self->win->move( 0, 0 );
    }
    $self->win->chgat( -1, A_STANDOUT, 0, 0 );
    $self->win->refresh();
    return;
}

sub display_prev_page {
    my $self = shift;
    if ( $self->page->first_page != $self->page->current_page ) {
        $self->page->current_page( $self->page->previous_page );
        $self->display_page(-1);
    }
    else {
        $self->display_page();
    }
    return;
}

sub display_next_page {
    my $self = shift;
    if ( $self->page->last_page != $self->page->current_page ) {
        $self->page->current_page( $self->page->next_page );
        $self->display_page();
    }
    else {
        $self->display_page(-1);
    }
    return;
}

sub display_first_page {
    my $self = shift;
    $self->page->current_page(1);
    $self->display_page();
    return;
}

sub display_last_page {
    my $self = shift;
    $self->page->current_page( $self->page->last_page );
    $self->display_page(-1);
    return;
}

sub _format_index_line {
    my ( $self, $uid ) = @_;
    my $env = Mail::IMAPClient::BodyStructure::Envelope->parse_string(
        $self->bodystructure->{$uid}->{'ENVELOPE'} );
    my %header =
      map { $_ => decode( 'MIME-Header', $env->{$_} ) } qw(subject date);
    ## TODO How to encode the string?
    my $from = $env->{from}->[0];
    $from =
        $from->personalname ne 'NIL'
      ? $from->personalname
      : $from->mailboxname . '@' . $from->hostname;
    $header{from} = decode( 'MIME-HEADER', $from );
    $header{subject} = $header{subject} eq 'NIL' ? '' : $header{subject};
    my %formats = map { lc( substr( $_, 0, 1 ) ) => $header{$_} } keys %header;
    return stringf( $self->index_format, %formats );
}

1;
