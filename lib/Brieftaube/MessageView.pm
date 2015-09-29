package Brieftaube::MessageView;
use strict;
use warnings;
use Moo;
use Encode qw(encode decode);

has 'win'   => ( is => 'ro', required => 1 );
has 'imap'  => ( is => 'ro', required => 1 );
has 'pager' => ( is => 'ro', required => 1 );
has 'cache' => ( is => 'ro', required => 1 );

sub display {
    my $self      = shift;
    my $uid       = $self->pager->current_element;
    my $part      = $self->imap->get_bodystructure($uid);
    my $text_part = $self->find_plain_text_part($part);
    my $body      = $self->decode_mail( $uid, $text_part );
    $self->win->erase;
    $self->win->scrollok();
    $body =~ s/\r\n/\n/smxg;
    $self->win->addstr( 0, 0, encode( 'utf8', $body ) );
    $self->win->refresh();
    $self->win->getch();
    return;
}

sub find_plain_text_part {
    my ($self,$part) = @_;
    if ( lc( $part->bodytype ) eq 'multipart' ) {
        my @parts = $part->bodystructure();
        for my $part (@parts) {
            if ( $self->get_type($part) eq 'text/plain' ) {
                return $part;
            }
        }
    }
    elsif ( $self->get_type($part) eq 'text/plain' ) {
        return $part;
    }
    return;
}

sub decode_mail {
    my ( $self, $uid, $part ) = @_;
    my $body     = $self->imap->bodypart_string( $uid, $part->id );
    my $encoding = $part->bodyenc;
    my %decoder  = (
        'quoted-printable' => \&decode_qp,
        'base64'           => \&decode_base64,
        '8bit'             => sub { $_[0] },
        '7bit'             => sub { $_[0] },
    );
    if ($encoding) {
        $encoding = lc $encoding;
        if ( exists $decoder{$encoding} ) {
            $body = $decoder{$encoding}->($body);
        }
        else {
            boom("Can't decode mail: Unknown encoding $encoding.\n");
        }
    }
    my $charset = $part->bodyparms->{charset};
    if ($charset) {
        $body = decode( $charset, $body );
    }
    return $body;
}

sub get_type {
    my ( $self, $part ) = @_;
    return lc( $part->bodytype . '/' . $part->bodysubtype );
}

1;
