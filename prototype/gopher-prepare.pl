#!/usr/bin/perl -W

use strict;

use File::Copy;
use File::Path;

my($MINSEQLENGTH)=30;
my($HAREA)=20;
my($HMIN)=3;
my($CDHIT_IDENTITY)=0.97;
my($CDHIT_WORD_SIZE)=5;
my($BLAST_PATH)='dc_blastall';
my($BLAST_ALGO)='tera-blastp';
my($KNOWNSEQS_DB)='fusionated';
my($BLAST_EVALUE)=1e-5;
my($BLAST_HITS)=500;

my($PDBPREFILE)='pdbpre.fas';
my($PDBFILE)='pdb.fas';
my($ORIGPRE)='prev-';
my($FILTPRE)='filtered-';
my($SURVPRE)='survivors-';
my($LEADERSPRE)='leaders-';
my($ORIGDB)='original.fas';
my($SURVDB)='survivors.fas';
my($LEADERSDB)='leaders.fas';
my($PDBPREPREFIX)='N';
my($PDBPREFIX)='P';
my($BLASTPOST)='.blast';

my($queryParticle)='Query=';

sub readFASTAHeaders($\@);
sub pruneSequence($;$);
sub filterFASTAFile($$$$);
sub processFASTAPDBDesc($);
sub copyWithPrefix($$$);
sub chooseLeaders($$$$$$$);

sub readFASTAHeaders($\@) {
	my($FH,$p_headers)=@_;
	
	my($line);
	my(@headers)=();
	while($line=<$FH>) {
		# We are only getting the headers
		if(substr($line,0,1) eq '>') {
			chomp($line);

			push(@headers,substr($line,1));
		}
	}
	
	# Sorting headers
	@{$p_headers}=sort(@headers);
}

# This method takes a one-line sequence, and it removes
# histidine heads and/or tails. Optional second parameter
# drives the behavior (undef or 0 is head, 1 is tail, 2 is both).
sub pruneSequence($;$) {
	my($cutseq,$mode)=@_;
	
	if(defined($mode) && $mode>0) {
		if($mode >= 2) {
			return pruneSequence(pruneSequence($cutseq),1);
		}
		
		$cutseq=scalar(reverse($cutseq));
	} else {
		$mode=undef;
	}
	
	if(length($cutseq)>=$MINSEQLENGTH && substr($cutseq,0,$HAREA) =~ /[HX]{$HMIN,}/) {
		# Let's get last match
		substr($cutseq,0,$HAREA) =~ /[HX]{$HMIN,}/g;
		my($lastpos)=$-[0];
		# And now the length
		substr($cutseq,$lastpos) =~ /^[HX]+/;
		# So the pos is...
		my($headpos)=$lastpos+length($&);
		$cutseq=substr($cutseq,$lastpos+length($&));
	}
	
	return defined($mode)?scalar(reverse($cutseq)):$cutseq;
}

sub filterFASTAFile($$$$) {
	my($origFile,$newFile,$filtFile,$analFile)=@_;
	
	my($succeed)=1;
	my($ORIG,$NEW,$FILT,$ANAL);
	
	if(open($ORIG,'<',$origFile)) {
		my(@origheaders)=();
		readFASTAHeaders($ORIG,@origheaders);
		
		# We don't need it any more
		close($ORIG);
		
		if(open($NEW,'<',$newFile)) {
			my(@newheaders)=();
			readFASTAHeaders($NEW,@newheaders);
			
			# Reset file pointer for further usage
			seek($NEW,0,0);
			
			# Now, let's find only new entries
			my($maxorigpos,$maxnewpos)=(scalar(@origheaders),scalar(@newheaders));
			my($origpos,$newpos)=(0,0);
			my(%candidate)=();
			
			while($origpos<$maxorigpos && $newpos<$maxnewpos) {
				if($origheaders[$origpos] eq $newheaders[$newpos]) {
					# Equal, next step!
					$origpos++;
					$newpos++;
				} elsif($origheaders[$origpos] lt $newheaders[$newpos]) {
					# Not skipped yet, next step on original!
					$origpos++;
				} else {
					# Skipped, save and next step on new!
					$candidate{$newheaders[$newpos]}=undef;
					$newpos++;
				}
			}
			
			# Now we know the candidate, let's save them
			if(open($FILT,'>',$filtFile) && open($ANAL,'>',$analFile)) {
				# Let's analyze the sequences, getting the headers
				my($line);
				
				my($description)=undef;
				my($sequence)=undef;
				my($survivor)=undef;
				while($line=<$NEW>) {
					chomp($line);
					if(substr($line,0,1) eq '>') {
						# We have a candidate sequence!
						if(defined($description) && length($sequence)>=$MINSEQLENGTH) {
							my($cutseq)=pruneSequence(uc($sequence),2);
							
							# Has passed the filter?
							if(length($cutseq)>=$MINSEQLENGTH) {
								# Let's save it!
								print $FILT $description,"\n";
								print $FILT $cutseq,"\n";
								if(defined($survivor)) {
									print $ANAL $description,"\n";
									print $ANAL $cutseq,"\n";
								}
							}
						}
						
						# New header is it in the "chosen one" list?
						$description=$line;
						$sequence='';
						if(exists($candidate{substr($line,1)})) {
							$survivor=1;
						} else {
							$survivor=undef;
						}
					} elsif(defined($sequence)) {
						$line =~ tr/ \t//d;
						$sequence .= $line;
					}
				}
				
				if(defined($description) && length($sequence)>=$MINSEQLENGTH) {
					my($cutseq)=pruneSequence(uc($sequence),2);

					# Has passed the filter?
					if(length($cutseq)>=$MINSEQLENGTH) {
						# Let's save it!
						print $FILT $description,"\n";
						print $FILT $cutseq,"\n";
						if(defined($survivor)) {
							print $ANAL $description,"\n";
							print $ANAL $cutseq,"\n";
						}
					}
				}
				
				close($FILT);
				close($ANAL);
			} else {
				warn "ERROR: Unable to create $filtFile or $analFile\n";
				$succeed=undef;
			}
			close($NEW);
		} else {
			warn "ERROR: Unable to open $newFile\n";
			$succeed=undef;
		}
	} else {
		warn "ERROR: Unable to open $origFile\n";
		$succeed=undef;
	}
	
	return $succeed;
}

sub processFASTAPDBDesc($) {
	my($desc)=@_;
	# Now, store
	my($id);
	if($desc =~ /PDB:([^ :]+)[ :]/) {
		$id=$1;
	} else {
		$desc =~ s/^[ \t]+//;
		my($fake);
		($id,$fake)=split(/[ \t]+/,$desc,2);
	}
	
	return $id;
}

sub copyWithPrefix($$$) {
	my($fastaFile,$prefix,$FH)=@_;
	
	my($FASTA);
	
	my(@seqs)=();
	
	if(open($FASTA,'<',$fastaFile)) {
		my($line);
		my($id)=undef;
		my($iddesc)=undef;
		my($sequence)=undef;
		while($line=<$FASTA>) {
			if(substr($line,0,1) eq '>') {
				push(@seqs,[$id,$iddesc,$sequence])  if(defined($id));
				my($desc)=substr($line,1);
				print $FH '>',$prefix,':',$desc;
				
				# Now, store
				$id=processFASTAPDBDesc($desc);
				chomp($desc);
				$iddesc=$desc;
				$sequence='';
			} else {
				print $FH $line;
				chomp($line);
				$sequence.=$line;
			}
		}
		close($FASTA);
		push(@seqs,[$id,$iddesc,$sequence]) if(defined($id));
	} else {
		die "ERROR: Unable to open $fastaFile to prefix it with $prefix!\n";
	}
	
	return \@seqs;
}

sub chooseLeaders($$$$$$$) {
	my($workdir,$origprepdb,$origpdb,$analprepdb,$analpdb,$leadersdb,$leadersReport)=@_;
	
	# First, let's generate common original database
	my($origdb)=$workdir.'/'.$ORIGDB;
	my($survdb)=$workdir.'/'.$SURVDB;
	my($leaderscanddb)=$leadersdb.'.candidate';
	my($ORIGFH);
	
	# Second, let's concatenate all of them
	if(open($ORIGFH,'>',$origdb)) {
		eval {
			copy($origpdb,$ORIGFH);
			copy($origprepdb,$ORIGFH);
		};
		my($err)=$@;
		close($ORIGFH);
		die "ERROR: Unable to concatenate $origpdb and $origprepdb into $origdb due $err\n"  if($err);
		
		my($SURVFH);
		if(open($SURVFH,'>',$survdb)) {
			my($pdbArray)=copyWithPrefix($analpdb,$PDBPREFIX,$SURVFH) || die "ERROR: Unable to concatenate $analpdb to $survdb\n";
			my($pdbPreArray)=copyWithPrefix($analprepdb,$PDBPREPREFIX,$SURVFH) || die "ERROR: Unable to concatenate $analprepdb to $survdb\n";
			close($SURVFH);
			
			my(%survivor)=($PDBPREFIX=>$pdbArray,$PDBPREPREFIX=>$pdbPreArray);
			
			# Now, let's calculate needed memory for clustering
			my($cdmem)=int(((stat($origdb))[7]+(stat($survdb))[7])/(1024*1024)*20+0.5);
			
			# And let's launch cd-hit-2d
			my(@CDHIT2Dparams)=(
				'cd-hit-2d',
				'-i',$origdb,
				'-i2',$survdb,
				'-o',$leaderscanddb,
				'-c',$CDHIT_IDENTITY,
				'-n',$CDHIT_WORD_SIZE,
				'-M',$cdmem
			);
			print STDERR "NOTICE: Launching @CDHIT2Dparams\n";
			system(@CDHIT2Dparams)==0 || die "system @CDHIT2Dparams failed: $?";
			
			my(@CDHITparams)=(
				'cd-hit',
				'-i',$leaderscanddb,
				'-o',$leadersdb,
				'-c',$CDHIT_IDENTITY,
				'-n',$CDHIT_WORD_SIZE,
				'-M',$cdmem
			);
			print STDERR "NOTICE: Launching @CDHITparams\n";
			system(@CDHITparams)==0 || die "system @CDHITparams failed: $?";
			
			# And now, information about the survivors!
			my(@BLASTparams)=(
				$BLAST_PATH,
				'-p',$BLAST_ALGO,
				'-i',$leadersdb,
				'-d',$KNOWNSEQS_DB,
				'-e',$BLAST_EVALUE,
				'-v',$BLAST_HITS,
				'-b',$BLAST_HITS,
			);
			
			# Let's parse!
			my($BLFH);
			my($LEREFH);
			if(open($LEREFH,'>',$leadersReport) && open($BLFH,'-|',@BLASTparams)) {
				my($line);
				my($query)=undef;
				my($gettingQuery)=undef;
				while($line=<$BLFH>) {
					# Saving original report
					print $LEREFH $line;
					
					if(index($line,$queryParticle)==0) {
						# First, let's save the obtained results
						
						# Second, new information
						chomp($line);
						
						$query=substr($line,length($queryParticle));
						$gettingQuery=1;
					} elsif(defined($gettingQuery)) {
						if($line =~ /\([0-9]+ letters?\)/) {
							$gettingQuery=undef;
						} else {
							chomp($line);
							$query.=' '.substr($line,length($queryParticle));
						}
					} elsif(index($line,'***** No hits found ******')!=-1) {
						print "This one is really difficult! $query\n";
						# We need to save here the information to generate the XML report
						$query=undef;
					} elsif(index($line,'Sequences producing significant')==0) {
						print "An easy one: $query\n";
						# We need to save here the information to generate the XML report
						$query=undef;
					}
				}
				close($LEREFH);
				close($BLFH);
			} else {
				die "ERROR: Unable to create $leadersReport or to run @BLASTparams\n";
			}
		} else {
			die "ERROR: Unable to create file $survdb\n";
		}
	} else {
		die "ERROR: Unable to create file $origdb\n";
	}
}

if(scalar(@ARGV)>=5) {
	my($origprepdb)=shift(@ARGV);
	my($newprepdb)=shift(@ARGV);

	my($origpdb)=shift(@ARGV);
	my($newpdb)=shift(@ARGV);
	
	my($workdir)=shift(@ARGV);
	my($first)=undef;
	
	$first=shift(@ARGV)  if(scalar(@ARGV)>0);
	
	# First, time to create workfing directory
	eval {
		mkpath($workdir);
	};
	
	if($@) {
		die "FATAL ERROR: Unable to create directory $workdir due $@\n";
	}
	
	# Second, let's copy the original and new files there
	my($Worigprepdb)=$workdir.'/'.$ORIGPRE.$PDBPREFILE;
	eval {
		copy($origprepdb,$Worigprepdb);
	};
	if($@) {
		die "FATAL ERROR: Unable to copy $origprepdb to $Worigprepdb due $@\n";
	}
	
	my($Worigpdb)=$workdir.'/'.$ORIGPRE.$PDBFILE;
	eval {
		copy($origpdb,$Worigpdb);
	};
	if($@) {
		die "FATAL ERROR: Unable to copy $origpdb to $Worigpdb due $@\n";
	}
	
	my($Wnewprepdb)=$workdir.'/'.$PDBPREFILE;
	eval {
		copy($newprepdb,$Wnewprepdb);
	};
	if($@) {
		die "FATAL ERROR: Unable to copy $newprepdb to $Wnewprepdb due $@\n";
	}
	my($Wnewpdb)=$workdir.'/'.$PDBFILE;
	eval {
		copy($newpdb,$Wnewpdb);
	};
	if($@) {
		die "FATAL ERROR: Unable to copy $newpdb to $Wnewpdb due $@\n";
	}
	
	# These ones are for the next week iteration
	my($Wnewfiltprepdb)=$workdir.'/'.$FILTPRE.$PDBPREFILE;
	my($Wnewfiltpdb)=$workdir.'/'.$FILTPRE.$PDBFILE;
	
	# And these ones are for now!
	my($analprepdb)=$workdir.'/'.$SURVPRE.$PDBPREFILE;
	my($analpdb)=$workdir.'/'.$SURVPRE.$PDBFILE;
	
	if(defined($first)) {
		# To run only the first time
		my($TH);
		# Like 'touch' command
		open($TH,'>',$Wnewfiltprepdb) && close($TH);
		open($TH,'>',$Wnewfiltpdb) && close($TH);
		
		filterFASTAFile($Wnewfiltprepdb,$Worigprepdb,$newprepdb,$analprepdb)  || die "FATAL ERROR: Unable to generate $analprepdb from $Worigprepdb and $Wnewprepdb";
		filterFASTAFile($Wnewfiltpdb,$Worigpdb,$newpdb,$analpdb)  || die "FATAL ERROR: Unable to generate $analpdb from $Worigpdb and $Wnewpdb";
		exit(0);
	} else {
		# Third, easy filtering phase (new only, 30 residues or more after
		# prunning histidines heads and tails)
		filterFASTAFile($Worigprepdb,$Wnewprepdb,$Wnewfiltprepdb,$analprepdb)  || die "FATAL ERROR: Unable to generate $analprepdb from $Worigprepdb and $Wnewprepdb";
		filterFASTAFile($Worigpdb,$Wnewpdb,$Wnewfiltpdb,$analpdb)  || die "FATAL ERROR: Unable to generate $analpdb from $Worigpdb and $Wnewpdb";

		# Fourth, heuristics and difficult filtering phase
		my($leadersdb)=$workdir.'/'.$LEADERSDB;
		my($leadersReport)=$workdir.'/'.$LEADERSDB.$BLASTPOST;
		chooseLeaders($workdir,$origprepdb,$origpdb,$analprepdb,$analpdb,$leadersdb,$leadersReport);

		# my($leadersprepdb)=$workdir.'/'.$LEADERSPRE.$PDBPREFILE;
		# my($leaderspdb)=$workdir.'/'.$LEADERSPRE.$PDBFILE;

		# Fifth, other tools?????
	}
} else {
	print STDERR <<EOF ;
FATAL ERROR: This program needs at least 5 params, in order:

*	The filtered, previous week, PDBPre database file in FASTA format.
*	The unfiltered, current week, PDBPre database file in FASTA format.
*	The filtered, previous week, PDB database file in FASTA format.
*	The unfiltered, current week, PDB database file in FASTA format.
*	The working directory where to store all the results and intermediate files.

	When a sixth optional param is used (the value does not matter), the meaning changes:
	
*	The unfiltered, current week, PDBPre database file in FASTA format.
*	The filtered, current week, PDBPre database file in FASTA format (to be generated).
*	The unfiltered, current week, PDB database file in FASTA format.
*	The filtered, current week, PDB database file in FASTA format (to be generated).
*	The working directory where to store all the intermediate files.
EOF
}
