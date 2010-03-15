#!/usr/bin/perl -W

use strict;

package CIFDict;

sub loadCIFDict($\%\%);

sub loadCIFDict($\%\%) {
	my($cifdict,$p_toOneAA,$p_notAA)=@_;
	
	# Let's read CIF dictionary
	my(%toOneAA)=();
	my(%notAA)=();
	my($DICT);
	unless(open($DICT,'<',$cifdict)) {
		warn("ERROR: Unable to open CIF dictionary $cifdict");
		return undef;
	}
	my($line);
	my($ispep)=undef;
	my($isamb)=undef;
	my($onelet)=undef;
	my($threelet)=undef;
	my(@parents)=();
	while($line=<$DICT>) {
		# '_chem_comp.type' => if($type eq 'ATOMP' || $type eq 'L-PEPTIDE LINKING');
		# '_chem_comp.pdbx_type' => if($type eq 'ATOMP' || $type eq 'L-PEPTIDE LINKING');
		if(index($line,'_chem_comp.type')==0 || index($line,'_chem_comp.pdbx_type')==0) {
			chomp($line);
			if(defined($ispep) && defined($threelet)) {
				# Let's save it!
				#if(defined($isamb)) {
				#	print STDERR "Warning: aminoacid $threelet is ambiguous (one letter $onelet, parents @parents)\n";
				#}
				$toOneAA{$threelet}=($onelet eq '?')?((scalar(@parents)>0)?[@parents]:'X'):$onelet;
				#print STDERR "Notice: aminoacid $threelet is $onelet\n";
			}
			
			my($first,$type)=split(/[ \t]+/,$line,2);
			$type=uc($type);
			$type =~ tr/"'//d;
			
			$type =~ s/[ \t]+$//;
			
			if($first eq '_chem_comp.type') {
				$ispep = ($type eq 'ATOMP' || $type eq 'L-PEPTIDE LINKING')?1:undef;
			} else {
				$ispep ||= ($type eq 'ATOMP' || $type eq 'L-PEPTIDE LINKING')?1:undef;
			}
			$isamb=undef;
			$onelet=undef;
			$threelet=undef;
			@parents=();
		} elsif(!defined($ispep) && index($line,'_chem_comp.three_letter_code')==0) {
			chomp($line);
			my($first,$elem)=split(/[ \t]+/,$line,2);
			$elem=uc($elem);
			$elem =~ tr/"'//d;
			
			$elem =~ s/[ \t]+$//;
			$notAA{$elem}=undef;
		} elsif(defined($ispep)) {
			if(
				index($line,'_chem_comp.pdbx_ambiguous_flag')==0 ||
				index($line,'_chem_comp.one_letter_code')==0 ||
				index($line,'_chem_comp.three_letter_code')==0 ||
				index($line,'_chem_comp.mon_nstd_parent_comp_id')==0 ||
				index($line,'_chem_comp.pdbx_replaced_by')==0
			) {
				chomp($line);
				my($first,$elem)=split(/[ \t]+/,$line,2);
				$elem=uc($elem);
				$elem =~ tr/"'//d;
				
				$elem =~ s/[ \t]+$//;
				if($first eq '_chem_comp.pdbx_ambiguous_flag') {
					$isamb=1  if($elem ne 'N');
				} elsif($first eq '_chem_comp.one_letter_code') {
					$onelet=$elem;
				} elsif($first eq '_chem_comp.three_letter_code') {
					$threelet=$elem;
				} elsif($first eq '_chem_comp.mon_nstd_parent_comp_id') {
					@parents=split(/[ ,]+/,$elem);
					@parents=()  if($parents[0] eq '?');
				} elsif($first eq '_chem_comp.pdbx_replaced_by') {
					@parents=($elem)  if($elem ne '?' && scalar(@parents)==0);
				}
			}
		}
	}
	close($DICT);
	
	if(defined($ispep) && defined($threelet)) {
		# Let's save it!
		#if(defined($isamb)) {
		#	print STDERR "Warning: aminoacid $threelet is ambiguous (one letter $onelet, parents @parents)\n";
		#}
		$toOneAA{$threelet}=($onelet eq '?')?((scalar(@parents)>0)?[@parents]:'X'):$onelet;
		#print STDERR "Notice: aminoacid $threelet is $onelet\n";
	}
	
	while(my($key,$val)=each(%toOneAA)) {
		my($one);
		if(ref($val) eq 'ARRAY') {
			my($tval)=$val;
			my($alt);
			do {
				$alt=(scalar(@{$tval})>0)?$tval->[0]:'UNK';
				$tval=exists($toOneAA{$alt})?$toOneAA{$alt}:'X';
			} while(ref($tval) eq 'ARRAY');
			$toOneAA{$key}=$tval;
		#	print STDERR "$key interpreted as $alt\n";
		#	$one=$tval;
		#} else {
		#	$one=$val;
		}
		#print STDERR "$key is $one\n";
	}
	
	# Last, setting up the hashes!
	@{$p_toOneAA}{keys(%toOneAA)}=values(%toOneAA);
	@{$p_notAA}{keys(%notAA)}=values(%notAA);
	
	return 1;
}


1;
