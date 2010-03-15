#!/usr/bin/perl -W

use strict;

use FindBin;

use lib "$FindBin::Bin";

use CIFDict;

my(%toOneAAGonzalo)=(
'ALA'=>'A','0CS'=>'A','AA3'=>'A','AA4'=>'A','ABA'=>'A','AHO'=>'A','AHP'=>'A','AIB'=>'A',
'ALC'=>'A','ALM'=>'A','ALN'=>'A','ALS'=>'A','APH'=>'A','AYA'=>'A','B2A'=>'A','B3A'=>'A',
'BAL'=>'A','BNN'=>'A','CAB'=>'A','CHG'=>'A','CLB'=>'A','CLD'=>'A','DAB'=>'A','DBU'=>'A',
'DBZ'=>'A','DHA'=>'A','DNP'=>'A','DPP'=>'A','FLA'=>'A','HAC'=>'A','HMF'=>'A','HV5'=>'A',
'IAM'=>'A','KYN'=>'A','LAL'=>'A','MAA'=>'A','NAL'=>'A','NAM'=>'A','NCB'=>'A','ORN'=>'A',
'PAU'=>'A','PRR'=>'A','PYA'=>'A','SEC'=>'A','SEG'=>'A','TIH'=>'A','UMA'=>'A','ARG'=>'R',
'2MR'=>'R','AAR'=>'R','ACL'=>'R','AGM'=>'R','AHB'=>'R','ALG'=>'R','ARM'=>'R','BOR'=>'R',
'DIR'=>'R','HAR'=>'R','HMR'=>'R','HRG'=>'R','MAI'=>'R','MGG'=>'R','NNH'=>'R','OPR'=>'R',
'ORQ'=>'R','ASN'=>'N','AFA'=>'N','B3X'=>'N','DMH'=>'N','MEN'=>'N','ASP'=>'D','2AS'=>'D',
'3MD'=>'D','ACB'=>'D','AEI'=>'D','AKL'=>'D','ASA'=>'D','ASB'=>'D','ASI'=>'D','ASK'=>'D',
'ASL'=>'D','ASQ'=>'D','B3D'=>'D','BFD'=>'D','BHD'=>'D','DMK'=>'D','DOH'=>'D','IAS'=>'D',
'OHS'=>'D','OXX'=>'D','PAS'=>'D','PHD'=>'D','TAV'=>'D','CYS'=>'C','5CS'=>'C','BBC'=>'C',
'BCS'=>'C','BCX'=>'C','BPE'=>'C','BTC'=>'C','BUC'=>'C','C3Y'=>'C','C5C'=>'C','C6C'=>'C',
'CAF'=>'C','CAS'=>'C','CCS'=>'C','CEA'=>'C','CME'=>'C','CMH'=>'C','CMT'=>'C','CS3'=>'C',
'CS4'=>'C','CSA'=>'C','CSB'=>'C','CSD'=>'C','CSE'=>'C','CSO'=>'C','CSP'=>'C','CSR'=>'C',
'CSS'=>'C','CSU'=>'C','CSW'=>'C','CSX'=>'C','CSZ'=>'C','CY0'=>'C','CY1'=>'C','CY3'=>'C',
'CY4'=>'C','CYA'=>'C','CYD'=>'C','CYF'=>'C','CYG'=>'C','CYM'=>'C','CYQ'=>'C','CYR'=>'C',
'CZ2'=>'C','CZZ'=>'C','EFC'=>'C','FOE'=>'C','GT9'=>'C','HTI'=>'C','K1R'=>'C','M0H'=>'C',
'MCS'=>'C','NPH'=>'C','OCS'=>'C','OCY'=>'C','P1L'=>'C','PBB'=>'C','PEC'=>'C','PR3'=>'C',
'PYX'=>'C','R1A'=>'C','R1B'=>'C','R1F'=>'C','R7A'=>'C','SAH'=>'C','SCH'=>'C','SCS'=>'C',
'SCY'=>'C','SHC'=>'C','SIB'=>'C','SMC'=>'C','SNC'=>'C','SOC'=>'C','TNB'=>'C','YCM'=>'C',
'GLN'=>'Q','GHG'=>'Q','GLH'=>'Q','MEQ'=>'Q','MGN'=>'Q','NLQ'=>'Q','GLU'=>'E','5HP'=>'E',
'AR4'=>'E','B3E'=>'E','CGU'=>'E','CRU'=>'E','GAU'=>'E','GGL'=>'E','GLQ'=>'E','GMA'=>'E',
'GSU'=>'E','ILG'=>'E','LME'=>'E','MEG'=>'E','PCA'=>'E','GLY'=>'G','CHP'=>'G','CR5'=>'G',
'CSI'=>'G','FGL'=>'G','GHP'=>'G','GLZ'=>'G','GSC'=>'G','IGL'=>'G','LPG'=>'G','LVG'=>'G',
'MEU'=>'G','MGY'=>'G','MPQ'=>'G','NMC'=>'G','PGY'=>'G','SAR'=>'G','SHP'=>'G','TBG'=>'G',
'HIS'=>'H','3AH'=>'H','DDE'=>'H','HBN'=>'H','HIA'=>'H','HIC'=>'H','HIP'=>'H','HIQ'=>'H',
'HSO'=>'H','MHS'=>'H','NEM'=>'H','NEP'=>'H','NZH'=>'H','PSH'=>'H','PVH'=>'H','ILE'=>'I',
'B2I'=>'I','IIL'=>'I','ILX'=>'I','IML'=>'I','LEU'=>'L','1LU'=>'L','2LU'=>'L','2ML'=>'L',
'BLE'=>'L','BTA'=>'L','BUG'=>'L','CLE'=>'L','DON'=>'L','FLE'=>'L','HLU'=>'L','LED'=>'L',
'LEF'=>'L','MHL'=>'L','MLE'=>'L','MLL'=>'L','MNL'=>'L','NLE'=>'L','NLN'=>'L','NLO'=>'L',
'NLP'=>'L','PLE'=>'L','PPH'=>'L','LYS'=>'K','6CL'=>'K','ALY'=>'K','API'=>'K','APK'=>'K',
'AZK'=>'K','B3K'=>'K','BLY'=>'K','C1X'=>'K','CLG'=>'K','CLH'=>'K','DLS'=>'K','DNL'=>'K',
'DNS'=>'K','GPL'=>'K','I58'=>'K','KCX'=>'K','KST'=>'K','LCX'=>'K','LLP'=>'K','LLY'=>'K',
'LYM'=>'K','LYN'=>'K','LYX'=>'K','LYZ'=>'K','M3L'=>'K','MCL'=>'K','MLY'=>'K','MLZ'=>'K',
'SHR'=>'K','SLZ'=>'K','MET'=>'M','2FM'=>'M','CXM'=>'M','FME'=>'M','KOR'=>'M','MHO'=>'M',
'MME'=>'M','MSE'=>'M','MSL'=>'M','MSO'=>'M','OMT'=>'M','SME'=>'M','PHE'=>'F','1PA'=>'F',
'200'=>'F','23F'=>'F','B1F'=>'F','B2F'=>'F','BIF'=>'F','DAH'=>'F','DPN'=>'F','FCL'=>'F',
'FPA'=>'F','HPC'=>'F','HPE'=>'F','HPQ'=>'F','MEA'=>'F','NFA'=>'F','PBF'=>'F','PCS'=>'F',
'PF5'=>'F','PFF'=>'F','PHA'=>'F','PHI'=>'F','PHL'=>'F','PHM'=>'F','PM3'=>'F','PPN'=>'F',
'PSA'=>'F','SMF'=>'F','PRO'=>'P','2MT'=>'P','4FB'=>'P','DPL'=>'P','H5M'=>'P','HY3'=>'P',
'HYP'=>'P','LPD'=>'P','N7P'=>'P','P2Y'=>'P','PCC'=>'P','POM'=>'P','PRS'=>'P','SER'=>'S',
'B3S'=>'S','BSE'=>'S','CWR'=>'S','DBS'=>'S','FGP'=>'S','HSE'=>'S','HSL'=>'S','LPS'=>'S',
'MC1'=>'S','MIS'=>'S','NC1'=>'S','OAS'=>'S','OSE'=>'S','PG1'=>'S','SAC'=>'S','SBD'=>'S',
'SBL'=>'S','SDP'=>'S','SEB'=>'S','SEL'=>'S','SEP'=>'S','SET'=>'S','SOY'=>'S','SVA'=>'S',
'TNR'=>'S','THR'=>'T','ALO'=>'T','BMT'=>'T','CTH'=>'T','TBM'=>'T','THC'=>'T','TMB'=>'T',
'TMD'=>'T','TPO'=>'T','TRP'=>'W','1TQ'=>'W','4DP'=>'W','4FW'=>'W','4HT'=>'W','6CW'=>'W',
'FT6'=>'W','FTR'=>'W','HRP'=>'W','HTR'=>'W','LTR'=>'W','PAT'=>'W','TOX'=>'W','TPL'=>'W',
'TQQ'=>'W','TRN'=>'W','TRO'=>'W','TRQ'=>'W','TRW'=>'W','TRX'=>'W','TTQ'=>'W','TYR'=>'Y',
'1TY'=>'Y','2TY'=>'Y','B3Y'=>'Y','DBY'=>'Y','FTY'=>'Y','IYR'=>'Y','MBQ'=>'Y','NBQ'=>'Y',
'NIY'=>'Y','NTY'=>'Y','PAQ'=>'Y','PTH'=>'Y','PTM'=>'Y','PTR'=>'Y','STY'=>'Y','TPQ'=>'Y',
'TTS'=>'Y','TYB'=>'Y','TYI'=>'Y','TYN'=>'Y','TYO'=>'Y','TYQ'=>'Y','TYS'=>'Y','TYT'=>'Y',
'TYY'=>'Y','VAL'=>'V','2VA'=>'V','B2V'=>'V','DHN'=>'V','MNV'=>'V','MVA'=>'V','NVA'=>'V',
'VAD'=>'V','VAF'=>'V','UNK'=>'X');

my(@artifacts)=(
	'CLON',		# 'Cloning Artifact'
	'EXPR',		# 'Expression Tag'
	'INIT',		# 'Initiating Methionine'
	'LEADER',	# 'Leader Sequence'
);

my($segsize)=60;

if(scalar(@ARGV)>3) {
	my($destfile)=shift(@ARGV);
	my($artifactsFile)=shift(@ARGV);
	my($cifdict)=shift(@ARGV);
	my(@dirqueue)=@ARGV;
	
	# Let's read CIF dictionary
	my(%toOneAA)=();
	my(%notAA)=();
	CIFDict::loadCIFDict($cifdict,%toOneAA,%notAA)  or die("ERROR: Unable to open CIF dictionary $cifdict");
	
	# Now, let's work!
	my($OUT);
	open($OUT,'>',$destfile)  or die("ERROR: Unable to create FASTA file $destfile");

	my($AFILE);
	open($AFILE,'>',$artifactsFile)  or die("ERROR: Unable to create artifacts info file $artifactsFile");

	# Y ahora vamos parseando cada uno de los directorios de entrada
	foreach my $dirname (@dirqueue) {
		my($DIRH);
		if(opendir($DIRH,$dirname)) {
			my($direntry);
			while($direntry=readdir($DIRH)) {
				next  if($direntry eq '.' || $direntry eq '..');
				my($fullentry)=$dirname.'/'.$direntry;
				if(-d $fullentry) {
					push(@dirqueue,$fullentry);
				} elsif($fullentry =~ /\.ent\.gz$/ || $fullentry =~ /\.ent\.Z$/) {
					my($PDBH);
					if(open($PDBH,'-|','gunzip','-c',$fullentry)) {
						# Ya he abierto el fichero, ¡vamos a leer!

						my($pdbcode)=undef;
						my($current_molid)=undef;
						my(%mols)=();
						my($current_desc)=undef;
						my($compline)=undef;
						my(%chaindescs)=();
						my($title)=undef;
						my($header)=undef;
						my($prev_chain)=undef;
						my($prev_seq)=undef;
						my($prev_subcomp)=undef;
						my($badchain)=undef;
						my($line);
						my($PRINTCMD)=sub {
							if(defined($prev_chain)) {
								if(defined($prev_seq) && !defined($badchain) && !($prev_seq =~ /^X+$/)) {
									print STDERR "BLAMEPDB: $pdbcode\n"  unless(exists($chaindescs{$prev_chain}));
									print $OUT ">PDB:${pdbcode}_${prev_chain} mol:protein length:",length($prev_seq),"  $chaindescs{$prev_chain}\n";
									while(length($prev_seq)>$segsize) {
										print $OUT substr($prev_seq,0,$segsize),"\n";
										$prev_seq=substr($prev_seq,$segsize);
									}
									print $OUT $prev_seq,"\n";
								} else {
									print STDERR "NOTICE: ${pdbcode}_${prev_chain} is not a protein sequence\n";
								}
							}
							$badchain=undef;
						};
						while($line=<$PDBH>) {
							chomp($line);
							# Línea a línea
							if(index($line,'HEADER')==0) {
								my($fheader)=(split(/[ \t]+/,$line,2))[1];
								my(@htoken)=split(/\s+/,$fheader);
								$pdbcode=$htoken[$#htoken];
								$header=join(' ',@htoken[0..($#htoken-2)]);
							} elsif(index($line,'TITLE')==0) {
								if(defined($title)) {
									my($ctitle)=(split(/[ \t]+/,$line,3))[2];
									$ctitle =~ s/[ \t]+$//;
									$title .= ' '.$ctitle;
								} else {
									$title=(split(/[ \t]+/,$line,2))[1];
									$title =~ s/[ \t]+$//;
								}
							} elsif(index($line,'COMPND')==0 || (defined($compline) && index($line,'SOURCE')==0)) {
								my($PROCCOMP)=sub {
									my($ridx)=rindex($compline,';');
									if($ridx!=-1 && $ridx==(length($compline)-1)) {
										$compline=substr($compline,0,$ridx);
										my(@comps)=split(/[ \t]*:[ \t]*/,$compline,2);
										$prev_subcomp=$comps[0];
										my($compdata)=$comps[1];
										if($prev_subcomp eq 'MOL_ID') {
											$current_molid=$compdata;
										} elsif($prev_subcomp eq 'MOLECULE') {
											$current_desc=$compdata;
										} elsif($prev_subcomp eq 'CHAIN') {
											$compdata='NULL'  if(length($compdata)==0);
											foreach my $chain (split(/[ ,]+/,$compdata)) {
												$chain=''  if($chain eq 'NULL');
												$chaindescs{$chain}=$current_desc;
											}
										}
										$compline=undef;
									}
								};
								if(defined($current_molid) || defined($compline)) {
									if(index($line,'SOURCE')==0) {
										$compline .= ';'  if(defined($compline));
									} elsif(defined($compline)) {
										my($pre_compline)=(split(/[ \t]+/,$line,3))[2];
										if(index($pre_compline,':')==-1) {
											$compline .= ' '.(split(/[ \t]+/,$line,3))[2];
										} else {
											$compline .= ';';
											$PROCCOMP->();
											$compline=$pre_compline;
										}
									} else {
										$compline = (split(/[ \t]+/,$line,3))[2];
									}
								} else {
									$compline=(split(/[ \t]+/,$line,2))[1];
									last  if(index($compline,'NULL')==0);
								}
								$compline =~ s/[ \t]+$//;
								$compline =~ tr/\\//d;
								if(index($compline,':')==-1) {
									if(defined($prev_subcomp)) {
										if($prev_subcomp eq 'MOL_ID') {
											$compline=$prev_subcomp.': '.$current_molid.$compline;
										} elsif($prev_subcomp eq 'MOLECULE') {
											$compline=$prev_subcomp.': '.$current_desc.' '.$compline;
										} elsif($prev_subcomp eq 'CHAIN') {
											$compline=$prev_subcomp.': '.$compline;
										} else {
											next;
										}
										#$prev_subcomp=undef;
									} else {
										print STDERR "BLAMEPDB: $pdbcode $compline\n";
									}
								} else {
									$prev_subcomp=undef;
								}
								$PROCCOMP->();
							} elsif(index($line,'SEQADV ')==0) {
								# See PDB manual documentation about SEQADV
								my($conflict)=substr($line,49);
								foreach my $artifact (@artifacts) {
									if(index($conflict,$artifact)==0 || $conflict =~ /\s$artifact/) {
										print $AFILE substr($line,7),"\n";
										last;
									}
								}
							} elsif(index($line,'SEQRES ')==0) {
								my(@seqlines)=split(/\s+/,$line);
								my($localchain);
								my($firstresidue);

								# Primero obtenemos el nombre de la cadena
								if($seqlines[2] =~ /^[0-9]+$/ && !($seqlines[3] =~ /^[0-9]+$/)) {
									# Si el elemento 2 es un número
									# y el elemento 3 no lo es
									# es que no hay nombre de cadena
									$localchain='';
									$firstresidue=3;
								} else {
									$localchain=$seqlines[2];
									$firstresidue=4;
								}

								my($localseq)='';
								foreach my $ires (@seqlines[$firstresidue..($#seqlines)]) {
									if(length($ires)==3) {
									# Por definición en PDB, los aminoácidos se expresan
									# en códigos de 3 letras
										if(exists($toOneAA{$ires})) {
											$localseq .= $toOneAA{$ires};
										} elsif(exists($notAA{$ires})) {
											#if(length($localseq)>0 || (defined($prev_chain) && defined($prev_seq) && $localchain eq $prev_chain && length($prev_seq)>0)) {
												print STDERR "WARNING: Jammed chain: '$ires' in ${pdbcode}_${localchain}\n";
												$localseq .= 'X';
											#} else {
											#	$localseq=undef;
											#	last;
											#}
										} else {
											$localseq .= 'X';
											print STDERR "WARNING: Unknown aminoacid '$ires' in ${pdbcode}_${localchain}!!!\n";
										}
									#} elsif(length($ires)==1) {
									#	# Y los nucleótidos en códigos de una letra
									#	$localseq=undef;
									#	last;
									} else {
										# print STDERR "WARNING: Jammed file: '$ires' in chain '$localchain' in $fullentry\n";
										$localseq=undef;
										last;
									}
								}

								# Por último, guardamos el trozo de secuencia
								# de la cadena
								if(defined($prev_chain) && $localchain eq $prev_chain) {
									if(defined($localseq)) {
										$prev_seq .= $localseq;
									} else {
										$badchain=1;
										$prev_seq=undef;
									}
								} else {
									$PRINTCMD->();
									
									# Now, let's keep the track
									$prev_chain = $localchain;
									if(defined($localseq)) {
										$prev_seq = $localseq;
									} else {
										$prev_seq=undef;
										$badchain=1;
									}
								}
							}
						}
						close($PDBH);
						
						$PRINTCMD->();
					}
				}
			}
			closedir($DIRH);
		} else {
			print STDERR "WARNING: Unable to process directory $dirname\n";
		}
	}
	close($AFILE);
	close($OUT);
} else {
	die <<EOF ;
This program needs:
	* A file where the PDB sequence chains are going to be saved in FASTA format.
	* A file where the interesting artifacts are going to be saved in pseudo SEQADV format (like SEQADV line, without SEQADV particle).
	* The CIF dictionary.
	* and one or more directories populated with PDB entries
EOF
}


