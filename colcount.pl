#!/usr/bin/perl

# usage: colcount.pl --[no]comma --[no]header filename | less
# usage: cat file | colcount.pl - | less

# Default is --nocomma, --noheader so if you use args, you'll probably
# use --comma and/or --header. Unique abbreviations are supported, as
# are --arg and -arg.

# Need utf8 so that regex will match. Using the utf8 pragma with stdin solved all of the other problems.

# The use open qw(:std :utf8); is a powerful pragma required to make Perl read stdin as utf8.

# See http://stackoverflow.com/questions/519309/how-do-i-read-utf-8-with-diamond-operator


use strict;
use Text::CSV;
use Getopt::Long;
use utf8;
use open qw(:std :utf8);
use Data::Dumper;

my $row = 1;
main:
{
    my $sep_char = "\t";
    my $use_comma = 0;
    my $use_header = 0;

    # Must have ! to support --header and --noheader which I think
    # means that the default is options disabled.

    my $ok = GetOptions('comma!' => \$use_comma,
			'header!' => \$use_header);

    if ($use_comma)
    {
	$sep_char = ",";
    }
   
    my $csv = Text::CSV->new( { sep_char => $sep_char });

    my $fh = 0;
    if (! $ARGV[0] || $ARGV[0] eq "-")
    {
	$fh = *STDIN;
    }
    elsif (open(IN, "< $ARGV[0]"))
    {
	$fh = *IN;
    }
    else
    {
	die "Can't open $ARGV[0]\n";
    }

    # Build headers using the first line.
    my @labels;
    my @values;
    {
	my $temp = <$fh>;
	my $status  = $csv->parse($temp);
	@values = $csv->fields();  
	@labels = @values;
    }

    # Use Perl foreach replace in place to change items of @labels to
    # numeric headers.

    if (! $use_header)
    {
	foreach my $item (@labels)
	{
	    $item = "  ";
	}
    }

    # The format field width should be at least one. Zero might work,
    # but just seems like a bad idea.

    my $max_llen = 1;
    my $fmt;
    foreach my $item (@labels)
    {
	if (length($item) > $max_llen)
	{
	    $max_llen = length($item);
	}
    }
    $fmt = "\%+$max_llen\.$max_llen" . "s";

    show_rec(\@values, \@labels, $fmt);

    my $yy = 1;
    while(my $temp = <$fh>)
    {
	my $status  = $csv->parse($temp);
	my @cols = $csv->fields();  
	my $curr_cols = scalar(@values);
	show_rec(\@cols, \@labels, $fmt);
	$yy++;
    }

}

sub show_rec
{
    my @cols = @{$_[0]};
    my @labels = @{$_[1]};
    my $fmt = $_[2];
    
    print "row: $row\n";
    $row++;
    print "in co la: value\n";
    for(my $xx = 0; $xx <= $#cols; $xx++)
    {
	if ($labels[$xx] =~ m/contrib/i)
	{
	    # change \n to comma in the contributors field
	    $cols[$xx] =~ s/\n/,/sg;
	}
	# strip leading white space from all fields
	$cols[$xx] =~ s/^\s+//;
	printf("%2.2d %2.2d $fmt: %s\n", $xx, $xx+1, $labels[$xx], $cols[$xx]);
    }
    print "\n";
}

sub  old_main: 
{
    my $sep_char = "\t";
    if ($ARGV[1] eq "-c")
    {
	$sep_char = ",";
    }
    
    my $allfile = readfile($ARGV[0]);
    
    my @lines;
    my $curr_line = "";
    my $quote_count = 0;
    my $second = "";
    while($allfile =~ m/(.*?)(\"|\n)/sg) # this needs to ignore \n that is ""
    {
	$second = "";
	if ($2 eq "\"")
	{
	    $quote_count++;
	    $second = "";
	}
	if (($quote_count % 2) && ($2 eq "\n"))
	{
	    #print "found newline qc:$quote_count\n";
	    $second = $2;
	}
	
	$curr_line .= "$1$second";
	if ((($quote_count % 2) == 0) && $2 eq "\n") # is even and found a \n
	{
	    #print "pushing $curr_line\n";
	    push(@lines, $curr_line);
	    $curr_line = "";
	}
    }

    my $lflag = 0;
    my $row = 1;
    my $max_llen = 0;
    my @labels;

    foreach my $temp (@lines)
    {
	# Don't use split because Perl will truncate the returned array 
	# due to an undersireable feature where arrays returned and assigned 
	# have null elements truncated.
	# Also, make sure there is a terminal \n which makes the regex
	# both simpler and more robust.

	if ($temp !~ m/\n$/)
	{
	    $temp .= "\n";
	}
	my @cols;
	while($temp)
	{
	    $temp =~ s/(.*?)[\t\n]//;
	    push(@cols, $1);
	}

	print "row: $row\n";
	$row++;
	if ($#cols > 1 && $lflag == 0)
	{
	    @labels = @cols;
	    $lflag = 1;
	    for(my $xx = 0; $xx <= $#labels; $xx++)
	    {
		$labels[$xx] =~ s/[\000-\037]/\ /sg; # get rid of control chars, including cr and lf
		if (length($labels[$xx]) > $max_llen)
		{
		    $max_llen = length($labels[$xx]);
		}
	    }
	}
	my $fmt = "\%+$max_llen\.$max_llen" . "s";
	# print "$fmt\n";
	#$fmt = '%+20.20s';
	for(my $xx = 0; $xx <= $#cols; $xx++)
	{
	    if ($labels[$xx] =~ m/contrib/i)
	    {
		$cols[$xx] =~ s/\n/,/sg; # change \n to comma in the contributors field
	    }
	    $cols[$xx] =~ s/^\s+//;    # strip leading white space from all fields
	    printf("%2.2d $fmt: %s\n", $xx, $labels[$xx], $cols[$xx]);
	}
	print "\n";
    }

    exit();
}

sub readfile
{
    my @stat_array = stat($_[0]);
    if ($#stat_array < 7)
    {
        die "File $_[0] not found\n";
    }
    my $temp;
    #
    # 2003-01-10 Tom:
    # It is possible that someone will ask us to open a file with a leading space.
    # That requires separate args for the < and for the file name. I did a test to confirm
    # this solution. It also works for files with trailing space.
    # 
    # open(IN, "<", "$_[0]");
    # Keep the old style, until the next version so that we don't have to retest everything.
    # 
    open(IN, "< $_[0]");
    sysread(IN, $temp, $stat_array[7]);
    close(IN);
    return $temp;
}
