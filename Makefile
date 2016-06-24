REFS = data/references
FIGS = results/figures
TABLES = results/tables
PROC = data/process
FINAL = submission/

# utility function to print various variables. For example, running the
# following at the command line:
#
#	make print-BAM
#
# will generate:
#	BAM=data/raw_june/V1V3_0001.bam data/raw_june/V1V3_0002.bam ...
print-%:
	@echo '$*=$($*)'



################################################################################
#
# Part 1: Get the references
#
# We will need several reference files to complete the analyses including the
# SILVA reference alignment and RDP reference taxonomy.
#
################################################################################

# We want the latest greatest reference alignment and the SILVA reference
# alignment is the best reference alignment on the market. This version is from
# v123 and described at http://blog.mothur.org/2015/12/03/SILVA-v123-reference-files/
# We will use the SEED v. 123, which contain 12,083 bacterial sequences. This
# also contains the reference taxonomy. We will limit the databases to only
# include bacterial sequences.

$(REFS)/silva.seed.align :
	wget -N http://mothur.org/w/images/1/15/Silva.seed_v123.tgz
	tar xvzf Silva.seed_v123.tgz silva.seed_v123.align silva.seed_v123.tax
	mothur "#get.lineage(fasta=silva.seed_v123.align, taxonomy=silva.seed_v123.tax, taxon=Bacteria);degap.seqs(fasta=silva.seed_v123.pick.align, Wprocessors=8)"
	mv silva.seed_v123.pick.align $(REFS)/silva.seed.align
	rm Silva.seed_v123.tgz silva.seed_v123.*

$(REFS)/silva.v4.align : $(REFS)/silva.seed.align
	mothur "#pcr.seqs(fasta=$(REFS)/silva.seed.align, start=11894, end=25319, keepdots=F, processors=8)"
	mv $(REFS)/silva.seed.pcr.align $(REFS)/silva.v4.align

# Next, we want the RDP reference taxonomy. The current version is v10 and we
# use a "special" pds version of the database files, which are described at
# http://blog.mothur.org/2014/10/28/RDP-v10-reference-files/

$(REFS)/trainset14_032015.% :
	wget -N http://www.mothur.org/w/images/8/88/Trainset14_032015.pds.tgz
	tar xvzf Trainset14_032015.pds.tgz trainset14_032015.pds/trainset14_032015.pds.*
	mv trainset14_032015.pds/* $(REFS)/
	rmdir trainset14_032015.pds
	rm Trainset14_032015.pds.tgz

$(REFS)/HMP_MOCK.fasta :
	wget --no-check-certificate -N -P $(REFS) https://raw.githubusercontent.com/SchlossLab/Kozich_MiSeqSOP_AEM_2013/master/data/references/HMP_MOCK.fasta

#align the mock community reference sequeces
$(REFS)/HMP_MOCK.v4.fasta : $(REFS)/HMP_MOCK.fasta $(REFS)/silva.v4.align
	mothur "#align.seqs(fasta=$(REFS)/HMP_MOCK.fasta, reference=$(REFS)/silva.v4.align);\
			degap.seqs()";\
	mv $(REFS)/HMP_MOCK.ng.fasta $(REFS)/HMP_MOCK.v4.fasta;\
	rm $(REFS)/HMP_MOCK.align;\
	rm $(REFS)/HMP_MOCK.align.report;\
	rm $(REFS)/HMP_MOCK.flip.accnos


################################################################################
#
# Part 2: Run data through mothur
#
#	Process fastq data through the generation of files that will be used in the
# overall analysis.
#
################################################################################


BASIC_STEM = data/mothur/gf_cdiff.trim.contigs.good.unique.good.filter.unique.precluster
NSEQS=2000



# here we go from the raw fastq files and the files file to generate a fasta,
# taxonomy, and count_table file that has had the chimeras removed as well as
# any non bacterial sequences
$(BASIC_STEM).denovo.uchime.pick.pick.count_table $(BASIC_STEM).pick.pick.fasta $(BASIC_STEM).pick.pds.wang.pick.taxonomy : code/get_good_seqs.batch\
										data/references/silva.v4.align\
										data/references/trainset14_032015.pds.fasta\
										data/references/trainset14_032015.pds.tax\
										data/raw/gf_cdiff.files
	mothur code/get_good_seqs.batch;\
	rm data/mothur/*.map



# here we go from the good sequences and generate a shared file and a
# cons.taxonomy file based on OTU data
$(BASIC_STEM).pick.pick.pick.an.unique_list.shared $(BASIC_STEM).pick.pick.pick.an.unique_list.0.03.cons.taxonomy : code/get_shared_otus.batch\
										$(BASIC_STEM).denovo.uchime.pick.pick.count_table\
										$(BASIC_STEM).pick.pick.fasta\
										$(BASIC_STEM).pick.pds.wang.pick.taxonomy
	mothur code/get_shared_otus.batch
	rm $(BASIC_STEM).denovo.uchime.pick.pick.pick.count_table
	rm $(BASIC_STEM).pick.pick.pick.fasta
	rm $(BASIC_STEM).pick.pds.wang.pick.pick.taxonomy;



# now we want to get the sequencing error as seen in the mock community samples
$(BASIC_STEM).pick.pick.pick.error.summary : code/get_error.batch\
										$(BASIC_STEM).denovo.uchime.pick.pick.count_table\
										$(BASIC_STEM).pick.pick.fasta\
										$(REFS)/HMP_MOCK.v4.fasta
	mothur code/get_error.batch



# Generate subsampled shared file
$(BASIC_STEM).pick.pick.pick.an.unique_list.0.03.subsample.shared : $(BASIC_STEM).pick.pick.pick.an.unique_list.shared
	mothur "#sub.sample(shared=$(BASIC_STEM).pick.pick.pick.an.unique_list.shared, label=0.03, size=$(NSEQS));"


# Generate subsampled distance matrix
$(BASIC_STEM).pick.pick.pick.an.unique_list.thetayc.0.03.lt.ave.dist : $(BASIC_STEM).pick.pick.pick.an.unique_list.shared
	mothur "#dist.shared(shared=$^, calc=thetayc, label=0.03, subsample=$(NSEQS), iters=100, processors=8)"


# Run alpha diversity analysis
$(BASIC_STEM).pick.pick.pick.an.unique_list.groups.ave-std.summary : $(BASIC_STEM).pick.pick.pick.an.unique_list.shared.pick.pick.pick.an.unique_list.shared
	mothur "#summary.single(shared=$(BASIC_STEM).pick.pick.pick.an.unique_list.shared, calc=nseqs-sobs-shannon-invsimpson-coverage, subsample=$(NSEQS))"



################################################################################
#
# Part 3: Figure and table generation
#
#	Run scripts to generate figures and tables
#
################################################################################



################################################################################
#
# Part 4: Pull it all together
#
# Render the manuscript
#
################################################################################


$(FINAL)/study.% : 			\ #include data files that are needed for paper
						$(FINAL)/peerj.csl\
						$(FINAL)/references.bib\
						$(FINAL)/study.Rmd
	R -e 'render("$(FINAL)/study.Rmd", clean=FALSE)'
	mv $(FINAL)/study.knit.md $@
	rm $(FINAL)/study.utf8.md

write.paper : $(TABLES)/table_1.pdf $(TABLES)/table_2.pdf\ #customize to include
				$(FIGS)/figure_1.pdf $(FIGS)/figure_2.pdf\	# appropriate tables and
				$(FIGS)/figure_3.pdf $(FIGS)/figure_4.pdf\	# figures
				$(FINAL)/study.Rmd $(FINAL)/study.md\
				$(FINAL)/study.tex $(FINAL)/study.pdf
