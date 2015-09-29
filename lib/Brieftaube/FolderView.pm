package Brieftaube::FolderView;
use strict;
use warnings;
use Moo;
use String::Format qw(stringf);
use Data::Page;
use Mail::IMAPClient::BodyStructure;
use Encode qw(encode decode);
use Time::Piece;
use Date::Parse 'str2time';
use Curses;
use Brieftaube::MessageView;

has 'win'          => ( is => 'ro', required => 1 );
has 'imap'         => ( is => 'ro', required => 1 );
has 'pager'        => ( is => 'ro', required => 1 );
has 'cache'        => ( is => 'ro', required => 1 );
has 'index_format' => ( is => 'rw', default  => "%-20.20d %-20.20f %-s" );

sub display_page {
    my ( $self, $highlight ) = @_;
    $highlight ||= 0;
    $self->win->getmaxyx( my ( $lines, $cols ) );
    $self->win->erase;
    $self->win->move( 0, 0 );
    my $page = '';
    for my $uid ( $self->pager->current_elements() ) {
        my $line = $self->_format_index_line($uid);
        $page .= substr( $line, 0, $cols - 1 ) . "\n";
    }
    $self->win->addstring($page);
    $self->win->move( $self->pager->position_on_page, 0 );
    $self->win->chgat( -1, A_STANDOUT, 0, 0 );
    $self->win->refresh();
    return;
}

sub _format_index_line {
    my ( $self, $uid ) = @_;
    my $env = Mail::IMAPClient::BodyStructure::Envelope->parse_string(
        $self->cache->{$uid}->{'ENVELOPE'} );
    my %header =
      map { $_ => decode( 'MIME-Header', $env->{$_} ) } qw(subject date);
    ## TODO How to encode the string?
    my $from = $env->{from}->[0];
    ## TODO should 'NIL' be undef? That seems against the spec
    $from =
        $from->personalname ne 'NIL'
      ? $from->personalname
      : $from->mailboxname . '@' . $from->hostname;
    $header{from} = decode( 'MIME-HEADER', $from );
    $header{subject} = $header{subject} eq 'NIL' ? '' : $header{subject};
    my %formats = map { lc( substr( $_, 0, 1 ) ) => $header{$_} } keys %header;
    $formats{d} = sub {
        my $format = $_[0] || '%F %H:%M';
        Time::Piece->new( str2time( $header{date} ) )->strftime($format);
    };
    return stringf( $self->index_format, %formats );
}

sub next_element {
    my $self       = shift;
    my $prev_index = $self->pager->current_index;
    my $prev_page  = $self->pager->current_page;
    $self->pager->next_element;
    my $next_index = $self->pager->current_index;
    my $next_page  = $self->pager->current_page;

    if ( $prev_page != $next_page ) {
        $self->display_page;
    }
    elsif ( $prev_index != $next_index ) {
        $self->move_cursor( $self->pager->position_on_page );
    }
    return;
}

sub prev_element {
    my $self       = shift;
    my $prev_index = $self->pager->current_index;
    my $prev_page  = $self->pager->current_page;
    $self->pager->prev_element;
    my $next_index = $self->pager->current_index;
    my $next_page  = $self->pager->current_page;

    if ( $prev_page != $next_page ) {
        $self->display_page;
    }
    elsif ( $prev_index != $next_index ) {
        $self->move_cursor( $self->pager->position_on_page );
    }
    return;
}

sub display_next_page {
    my $self = shift;
    $self->pager->next_page;
    $self->display_page();
    return;
}

sub display_prev_page {
    my $self = shift;
    $self->pager->prev_page;
    $self->display_page();
    return;
}

sub display_first_page {
    my $self = shift;
    $self->pager->first_page;
    $self->display_page();
    return;
}

sub display_last_page {
    my $self = shift;
    $self->pager->last_page;
    $self->display_page();
    return;
}

sub move_cursor {
    my ( $self, $line ) = @_;
    $self->win->chgat( -1, A_NORMAL, 0, 0 );
    $self->win->move( $line, 0 );
    $self->win->chgat( -1, A_STANDOUT, 0, 0 );
    return;
}

sub display_message {
	my $self = shift;
	my $message_view = Brieftaube::MessageView->new(
		imap => $self->imap,
		win  => $self->win,
		pager => $self->pager,
		cache => $self->cache,
	);

	$message_view->display;
	$self->display_page;
	return;
}

sub handle_input {
    my ( $self, $char ) = @_;
    my %key_handler = (
        KEY_DOWN,  'next_element',      KEY_UP,    'prev_element',
        KEY_NPAGE, 'display_next_page', KEY_HOME,  'display_first_page',
        KEY_END,   'display_last_page', KEY_PPAGE, 'display_first_page',
        "\n",      'display_message',
    );
    if ( exists $key_handler{$char} ) {
	my $method = $key_handler{$char};
        $self->$method;
    }
    return;
}

1;
