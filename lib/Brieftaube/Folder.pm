package Brieftaube::Folder;
use strict;
use warnings;
use Moo;
use String::Format qw(stringf);
use Data::Page;
use Mail::IMAPClient::BodyStructure;
use Encode qw(encode decode);

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

sub next_page {
    return $_[0]->page->current_page( $_[0]->page->next_page );
}

sub prev_page {
    return $_[0]->page->current_page( $_[0]->page->prev_page );
}

sub display_page {
    my $self = shift;
    $self->win->getmaxyx( my ( $lines, $cols ) );
    $self->win->erase;
    $self->win->move(0,0);
    for my $uid ( $self->page->splice( $self->uids ) ) {
        my $line = $self->_format_index_line($uid);
        $self->win->addstring( substr($line,0,$cols - 1 )."\n");
    }
    $self->win->move(0,0);
    $self->win->refresh();
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
    my %formats = map { lc( substr( $_, 0, 1 ) ) => $header{$_} } keys %header;
    return stringf( $self->index_format, %formats );
}

1;
