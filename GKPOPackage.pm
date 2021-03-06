package GKPOPackage;

# Copyright (C) 2010 James Kastrantas
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

use strict;
use warnings;
use diagnostics;

use base 'GKPOPackage::Base';

use Fcntl qw(SEEK_SET SEEK_CUR);
use IO::File;
use Carp;

use GKPOPackage::File;


# PKG_ refers to whole GKPO package constant.
# PKGF_ refers to constants that are specific to each file's metadata.

# Identifies the PKG file.
use constant PKG_HEADER         => 'GKPO';
use constant PKG_HEADER_LENGTH  => 4;

# Right after the file identifier is a 32 bit value that stores the
# number of files in the PKG
use constant PKG_NUM_FILES_OFFSET   => 4;

# Start of the PKG data.
use constant PKG_DATA_START => PKG_HEADER_LENGTH + PKG_NUM_FILES_OFFSET;




# Create a blessed hashref for the PKG object.
sub new {
    my ($class, $args_ref) = @_;
    
    my $self = {
        'pkg'   => $args_ref->{'pkg'}
    };
    
    bless $self, ref($class) || $class;
    
    if (defined $args_ref->{'pkg'}) {
        $self->_init($args_ref);
    }
    
    return $self;
}




sub get_files {
    my ($self, @files) = @_;
    
    unless (@files) {
        return values %{$self->{'files'}};
    }
    
    return map { $self->{'files'}->{$_} } (@files);
}




sub _init {
    my ($self) = @_;
    
    # Open the file pointed to by the pkg key for reading.
    my $fh = IO::File->new($self->{'pkg'}, "<");
    
    $self->{'fh'} = $fh;
    
    unless (defined $fh) {
        croak "Could not open $self->{'pkg'}";
    }
    
    $self->{'fh'}->binmode();
    
    # Stores the GKPOPackage::File objects.
    $self->{'files'} = {};
    
    # Sort of verifies this is a GKPO Package file by reading the
    # header.    
    $self->_read_header();
    
    # Store the number of files in the PKG file.
    $self->{'num_files'} = $self->_read_number({
        'fh'    => $self->{'fh'},
        'pos'   => PKG_NUM_FILES_OFFSET,
    });
    
    # Store the number of files.
    $self->_read_file_records(PKG_DATA_START);
}




# Verifies this is a GKPO file by reading the header.
sub _read_header {
    my ($self) = @_;
    
    # Stores the header from the package file.
    my $pkg_header = $self->_read_data($self->{'fh'}, 4, 0);
    
    if ($pkg_header ne PKG_HEADER) {
        croak $self->{'pkg'} . " is not a PKG file.";
    }
    
    return 1;
}
    
    
    

# Build a list of filename objects for the package
sub _read_file_records {
    my ($self, $offset) = @_;
    
    my $f;
    my $fh = $self->{'fh'};
    
    do {
        last if !defined($offset);
        $f = GKPOPackage::File->new({
            'meta_offset' => $offset,
            'fh'          => $fh,
            'pkg'         => $self->{'pkg'},
        });
        
        $self->{'files'}->{$f->filename()} = $f;
    } while ($offset = $f->_read_next_record_offset($self->{'fh'}));
}

1;
