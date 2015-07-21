#!/usr/bin/perl

use strict;
use warnings;
use File::Basename;
use File::Copy;
use File::Path;

use Data::Dumper; # Debug

# Valid options
our $options = "  ".join("\n  ", (
  "target            <filepath|dirpath>",
  "audio    extract  <track1>:<lang1>[,<track2>:<lang2>]",
  "audio    keep     <track1>[,<track2>]",
  "chapter  clean",
  "set      language <track1>:<lang1>[,<track2>:<lang2>]",
  "subtitle add      <lang1>[,<lang2>]",
  "subtitle clean",
  "subtitle extract  <track1>:<lang1>[,<track2>:<lang2>]",
  "subtitle keep     <track1>[,<track2>]",
  "video    extract  <track1>[,<track2>]",
  "info",
  "remux",
  "nobackup",
  "preview",
  ));

# Command masks
our %cmdMask = (
  'audio keep' => {
    'cmd'   => 'mkvmerge -o <OUTPUT> --disable-track-statistics-tags -a <VALUE> <INPUT>',
    },
  'audio extract' => {
    'cmd'   => 'mkvextract tracks <INPUT> <VALUES>',
    'split' => ':',
    'value' => '<ARG0>:<INPUT_NO_EXT>.<ARG1>.audio',
    'postCheckFiles' => [
      '<INPUT_NO_EXT>.<ARG1>.audio',
      ],
    },
  'chapter clean' => {
    'cmd'   => 'mkvpropedit <INPUT> -c \'\'',
    # 'cmd'   => 'mkvmerge -o <OUTPUT> --disable-track-statistics-tags --no-chapters <INPUT>',
    },
  'subtitle keep' => {
    'cmd'   => 'mkvmerge -o <OUTPUT> --disable-track-statistics-tags -s <VALUE> <INPUT>',
    # 'cmd'   => "$0 target <INPUT> subtitle extract <VALUES> subtitle clean subtitle add <ARG1>",
    # 'split' => ':',
    # 'value' => '<ARG0>:<ARG1>',
    },
  'subtitle extract' => {
    'cmd'   => 'mkvextract tracks <INPUT> <VALUES>',
    'split' => ':',
    'value' => '<ARG0>:<INPUT_NO_EXT>.<ARG1>.srt',
    'postCheckFiles' => [
      '<INPUT_NO_EXT>.<ARG1>.srt',
      ],
    },
  'subtitle add' => {
    'cmd'   => 'mkvmerge -o <OUTPUT> <INPUT> --disable-track-statistics-tags <VALUES>',
    'value' => '--default-track 0:0 --language 0:<ARG> <INPUT_NO_EXT>.<ARG>.srt',
    'preCheckFiles' => [
      '<INPUT_NO_EXT>.<ARG>.srt',
      ],
    'postMoveToBackup' => [
      '<INPUT_NO_EXT>.<ARG>.srt',
      ],
    },
  'subtitle clean' => {
    'cmd'   => 'mkvmerge -o <OUTPUT> --disable-track-statistics-tags -S <INPUT>',
    },
  'set language' => {
    'cmd'   => 'mkvmerge <VALUES> <INPUT> -o <OUTPUT>',
    'split' => ':',
    'value' => '--language <ARG0>:<ARG1>',
    },
  'video extract' => {
    'cmd'   => 'mkvextract tracks <INPUT> <VALUES>',
    'value' => '<ARG>:<INPUT_NO_EXT>.<ARG>.video',
    'postCheckFiles' => [
      '<INPUT_NO_EXT>.<ARG>.video',
      ],
    },
  'info' => {
    'cmd'   => $0.' info <INPUT>',
    },
  'remux' => {
    'cmd'   => $0.' remux <INPUT>',
    },
  );

# Usage
our $usage =
  "\nUsage: ".basename($0)." <options>\n".
  "\nOptions:\n".
  $options."\n\n".
  "OBS: remux can't be used with other options!\n\n";

# Test if all the necessary binaries are installed
testDependencies();

# No args?
if( $#ARGV == -1 ) {
  die $usage;
}

# INFO
if( $#ARGV < 2 && $ARGV[0] eq 'info' ) {

  # If no path provided
  die "\nUsage: ".basename($0)." info <filepath|dirpath>\n\n" if $#ARGV == 0 ;

  # If is file
  if( -f $ARGV[1] ) {

    # If invalid file path
    my $isValid = isValidMKV($ARGV[1]);
    die "\nTarget ".$isValid.": \"".$ARGV[1]."\"\n\n" if $isValid ne 'ok';

    # Get info
    my @mediainfo = split("\n\n", `mediainfo "$ARGV[1]"`);
    my $mkvmerge  = `mkvmerge -i "$ARGV[1]"`;

    # Merge mediainfo with mkvmerge
    foreach my $track (@mediainfo) {
      if( $track =~ /^(Video|Audio|Text)/ ) {

        my $trackType = lc($1);
        my $ID = -1;
        my $Language = 'Unknown';

        if( $track =~ /ID[ ]+\: ([0-9]+)\n/ )
          { $ID = $1-1; }
        if( $track =~ /Language[ ]+\: ([a-zA-Z\- ]+)\n/ )
          { $Language = $1; }

        if( $trackType eq 'text' )
          { $trackType = 'subtitles'; }

        $mkvmerge =~ s/(Track ID $ID: $trackType .*)\n/$1 ($Language)\n/;
      }
    }

    die $mkvmerge;
  }

  # If is dir
  else { if( -d $ARGV[1] ) {

    my $file = '';
    my @validFiles = ();

    # If dir doesn't have '/' ending
    if( $ARGV[1] !~ /\/$/ ) {
      $ARGV[1] .= '/';
    }

    # Parse files in dir
    opendir(DIR, $ARGV[1]) or die $!;
    while( $file = readdir(DIR) ) {

      # Skip invalid files
      next if( $file =~ m/^\./ || isValidMKV($ARGV[1].$file) ne 'ok' );

      push(@validFiles, $ARGV[1].$file);
    }
    closedir(DIR);

    # If no valid files found
    if( !@validFiles ) {
      die "\nThere are no MKV files in \"".$ARGV[1]."\"\n\n";
    }

    # Launch info for each file
    foreach $file (@validFiles) {
      print "\n";
      system($0." info '".$file."'");
    }

    die "\n";
  } }

  die "Invalid path: \"".$ARGV[1]."\"";
}

# REMUX
if( $#ARGV < 2 && $ARGV[0] eq 'remux' ) {

  # If no path provided
  die "\nUsage: ".basename($0)." remux <filepath>\n\n" if $#ARGV == 0 ;

  # If invalid file path
  my $isValid = isValidMKV($ARGV[1]);
  die "\nTarget ".$isValid.": \"".$ARGV[1]."\"\n\n" if $isValid ne 'ok';

  # Get info
  my @info = split("\n", `mkvmerge -i "$ARGV[1]"`);

  # Input file without extension (for result checking)
  my $inputNoExt = $ARGV[1];
  $inputNoExt =~ s/\.mkv$//i;

  # Demux input file
  my @video    = [];
  my @audio    = [];
  my @subtitle = [];
  foreach my $track (@info) {
    if( $track =~ /^.*Track ID ([0-9]+): ([a-zA-Z]+) .*/ ) {

      my $id = $1;
      my $type = $2;

      my $ext = $type;
      if( $type eq 'subtitles' ) {
        $type = 'subtitle';
        $ext = 'srt';
      }

      my $extractedFile = $inputNoExt.'.'.$id.'.'.$ext;

      # print "Extracting $type with id $id...\n";

      # VIDEO
      if( $type eq 'video' ) {
        system("$0 $type extract $id target \"$ARGV[1]\"");
        push(@video, $extractedFile);
      }

      # AUDIO
      else { if( $type eq 'audio' ) {
        system("$0 $type extract $id:$id target \"$ARGV[1]\"");
        push(@audio, $extractedFile);
      }

      # SUBTITLE
      else { if( $type eq 'subtitle' ) {
        system("$0 $type extract $id:$id target \"$ARGV[1]\"");
        push(@subtitle, $extractedFile);
      }}}

      # Test if file got extracted
      if( ! -f $extractedFile ) {
        die "\nERR: Could not extract \"$extractedFile\"\n\n";
      }
    }
  }

  # Generate remux ordered file list
  my @demuxed = [];
  shift(@video);    foreach my $file (@video)    { push(@demuxed, $file); }
  shift(@audio);    foreach my $file (@audio)    { push(@demuxed, $file); }
  shift(@subtitle); foreach my $file (@subtitle) { push(@demuxed, $file); }
  shift(@demuxed);

  my $output = $inputNoExt.'.remux.mkv';
  my $remux = 'mkvmerge -o "'.$output.'" "'.join('" "', @demuxed).'"';
  print "\nREMUX into $output\n\n";
  system($remux);

  die "\nERR: Couldn't remux files!\n\n" if( ! -f $output );

  print "\nREMUX DONE!\n\nRemoving demuxed parts:\n";
  foreach my $file (@demuxed) {
    print "unlink($file)\n";
    unlink($file)
      or die "\nERR: Couldn't delete demuxed file: $!\n\n";
  }

  # Input file basename
  my $inputBasename = basename($ARGV[1]);

  # Create backup dir
  my $backupDir = $ARGV[1];
  $backupDir =~ s/$inputBasename$/backup\//;
  if( ! -d $backupDir ) {
    print "\nmkdir $backupDir\n";
    mkdir $backupDir
      or die "\nERR: Couldn't create backup dir: $!\n\n";
  }

  # Backup input file
  my $backup = $backupDir.$inputBasename;
  if( ! -f $backup ) {
    print "\nmove(".$ARGV[1].", ".$backup.")\n";
    move($ARGV[1], $backup)
      or die "\nERR: Couldn't backup file: $!\n\n";
  }
  # Delete input file if backup exists
  else {
    print "\nunlink($ARGV[1])\n";
    unlink($ARGV[1])
      or die "\nERR: Couldn't delete input file: $!\n\n";
  }

  # Rename output file
  print "\nmove(".$output.", ".$ARGV[1].")\n";
  move($output, $ARGV[1])
    or die "\nERR: Couldn't rename output file: $!\n\n";

  # Print remuxed file info
  print "\nREMUX INFO:\n\n";
  system("$0 info \"$ARGV[1]\"");

  die "\nDONE\n\n";
}

# Trim string
sub trim($) {
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}

# Generate validOptions
sub generateValidOptionsFromUsage {
  my %validOptions = ();

  my @opts = split("\n", $options);
  for( my $i = 0; $i <= $#opts; $i++ ) {

    my @opt = split(/[ ]+/, trim($opts[$i]));

    if( defined($opt[1]) && $opt[1] !~ /</ ) {
      $validOptions{ $opt[0] }{ $opt[1] } = 0;
      next;
    }

    $validOptions{ $opt[0] } = 0;
  }

  return %validOptions;
}

# Get option usage
sub optionUsage {
  my $opts = join("\n", grep(/ $_[0] /, split("\n",$options)));
  if( defined($_[1]) ) {
    $opts = join("\n", grep(/ $_[1] /, split("\n",$opts)));
  }
  return $opts;
}

# Exit with option usage
sub exitOptionUsage {
  die "\nUsage of \"".join(" ", @_)."\":\n".optionUsage(@_)."\n\n";
}

# Check if option requires values
sub optionRequiresOpt {
  my $nr = pop(@_);
  my @syntax = split(/[ ]+/, optionUsage(@_));
  return defined($syntax[$nr]);
}

# Check if all commands have masks
sub testIfAllCommandsAreValid {
  for( my $i = 0; $i <= $#_; $i++ ) {
    if( !defined($cmdMask{ $_[$i]{'type'} }) ) {
      die "\nERR: There's no command mask defined for: \"".$_[$i]{'type'}."\"\n\n";
    }
  }
}

# Check if all the necessary binaries are installed
sub testDependencies {
  foreach my $key (keys %main::cmdMask) {
    if( $main::cmdMask{$key}{'cmd'} =~ /^([^\s]+\s).*/ ) {
      if( `which $1` eq '' ) {
        die "\nDependency missing: ".$1."\n\n";
      }
    }
  }
}

# Check if the received path is a valid mkv file
sub isValidMKV {
  if( ! -f $_[0] ) { return "is not a file"; }
  if( $_[0] !~ /\.mkv$/i ) { return "doesn't have .mkv extension"; }
  if( -s $_[0] == 0 ) { return "is an empty file"; }
  if( `file $_[0]` !~ /matroska/i ) { return "is not a matroska file"; }
  return 'ok';
}

# Select targeted files
sub targetFiles {

  # If wildcard is present
  # if( $_[0] =~ /\*/ ) {
  #   die "\nYou can't use wildcards in target path: \"".$_[0]."\"\n\n";
  # }

  # If is file
  if( -f $_[0] ) {
    my $isValid = isValidMKV($_[0]);
    if( $isValid ne "ok" ) {
      die "\nTarget ".$isValid.": \"".$_[0]."\"\n\n";
    }
    push(@main::files, $_[0]);
    return 0;
  }

  # If is dir
  if( -d $_[0] ) {

    my $file = '';
    my @validFiles = ();

    # If dir hasn't '/' ending
    if( $_[0] !~ /\/$/ ) {
      $_[0] .= '/';
    }

    # Parse files in dir
    opendir(DIR, $_[0]) or die $!;
    while( $file = readdir(DIR) ) {

      # Skip invalid files
      next if( $file =~ m/^\./ || isValidMKV($_[0].$file) ne 'ok' );

      push(@validFiles, $_[0].$file);
    }
    closedir(DIR);

    # If no valid files found
    if( !@validFiles ) {
      die "\nThere are no MKV files in \"".$_[0]."\"\n\n";
    }

    # Append file paths
    foreach $file (@validFiles) {
      push(@main::files, $file);
    }
    return 0;
  }

  die "\nInvalid target path: \"".$_[0]."\"\n\n";
}

# Append command to the list
sub appendCmd {
  my %cmd = (
    'type' => $_[0],
    'mask' => $main::cmdMask{ $_[0] },
    'args' => $_[1],
    );
  push(@main::cmds, \%cmd);
}

# Test options and generate commands
sub parseArgs {

  my %validOpts = generateValidOptionsFromUsage();

  for( my $arg = 0; $arg <= $#ARGV; $arg++ ) {

    # Test option
    if( !defined($validOpts{ $ARGV[$arg] }) ) {
        die "\nERR: Unknown option: ".$ARGV[$arg]."\n".$usage;
    }

    # Mark preview if neccesary
    if( $ARGV[$arg] eq 'preview' ) {
      $main::preview = 1;
      next;
    }

    # Mark nobackup if neccesary
    if( $ARGV[$arg] eq 'nobackup' ) {
      $main::nobackup = 1;
      next;
    }

    # Set target files
    if( $ARGV[$arg] eq "target" ) {
      if( !defined($ARGV[$arg+1]) ) {
        exitOptionUsage($ARGV[$arg]);
      }
      targetFiles($ARGV[$arg+1]);
      $arg++;
      next;
    }

    # If there's no suboption required
    if( !optionRequiresOpt($ARGV[$arg], 1) ) {
      appendCmd($ARGV[$arg], '');
      next;
    }

    # Test suboption
    if( !defined($ARGV[$arg+1]) ||
        !defined($validOpts{ $ARGV[$arg] }{ $ARGV[$arg+1] }) ) {
      exitOptionUsage($ARGV[$arg]);
    }

    # If there's no value required
    if( !optionRequiresOpt($ARGV[$arg], $ARGV[$arg+1], 2) ) {
      appendCmd($ARGV[$arg]." ".$ARGV[$arg+1], '');
      $arg++;
      next;
    }

    # Test value
    if( !defined($ARGV[$arg+2]) ) {
      exitOptionUsage($ARGV[$arg], $ARGV[$arg+1]);
    }

    # If got values
    appendCmd($ARGV[$arg]." ".$ARGV[$arg+1], $ARGV[$arg+2]);
    $arg += 2;
  }

  # Test if all cmds are valid
  testIfAllCommandsAreValid(@main::cmds);
}

# PRE/POST File Checks
sub checkFiles {

  my $type = $_[0]."CheckFiles";
  my $c    = $_[1];

  if( !defined($main::cmds[$c]{'mask'}{$type}) ) {
    return 1;
  }

  my @masks = @{$main::cmds[$c]{'mask'}{$type}};

  for( my $cf = 0; $cf <= $#masks; $cf++ ) {

    my $fileMask = $masks[$cf];

    $fileMask =~ s/<INPUT>/$_[2]/g;
    $fileMask =~ s/<OUTPUT>/$_[3]/g;
    $fileMask =~ s/<INPUT_NO_EXT>/$_[4]/g;

    # Single value
    if( $main::cmds[$c]{'mask'}{'cmd'} =~ /<VALUE>/ ) {
      $fileMask =~ s/<VALUE>/$main::cmds[$c]{'args'}/g;

      if( ! -f $fileMask ) {
        if( $_[0] eq 'pre' ) {
          print "\nERR: Can't execute command. Missing file: \"".$fileMask."\"\n\n";
        }
        else {
          print "\nERR: File not generated: \"".$fileMask."\"\n\n";
        }
        return 0;
      }
    }

    # Multiple values
    else { if( $main::cmds[$c]{'mask'}{'cmd'} =~ /<VALUES>/ ) {

      my @args = split(",", $main::cmds[$c]{'args'});
      for( my $a = 0; $a <= $#args; $a++ ) {

        my $fileMaskPerArg = $fileMask;

        # If arg needs splitting
        if( defined($main::cmds[$c]{'mask'}{'split'}) ) {
          my @subargs = split($main::cmds[$c]{'mask'}{'split'}, $args[$a]);
          for( my $sa = 0; $sa <= $#subargs; $sa++ ) {
            $fileMaskPerArg =~ s/<ARG$sa>/$subargs[$sa]/g;
          }
        }
        else {
          $fileMaskPerArg =~ s/<ARG>/$args[$a]/g;
        }

        if( ! -f $fileMaskPerArg ) {
          if( $_[0] eq 'pre' ) {
            print "\nERR: Can't execute command. Missing file: \"".$fileMaskPerArg."\"\n\n";
          }
          else {
            print "\nERR: File not generated: \"".$fileMaskPerArg."\"\n\n";
          }
          return 0;
        }
      }
    } }
  }
  return 1;
}

# PRE/POST Move files to backup dir
sub moveToBackup {

  my $type      = $_[0]."MoveToBackup";
  my $c         = $_[1];
  my $backupDir = $_[5];

  if( !defined($main::cmds[$c]{'mask'}{$type}) ) {
    return 1;
  }

  my @masks = @{$main::cmds[$c]{'mask'}{$type}};

  for( my $cf = 0; $cf <= $#masks; $cf++ ) {

    my $fileMask = $masks[$cf];

    $fileMask =~ s/<INPUT>/$_[2]/g;
    $fileMask =~ s/<OUTPUT>/$_[3]/g;
    $fileMask =~ s/<INPUT_NO_EXT>/$_[4]/g;

    # Single value
    if( $main::cmds[$c]{'mask'}{'cmd'} =~ /<VALUE>/ ) {
      $fileMask =~ s/<VALUE>/$main::cmds[$c]{'args'}/g;

      if( -f $fileMask ) {
        print "\nmove(".$fileMask.", ".$backupDir.basename($fileMask).")\n";
        move($fileMask, $backupDir.basename($fileMask))
          or die "\nERR: Couldn't backup file: $!\n\n";
      }
    }

    # Multiple values
    else { if( $main::cmds[$c]{'mask'}{'cmd'} =~ /<VALUES>/ ) {

      my @args = split(",", $main::cmds[$c]{'args'});
      for( my $a = 0; $a <= $#args; $a++ ) {

        my $fileMaskPerArg = $fileMask;

        # If arg needs splitting
        if( defined($main::cmds[$c]{'mask'}{'split'}) ) {
          my @subargs = split($main::cmds[$c]{'mask'}{'split'}, $args[$a]);
          for( my $sa = 0; $sa <= $#subargs; $sa++ ) {
            $fileMaskPerArg =~ s/<ARG$sa>/$subargs[$sa]/g;
          }
        }
        else {
          $fileMaskPerArg =~ s/<ARG>/$args[$a]/g;
        }

        if( -f $fileMaskPerArg ) {
          print "\nmove(".$fileMaskPerArg.", ".$backupDir.basename($fileMaskPerArg).")\n";
          move($fileMaskPerArg, $backupDir.basename($fileMaskPerArg))
            or die "\nERR: Couldn't backup file: $!\n\n";
        }
      }
    } }
  }
}

# Execute commands for each file
sub executeCommands {

  my @files    = @main::files;
  my @cmds     = @main::cmds;
  my $preview  = $main::preview;
  my $nobackup = $main::nobackup;

  # For each file
  for( my $f = 0; $f <= $#files; $f++ ) {

    my $inputNoExt = my $input = $files[$f];
    $inputNoExt =~ s/\.mkv$//i;
    my $output = $inputNoExt.".out.mkv";
    my $inputBasename = basename($input);

    if( $#files > 0 ) {
      print "\n\n================================================================================\n";
    }

    # For each command mask
    for( my $c = 0; $c <= $#cmds; $c++ ) {

      # Print file
      print "\nMKV: ".$input;

      # Print option
      print "\nOPT: ".$cmds[$c]{'type'};
      if( defined($cmds[$c]{'args'}) ) {
        print " ".$cmds[$c]{'args'};
      }

      # Command mask
      my $cmd = $cmds[$c]{'mask'}{'cmd'};

      # If value required and no args received
      if( $cmd =~ /<VALUE[S]?>/ && !defined($cmds[$c]{'args'}) ) {
        die "\nERR: args not provided for command mask:\n".$cmd."\n\n";
      }
      
      # If single value required
      if( $cmd =~ /<VALUE>/ ) {
        $cmd =~ s/<VALUE>/$cmds[$c]{'args'}/g;
      }

      # If multiple values required
      else { if( $cmd =~ /<VALUES>/ ) {
        my @values = ();

        my @args = split(",", $cmds[$c]{'args'});
        for( my $a = 0; $a <= $#args; $a++ ) {

          my $valueMask = $cmds[$c]{'mask'}{'value'};

          # If arg needs splitting
          if( defined($cmds[$c]{'mask'}{'split'}) ) {
            my @subargs = split($cmds[$c]{'mask'}{'split'}, $args[$a]);
            for( my $sa = 0; $sa <= $#subargs; $sa++ ) {
              $valueMask =~ s/<ARG$sa>/$subargs[$sa]/g;
              $cmd =~ s/<ARG$sa>/$subargs[$sa]/g;
            }
          }
          else {
            $valueMask =~ s/<ARG>/$args[$a]/g;
            $cmd =~ s/<ARG>/$args[$a]/g;
          }

          push(@values, $valueMask);
        }

        my $join = ' ';
        if( defined($cmds[$c]{'mask'}{'join'}) ) {
          $join = $cmds[$c]{'mask'}{'join'};
        }

        my $finalValues = join($join, @values);
        $cmd =~ s/<VALUES>/$finalValues/g;
      } }

      # Set input
      $cmd =~ s/<INPUT>/$input/g;

      # Set inputNoExt
      $cmd =~ s/<INPUT_NO_EXT>/$inputNoExt/g;

      # Set output
      my $cmdHasOutputFile = 0;
      if( $cmd =~ /<OUTPUT>/ ) {
        $cmd =~ s/<OUTPUT>/$output/g;
        $cmdHasOutputFile = 1;
      }

      # Print command
      print "\nCMD: ".$cmd."\n";

      # Test if all variables are replaced
      if( $cmd =~ /<[A-Z\_]+>/ ) {
        die "ERR: Could not replace all variables in command mask!\n\n";
      }

      # Execute command
      if( !$preview ) {
        print "\n";

        # Set backup dir
        my $backupDir = $input;
        $backupDir =~ s/$inputBasename$/backup\//;
        my $backup = $backupDir.$inputBasename;

        # PRE File Checks
        next if !checkFiles('pre', $c, $input, $output, $inputNoExt);

        # PRE Move Files to Backup
        moveToBackup('pre', $c, $input, $output, $inputNoExt, $backupDir);

        # Execute command
        system($cmd);

        # If command should generate output file
        if( $cmdHasOutputFile ) {

          # If output was generated
          if( -f $output ) {

            # Backup
            if( !$nobackup ) {

              # Backup input file if not done already
              if( ! -f $backup ) {

                # Create backup dir
                if( ! -d $backupDir ) {
                  print "\nmkdir $backupDir\n";
                  mkdir $backupDir
                    or die "\nERR: Couldn't create backup dir: $!\n\n";
                }

                # Copy input file to the backup dir
                print "\nmove($input, $backup)\n";
                move($input, $backup)
                  or die "\nERR: Couldn't backup input file: $!\n\n";
              }
            }

            # Remove input file (if exists - it's moved when backup is done)
            if( -f $input ) {
              print "\nunlink($input)\n";
              unlink($input)
                or die "\nERR: Couldn't delete input file: $!\n\n";
            }

            # Replace input file with the output
            print "\nmove($output, $input)\n";
            move($output, $input)
              or die "\nERR: Couldn't rename output file: $!\n\n";
          }
          else {
            die "\nERR: \"".$output."\" was not generated!\n\n";
          }
        }

        # POST File Checks
        next if !checkFiles('post', $c, $input, $output, $inputNoExt);

        # POST Move Files to Backup
        moveToBackup('post', $c, $input, $output, $inputNoExt, $backupDir);
      }
    }
  }

  print "\n";
}

# Declare vars
our @cmds       = ();
our @files      = ();
our $preview    = 0;
our $nobackup   = 0;

# Parse args, test options, generate commands, select files
parseArgs();

# If no commands generated
if( !@cmds ) {
  die $usage;
}

# If no file selected set current dir
if( !@files ) {
  targetFiles('./');
}

# Execute commands (or preview if required)
executeCommands();

# Success message
print "Done!\n\n";
