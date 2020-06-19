# -*- coding: utf-8 -*-
"""
Created on Thu May  5 20:57:53 2016

@author: Panos Bravakos
"""
#import os
#import pprint
#pp = pprint.PrettyPrinter(indent=4)


#os.chdir('D:\\phD\\DATA\\Whole_Genome_Sequencing\\Homology\\Pfam_pipeline\\Strain09\\No_Clan')

MinNumSeqs=50 #Sets the mininimum length of amino-acids to be printed in the 
#final fasta output. For example a value of 30 will exclude from the ouptupt 
#all proteins with sequence length less than 30. If no filetering is needed
#this value can be set equal to 1.

def readPfamOutput(pfamTable):
    '''
    reads pfam table output and creates a dictionary with values
    the envelope start and end coordinates(columns 4 and 5 of the pfam output)
    and keys the protein heading
    '''
    proteinDict = {}

    with open(pfamTable, 'r') as f:
        for line in f.readlines():
            if line[0] in ['#', '\n', '\r\n']:
                continue
            ls = line.strip().split()
            dictKey = ls[0]
            if dictKey in proteinDict.keys():
                proteinDict[dictKey].append((int(ls[3]), int(ls[4])))
            else:
                proteinDict[dictKey] = [(int(ls[3]), int(ls[4]))]
    return proteinDict


def readFasta(fastaFile):
    '''
    Read an amino acid fasta file and create a dictionary with 
    key the fasta heading and values the amino-acid sequence
    '''
    proteinSequenceDict = {}
    currentSequence = ''
    with open(fastaFile, 'r') as f:
        for line in f.readlines():
            if line[0] in ['#', '\n', '\r\n']:
                continue
            elif line[0] == '>':
                currentSequence = line[1:].strip()
                proteinSequenceDict[currentSequence] = ''
            else:
                proteinSequenceDict[currentSequence] = proteinSequenceDict[
                    currentSequence] + line.strip()
    return proteinSequenceDict


def merge_intervals(intervalsList):
    """
    It takes a list of ranges (tuples) and returns a list of ranges corresponding
    to the the overlap of the initial ranges.
    More specifically:
    1. Sorts the intervals in increasing order
    2. Pushes the first interval on the stack
    3. Iterates through intervals and for each one compare current interval
       with the top of the stack and:
       A. If current interval does not overlap, pushes on to stack
       B. If current interval does overlap, merges both intervals in to one
          and push on to stack
    4. At the end returns stack
    """

    si = sorted(intervalsList, key=lambda tup: tup[0])
    merged = []

    for tup in si:
        if not merged:
            merged.append(tup)
        else:
            b = merged.pop()
            if b[1] >= tup[0]:
                new_tup = (b[0], max(b[1], tup[1]))
                merged.append(new_tup)
            else:
                merged.append(b)
                merged.append(tup)
    return merged


def InvertRanges(RangeDict, SeqDict):
    """
    Takes two dictionaries, one with the ranges and one with the fasta formatted
    amino acids and returns a new dictionary with values the sequences that are
    NOT included in the given ranges.
    For example, if a protein is 302 residues long and regions 1–48, 1–53, 
    and 121–210 have matches to Pfam families it will produce a total of two 
    unannotated fragments spanning regions 54–120 and 211–302, respectively.
    """
    InvertRangesDict = {}
    for key, val in RangeDict.items():
        FastaSeq = SeqDict[key]
        previousPosition = 0
        maxPosition = len(FastaSeq)
        for AnnotatedRange in val:
            currentPosition = AnnotatedRange[0]
            if currentPosition-previousPosition>=MinNumSeqs:#if we don't add 
            #this line, we have to add instead: if currentPosition!=0:
                NewFastaHeading = key+"_"+str(previousPosition+1)+"-"+str(currentPosition-1)
                InvertRangesDict[NewFastaHeading] = FastaSeq[previousPosition:currentPosition-1]
                #We subtract (-1) because we want to take into account:
            #a) The fact that python counts from zero (0) while in the 
            #Annotated Columns (from the pfam output) we count from one (1).
            #b) The fact that slicing in python does not include the last number. 
            previousPosition = AnnotatedRange[1]
        
        if maxPosition>previousPosition and currentPosition-previousPosition>=MinNumSeqs:
            #This if statement is needed to add the last inverted range i.e. 
        #from the last 'normal' range till the end of the sequence
            NewFastaHeading = key+"_"+str(previousPosition)+"-"+str(maxPosition)
            InvertRangesDict[NewFastaHeading] = FastaSeq[previousPosition:maxPosition]
    return InvertRangesDict

    
    
    
#Here we create the dictionary with all the fasta sequences
FastaDict = readFasta('Strain09_amino-acid-fasta.faa')


#Here we read the pfam output file and save it to dictionary
PfamColDict = readPfamOutput('pfam_Strain09.output')


#Next we create a new dictionary which contains the overlap of the ranges
#and corresponds to the annotated proteins range
AnnotatedRangeDict = {}
for key, val in PfamColDict.items():
    AnnotatedRangeDict[key] = merge_intervals(val)

NotAnnotatedDict=InvertRanges(AnnotatedRangeDict, FastaDict)




#fasta output file
    
#For proteins with no marked up residues (i.e., with no Pfam match 
#in the pfam  output), the whole sequence has to be retained 
for key, val in FastaDict.items():
    if key not in AnnotatedRangeDict.keys(): #The comparison is with 
    #AnnotatedRangeDict because we have changed the keys (NewFastaHeading) 
    #of the NotAnnotatedDict
        if len(val)>=MinNumSeqs:
            NotAnnotatedDict[key]=val


#Finally we save the dictionary into a fasta format
with open("Not_annotated_proteins.fasta", 'w') as f:
    for key, val in NotAnnotatedDict.items():
        f.write(">"+key+"\n"+val+"\n")

    
        


 
        
        
#        