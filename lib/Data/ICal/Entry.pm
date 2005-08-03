use warnings;
use strict;

package Data::ICal::Entry;
use Data::ICal::Property;
use Carp;

=head1 NAME

Data::ICal::Entry - Represents an entry in an iCalendar file


=head1 SYNOPSIS

    my $vtodo = Data::ICal::Entry::Todo->new();
    $vtodo->add_properties(
    # ... see Data::ICal::Entry::Todo documentation
    );

    $calendar->add_entry($vtodo);

    $event->add_entry($alarm); 
  
=head1 DESCRIPTION

A L<Data::ICal::Entry> object represents a single entry in an iCalendar file.
(Note that the iCalendar RFC refers to entries as "components".)  iCalendar
defines several types of entries, such as events and to-do lists; each of
these corresponds to a subclass of L<Data::ICal::Entry> (though only to-do
lists and events are currently implemented).  L<Data::ICal::Entry> should be treated
as an abstract base class -- all objects created should be of its subclasses.
The entire calendar itself (the L<Data::ICal> object) is also represented
as a L<Data::ICal::Entry> object.

Each entry has an entry type (such as C<VCALENDAR> or C<VEVENT>), a series
of "properties", and possibly some sub-entries.  (Only the root L<Data::ICal>
object can have sub-entries, except for alarm entries contained in events and
to-dos (not yet implemented).)

=head1 METHODS

=cut

=head2 new

Creates a new entry object with no properties or sub-entries.

=cut

sub new {
    my $class = shift;
    my $self  = {
        properties => {},
        entries    => [],
    };
    bless $self, $class;
    return $self;
}

=head2 as_string

Returns the entry as an appropriately formatted string (with trailing newline).

Properties are returned in alphabetical order, with multiple properties of the same name
returned in the order added.  (Property order is unimportant
in iCalendar, and this makes testing easier.)

If any mandatory property is missing, issues a warning.

=cut

sub as_string {
    my $self = shift;

    my $output = $self->header;

    for my $name (
        $self->mandatory_unique_properties,
        $self->mandatory_repeatable_properties
        )
    {
        carp "Mandatory property for " . ( ref $self ) . " missing: $name"
            unless $self->properties->{$name}
            and @{ $self->properties->{$name} };
    }

    for my $name ( sort keys %{ $self->properties } ) {
        $output .= $_
            for map { $_->as_string } @{ $self->properties->{$name} };
    }

    for my $entry ( @{ $self->entries } ) {
        $output .= $entry->as_string;
    }
    $output .= $self->footer;

    return $output;
}

=head2 add_entry $entry

Adds an entry to this entry.  (According to the standard, this should only be called
on either a to-do or event entry with an alarm entry, or on a calendar entry (L<Data::ICal>)
with a to-do, event, journal, timezone, or free/busy entry.)

Returns true if the entry was successfully added, and false otherwise (perhaps because you
tried to add an entry of an invalid type, but this check hasn't been implemented yet). 

=cut

sub add_entry {
    my $self  = shift;
    my $entry = shift;
    push @{ $self->{entries} }, $entry;

    return 1;
}

=head2 entries

Returns a reference to the array of subentries of this entry.

=cut

sub entries {
    my $self = shift;
    return $self->{'entries'};
}

=head2 properties

Returns a reference to the hash of properties of this entry.  The keys are property names and
the values are array references containing L<Data::ICal::Property> objects.

=cut

sub properties {
    my $self = shift;
    return $self->{'properties'};
}


=head2 property

Given a property name returns a reference to the array of L<Data::ICal::Property> objects.

=cut

sub property {
    my $self = shift;
    my $prop = lc shift;
	return $self->{'properties'}->{$prop};
}


=head2 add_property $propname => $propval

Creates a new L<Data::ICal::Property> object with name C<$propname> and value
C<$propval> and adds it to the event.

If the property is not known to exist for that object type and does not begin
with C<X->, issues a warning.

If the property is known to be unique, replaces the original property.

To specify parameters for the property, let C<$propval> be a two-element array reference
where the first element is the property value and the second element is a hash reference.
The keys of the hash are parameter names; the values should be either strings or array references
of strings, depending on whether the parameter should have one or multiple (to be comma-separated)
values.

=cut

sub add_property {
    my $self = shift;
    my $prop = lc shift;
    my $val  = shift;

    unless ( $self->is_property($prop) or $prop =~ /^x-/i ) {
        carp "Unknown property for " . ( ref $self ) . ": $prop";
    }

    if ( $self->is_unique($prop) ) {

        # It should be unique, so clear out anything we might have first
        $self->properties->{$prop} = [];
    }

    $val = [ $val, {} ] unless ref $val eq 'ARRAY';

    my ( $prop_value, $param_hash ) = @$val;

    push @{ $self->properties->{$prop} },
        Data::ICal::Property->new( $prop => $prop_value, $param_hash );
}

=head2 add_properties $propname1 => $propval1, [$propname2 => $propname2, ...]

Convenience function to call C<add_property> several times with a list of properties.

This method is guaranteed to call add C<add_property> on them in the order given, so that
unique properties given later in the call will take precedence over those given earlier.
(This is unrelated to the order of properties when the entry is rendered as a string, though.)

Parameters for the properties are specified in the same way as in C<add_property>.

=cut

sub add_properties {
    my $self = shift;

    if ( @_ % 2 ) {
        carp "Odd number of elements in add_properties call";
        return;
    }

    while (@_) {
        my $prop = shift;
        my $val  = shift;
        $self->add_property( $prop => $val );
    }
}

=head2 mandatory_unique_properties 

Subclasses should override this method (which returns an empty list by default)
to provide a list of lower case strings identifying the properties which must appear exactly
once in the subclass's entry type.

=cut

sub mandatory_unique_properties { () }

=head2 mandatory_repeatable_properties 

Subclasses should override this method (which returns an empty list by default)
to provide a list of lower case strings identifying the properties which must appear at least
once in the subclass's entry type.

=cut

sub mandatory_repeatable_properties { () }

=head2 optional_unique_properties 

Subclasses should override this method (which returns an empty list by default)
to provide a list of lower case strings identifying the properties which must appear at most
once in the subclass's entry type.

=cut

sub optional_unique_properties { () }

=head2 optional_repeatable_properties

Subclasses should override this method (which returns an empty list by default)
to provide a list of lower case strings identifying the properties which may appear zero,
one, or more times in the subclass's entry type.

=cut

sub optional_repeatable_properties { () }

=head2 is_property $name

Returns a boolean value indicating whether or not the property C<$name> is known to the class
(that is, if it's listed in C<(mandatory/optional)_(unique/repeatable)_properties>).

=cut

sub is_property {
    my $self = shift;
    my $name = shift;
    return scalar grep { $_ eq $name } $self->mandatory_unique_properties,
        $self->mandatory_repeatable_properties,
        $self->optional_unique_properties,
        $self->optional_repeatable_properties;
}

=head2 is_mandatory $name

Returns a boolean value indicating whether or not the property C<$name> is known to the class as mandatory
(that is, if it's listed in C<mandatory_(unique/repeatable)_properties>).

=cut

sub is_mandatory {
    my $self = shift;
    my $name = shift;
    return scalar grep { $_ eq $name } $self->mandatory_unique_properties,
        $self->mandatory_repeatable_properties;
}

=head2 is_optional $name

Returns a boolean value indicating whether or not the property C<$name> is known to the class as optional
(that is, if it's listed in C<optional_(unique/repeatable)_properties>).

=cut

sub is_optional {
    my $self = shift;
    my $name = shift;
    return scalar grep { $_ eq $name } $self->optional_unique_properties,
        $self->optional_repeatable_properties;
}

=head2 is_unique $name

Returns a boolean value indicating whether or not the property C<$name> is known to the class as unique
(that is, if it's listed in C<(mandatory/optional)_unique_properties>).

=cut

sub is_unique {
    my $self = shift;
    my $name = shift;
    return scalar grep { $_ eq $name } $self->mandatory_unique_properties,
        $self->optional_unique_properties;
}

=head2 is_repeatable $name

Returns a boolean value indicating whether or not the property C<$name> is known to the class as repeatable
(that is, if it's listed in C<(mandatory/optional)_repeatable_properties>).

=cut

sub is_repeatable {
    my $self = shift;
    my $name = shift;
    return scalar grep { $_ eq $name } $self->mandatory_repeatable_properties,
        $self->optional_repeatable_properties;
}

=head2 ical_entry_type

Subclasses should override this method to provide the identifying type name of the entry
(such as C<VCALENDAR> or C<VTODO>).

=cut

sub ical_entry_type {'UNDEFINED'}

=head2 header

Returns the header line for the entry (including trailing newline).

=cut

sub header {
    my $self = shift;
    return 'BEGIN:' . $self->ical_entry_type . "\n";
}

=head2 footer

Returns the footer line for the entry (including trailing newline).

=cut

sub footer {
    my $self = shift;
    return 'END:' . $self->ical_entry_type . "\n";
}

# mapping of event types to class (under the Data::Ical::Event namespace)
my %_generic = (
    vevent    => 'Event',
    vtodo     => 'Todo',
    vjournal  => 'Journal',
    vfreebusy => 'FreeBusy',
    vtimezone => 'TimeZone',
    standard  => 'TimeZone::Standard',
    daylight  => 'TimeZone::Daylight',
);


=head2 parse_object

Translate a L<Text::vFile::asData> sub object into the appropriate 
L<Data::iCal::Event> subtype.

=cut 


# TODO: this is currently recursive which could blow the stack -
#       it might be worth refactoring to make it sequential
sub parse_object {
    my ($self,$object) = @_;


    my $type = $object->{type};
    
    
    my $new_self;
    
    # First check to see if it's generic long name just in case there 
    # event turns out to be a VGENERIC entry type
    if (my $class = $_generic{lc($type)}) {
        $new_self = $self->_parse_data_ical_generic($class, $object);     
    # then look for specific overrides
    } elsif (my $sub = $self->can('_parse_'.lc($type))) {
        $new_self = $self->$sub($object);
    # bitch
    } else {
        warn "Can't parse type $type yet";
        return;
    }
        
    # recurse through sub-objects
    foreach my $sub_object(@{ $object->{objects} }) {
        $new_self->parse_object($sub_object);
    }

}



# special because we want to use ourselves as the parent
sub _parse_vcalendar {
    my ($self, $object) = @_;
    $self->_parse_generic_event($self, $object);
    return $self;
}

# mapping of action types to class (under the Data::Ical::Event::Alarm namespace)
my %_action_map = (
    AUDIO      => 'Audio',
    DISPLAY    => 'Display',
    EMAIL      => 'Email',
    PROCEDURE  => 'Procedure',
);

# alarms have actions
sub _parse_valarm {
    my ($parent, $object) = @_;

    # ick
    my $action = $object->{properties}->{ACTION}->[0]->{value};
    die "Can't parse VALARM with action $action" unless exists $_action_map{$action};

    
    my $alarm_class = "Data::ICal::Entry::Alarm::".$_action_map{$action};
    eval "require $alarm_class";
    die "Failed to require $alarm_class : $@" if $@;

    $alarm_class->import;
    my $alarm = $alarm_class->new;
    $parent->_parse_generic_event($alarm, $object);
    $parent->add_entry($alarm);
    return $alarm;

    
}    

# generic event handler
sub _parse_data_ical_generic {
    my ($parent, $class, $object) = @_;
    
    my $entry_class = "Data::ICal::Entry::$class";
    eval "require $entry_class";
    die "Failed to require $entry_class : $@" if $@;
    
    $entry_class->import;
    my $entry = $entry_class->new;
    $parent->_parse_generic_event($entry, $object);
    $parent->add_entry($entry);
    return $entry;
}

# handle transferring of properties
sub _parse_generic_event {
    my ($parent, $entry, $object) = @_;

    my $p = $object->{properties};
    while (my($key,$val) = each(%$p)) {
        foreach my $occurence (@$val) {
            my $prop;
            # handle optional params and 'normal' key/value pairs
            # TODO: line wrapping?
            if ($occurence->{param}) {
                $prop = [ $occurence->{value}, $occurence->{param} ];
            } else {
                $prop = $occurence->{value};
            }
            $entry->add_property( lc($key) => $prop );            
        }
    }
    return $entry;
}


=head1 AUTHOR

Jesse Vincent  C<< <jesse@bestpractical.com> >> with David Glasser and Simon Wistow


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2005, Best Practical Solutions, LLC.  All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

=cut

1;
