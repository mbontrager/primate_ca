# Bret Larget
# Martin Bontrager

#Set the working directory to the directory in which the script is run.
this.dir <- dirname(parent.frame(2)$ofile)
setwd(this.dir)

#Load and/or install require packages.
PkgTest <- function(x)
{
  if (!require(x,character.only = TRUE))
  {
    install.packages(x,dep=TRUE)
    if(!require(x,character.only = TRUE)) stop("Package not found")
  }
}

# Load libraries
PkgTest("ape")
PkgTest("hash")
PkgTest("RGenetics")

#Set the random number seed for reproducibility
set.seed(434995235)

# Number of trials (samples of entropy per gene from the expected distribution) and species sampled.
speciesSamplesPerGene = 50
nullTrials = 100

#Generate Sequences (1 = yes, 0 = no)
seqs = 0

# Reads in a list of filenames with aligned nucleotide sequences (starting and ending at coding positions)
Main = function(x){
  
  L <- setNames(replicate(6, matrix(0, nrow=speciesSamplesPerGene, ncol=3, 
       dimnames=list(paste("Trial",1:speciesSamplesPerGene), c("Observed", "Expected", "StdDev"))), simplify=FALSE), 
       c("GC.All", "GC.Var", "Mouse.All", "Mouse.Var", "PerGene.All", "PerGene.Var"))
  
  for (i in 1:length(x)){
    gene = processFile(paste("../data/aligned_coding_genes/", x[i], sep=""))
    gc = gcContent3(gene$dna)
    
    codonFreqGC = gcCodonUsage(gc)  ## Third position GC content per gene as the expected distribution
    codonFreqMouse = mouseUsage()  ## Mouse genome-wide codon usage as the expected
    codonFreqGene = geneCodonUsage(gene) ## Per-gene codon usage distribution as the expected
    
    taxa = sampleSpecies(speciesSamplesPerGene, gene)
    
    a = CalculateEntropy(gene, taxa, codonFreqGC)
    b = CalculateEntropy(gene, taxa, codonFreqMouse)
    c = CalculateEntropy(gene, taxa, codonFreqGene)
    
    L[]$GC.All = L[]$GC.All + a[[1]]
    L[]$GC.Var = L[]$GC.Var + a[[2]]
    L[]$Mouse.All = L[]$Mouse.All + b[[1]]
    L[]$Mouse.Var = L[]$Mouse.Var + b[[2]]
    L[]$PerGene.All = L[]$PerGene.All + c[[1]]
    L[]$PerGene.Var = L[]$PerGene.Var + c[[2]]
  }
  return(L)
}


#Calculate entropy and generate null distribution
CalculateEntropy = function(x, y, z){
  #  sdList = c()
  mat = matrix(0, nrow=speciesSamplesPerGene, ncol=3, 
    dimnames=list(paste("Trial",1:speciesSamplesPerGene), c("Observed", "Expected", "StdDev")))
  mat2 = matrix(0, nrow=speciesSamplesPerGene, ncol=3, 
    dimnames=list(paste("Trial",1:speciesSamplesPerGene), c("Observed", "Expected", "StdDev")))

  
  for (i in 1:length(y[,1])){
    h = synonymousSites1(x, y[i, ]) ## Includes conserved AA positions using the same codon
    h2 = synonymousSites2(x, y[i, ])  ## Excludes conserved AA positions with the same codon
    
#     if (i == 1){  ##Uncomment this if loop (along with other code) to output concatenated nucleotide seq
#       toOutput(x, y[i,],h)
#     }

    if (length(h) > 0){
      e = usage(x, h, y[i, ])
      f = generateUsage(nullTrials, x, h, y[i,], z) ##GC content, mouse, or per gene codon usage
      #f = generateUsage2(nullTrials, x, h, y[i,])
      mat[i,1] = e
      mat[i,2] = mean(f)
      mat[i,3] = var(f)
    }

    if (length(h2) > 0){
      e2 = usage(x, h2, y[, ])
      f2 = generateUsage(nullTrials, x, h2, y[i,], z) ##GC content, mouse, or per gene codon usage
      #f = generateUsage2(nullTrials, x, h, y[i,])
      mat2[i,1] = e2      
      mat2[i,2] = mean(f2)
      mat2[i,3] = var(f2)
    }
  }
  a <- list(mat, mat2)
  return(a)
}


# Read in codon table and create a hash table with aa, [codons] key,value pairs
codons = read.table("../data/codon_table.txt", header=T, sep="", as.is=c(1,2))
codonTable = hash()
for (i in 1:length(codons$codon)){
  if (all(has.key(codons$aa[i], codonTable))){
    codonTable[[codons$aa[i]]] = append(codonTable[[codons$aa[i]]], codons$codon[i])
  }
  else {
    codonTable[[codons$aa[i]]] = codons$codon[i]
  } 
}


# Read in species info
primates = read.table("../data/primate-species-16fam.csv",header=T,sep=";",quote="")

# Code to change sequence of coding dna into sequence of amino acids
dnaToAA = function(x) {
    n = length(x)
    if ( n %% 3 != 0 ) {
        stop("length of sequence not a multiple of three")
    }
    m = n %/% 3
    aa = character(m)
    index = 1
    for ( i in 1:m ) {
        foo = tolower(x[index:(index+2)])
        if ( any(foo == '-') )
            aa[i] = '-'
        else if ( !all(foo %in% c('a','c','g','t')) )
            aa[i] = '-'
        else
            aa[i] = codonToAAone(paste(x[index],x[index+1],x[index+2],sep=""))
        index = index + 3
    }
    return( aa )
}

# Function to remove first word from a string: here, get genus from species name
getGenus = function(x) {
    return( strsplit(x," ")[[1]][1] )
}

# Function to get family from genus using the information in primates
getFamily = function(genus) {
    return( as.character(primates$Family[which(primates$Genus == genus)[1]]) )
}

# processFile
# Read in a data file;
# Drop last row, which is duplicate of homo sapiens
processFile = function(file) {
    gene = read.dna(file,as.character=TRUE,format="fasta")
    gene = gene[-nrow(gene),]
    nspecies = nrow(gene)
    species = rownames(gene)
    genus = character(nspecies)
    for ( i in 1:nspecies )
        genus[i] = getGenus(species[i])

    family = character(nspecies)
    for ( i in 1:nspecies )
        family[i] = getFamily(genus[i])
    
    aa = character(0)
    for ( i in 1:nrow(gene) ) {
        aa = rbind(aa,dnaToAA(gene[i,]))
    }
    
    return ( list(name=sub("^([^.]*).*", "\\1", file),species=species,genus=genus,family=as.factor(family),dna=gene,aa=aa) )
}


# calculate entropy statistic
entropy = function(x) {
  y = x[x>0]
  p = y/sum(y)
  return( -1 * sum(p * log(p) ) )
}

# sample codon usage from a distribution
codon.sample = function(n,p) {
  s = sample(1:length(p),size=n,prob=p,replace=TRUE)
  x = rep(0,n)
  for ( i in 1:n )
    x[i] = sum(s==i)
  return( x )
}

# sample from null distribution
null.sample = function(B,n,p) {
  out = numeric(B)
  for ( i in 1:B ) {
    out[i] = entropy( codon.sample(n,p) )
  }
  return(out)
}

# Read in mouse genome-wide codon usage frequency
mouseUsage = function(){
  codons = read.table("../data/use_mouse.txt", header=T, sep="", as.is=1)
  codonUsageFreq = hash()
  for (i in 1:length(codons$codon)){
    codonUsageFreq[[codons$codon[i]]] = codons$freq[i]
  }
  return(codonUsageFreq)
}
  
# Function to sample variable length vectors (deals with length=1)
sample.primates = function(x, ...) x[sample(length(x), ...)]

# Function to sample one species from each family, B times
# Return in a matrix with B rows, each row is a sample of the indicies
# 6/20/14 - Exclude families with no sequenced representatives in a particular gene
sampleSpecies = function(B,x) {
    nfamilies = length(levels(x$family))
    out = matrix(0,B,nfamilies)
    for ( i in 1:nfamilies ) {
        fam = (levels(x$family))[i]
        indices = which( x$family == fam )
        if ( !any(is.na(indices)) )
            out[,i] = sample.primates(indices,size=B,replace=TRUE)
    }
    return( out )
}


# Function to return a vector of indices of synonymous aa sites from a group of taxa (including all same codon)
synonymousSites1 = function(x, s) {
  synSites = vector()
  for (i in 1:length(x$aa[1,])){
    residue = character(length(s))
    for (k in 1:length(s)){
      residue[k] = x$aa[s[k],i]
    }
    if (all(residue[1] == residue) && (residue[1] != "W") && (residue[1] != "M") && (residue[1] != "-"))
      synSites <- c(synSites, i)
  }
  return(synSites)
}


# Function to return a vector of indices of synonymous aa sites from a group of taxa (exclude all exact same codons)
synonymousSites2 = function(x, s) {
  synSites = vector()
  for (i in 1:length(x$aa[1,])){
    residue = character(length(s))
    codon = character(length(s))
    for (k in 1:length(s)){
      residue[k] = x$aa[s[k],i]
      startPos = (i*3)-2
      codon[k] = toupper(paste(x$dna[s[k], startPos:(startPos+2)], sep='', collapse=''))
    }
    if (all(residue[1] == residue) && (residue[1] != "W") && (residue[1] != "M") && (residue[1] != "-")){
      if (!(all(codon[1] == codon))){
        synSites = c(synSites, i)
      }
    }
  }
  return(synSites)
}


# Function to find gc content of all third codon positions in an alignment.
# x is a matrix of characters
gcContent3 = function(x) {
  nsites = ncol(x)
  if ( nsites %% 3 != 0 )
    stop("Expected number of sites to be a multiple of 3")
  third = seq(3,nsites,3)
  dna.tab = table(x[,third])
  gc = sum(dna.tab[ which(dimnames(dna.tab)[[1]] %in% c('c','g')) ])
  at = sum(dna.tab[ which(dimnames(dna.tab)[[1]] %in% c('a','t')) ])
  return( gc / (gc+at) )
}


#Calculate codon frequencies based on GC content of each gene
gcCodonUsage = function(gc){
  a = keys(codonTable)
  codonUsageFreq = hash()
  
  for (i in 1:length(a)){
    x = length(codonTable[[a[i]]])
    for (k in 1:x){
      if (x == 2){
        if (substr(codonTable[[a[i]]][k],3,3) == "G" || (substr(codonTable[[a[i]]][k],3,3) == "C"))
          codonUsageFreq[[codonTable[[a[i]]][k]]] = gc
        else {
          codonUsageFreq[[codonTable[[a[i]]][k]]] = (1-gc)
        }
      }
      else if(x == 3){
        if (substr(codonTable[[a[i]]][k],3,3) == "G" || (substr(codonTable[[a[i]]][k],3,3) == "C"))
          codonUsageFreq[[codonTable[[a[i]]][k]]] = 1-(((1-gc)/3)*4)
        else {
          codonUsageFreq[[codonTable[[a[i]]][k]]] = ((1-gc)/3)*2
        }
      }
      else if(x == 4){
        if (substr(codonTable[[a[i]]][k],3,3) == "G" || (substr(codonTable[[a[i]]][k],3,3) == "C"))
          codonUsageFreq[[codonTable[[a[i]]][k]]] = gc/2
        else {
          codonUsageFreq[[codonTable[[a[i]]][k]]] = (1-gc)/2
        }
      }
      else if(x == 6){
        if (substr(codonTable[[a[i]]][k],3,3) == "G" || (substr(codonTable[[a[i]]][k],3,3) == "C"))
          codonUsageFreq[[codonTable[[a[i]]][k]]] = (gc/3)
        else {
          codonUsageFreq[[codonTable[[a[i]]][k]]] = ((1-gc)/3)
        }
      }      
    }
  }
  return(codonUsageFreq)
}


# Calculate codon frequencies based on observed frequencies per gene
geneCodonUsage = function(gene){
  counts = hash()
  output = hash()
  
  for (i in 1:length(codons$codon)){
    output[[codons$codon[i]]] = 0
    counts[[codons$codon[i]]] = 0
  }
  for (i in 1:length(gene$aa[1,])){
    startPos = (i*3)-2
    for (j in 1:length(gene$species)){
      codon = toupper(paste(gene$dna[j, startPos:(startPos+2)], sep='', collapse=''))
      if (has.key(codon, counts)){
        counts[[codon]] = counts[[codon]] + 1
      }
    }  
  }
  for (i in 1:length(keys(counts))){
    c = keys(counts)[i]
    a = codonToAAone(c)
    if (a == "Stop"){
      a = "X"
    }
    s = 0
    for (j in 1:length(codonTable[[a]])){
      s = s + counts[[codonTable[[a]][j]]]
    }
    output[[c]] = counts[[c]] / s
  }
  return(output)
}


# Calculate codon frequencies based on observed frequencies per gene per species
speciesCodonUsage = function(gene, taxon){
  counts = hash()
  output = hash()
  
  for (i in 1:length(codons$codon)){
    output[[codons$codon[i]]] = 0
    counts[[codons$codon[i]]] = 0
  }
  for (i in 1:length(gene$aa[taxon,])){
    startPos = (i*3)-2
    codon = toupper(paste(gene$dna[taxon, startPos:(startPos+2)], sep='', collapse=''))
      if (has.key(codon, counts)){
        counts[[codon]] = counts[[codon]] + 1
      }
    }  

  for (i in 1:length(keys(counts))){
    c = keys(counts)[i]
    a = codonToAAone(c)
    if (a == "Stop"){
      a = "X"
    }
    s = 0
    for (j in 1:length(codonTable[[a]])){
      s = s + counts[[codonTable[[a]][j]]]
    }
    output[[c]] = counts[[c]] / s
  }
  return(output)
}

# Function to create a hash table of frequency for each codon position
cHash = function(x){
  a <- hash()
  for (i in 1:length(x)){
    a[[x[i]]] <- 0
  }
  return(a)
}


# Generate the summed entropy from B samples of a gene given a null distribution of codon usage
generateUsage = function(B, x, y, z, cuf){
  m = matrix(nrow=B, ncol=length(y))
  for (i in 1:length(y)){
    aa = x$aa[z[1], y[i]]
    a = codonTable[[aa]]
    pdist = c()
    for (j in 1:length(a)){
      pdist = c(pdist, cuf[[a[j]]])
    }
    m[,i] = null.sample(B, length(z), pdist)
  }
  n = rowSums(m)
  return(n)
}

# Generate the summed entropy from B samples of a gene given a null distribution of codon usage
generateUsage2 = function(B, gene, synSites, taxa){
  m = matrix(nrow=B, ncol=length(synSites))
  for (i in 1:length(synSites)){
    aa = gene$aa[taxa[1], synSites[i]]
    cList = codonTable[[aa]]
    
    for (j in 1:length(taxa)){
      specUsage = speciesCodonUsage(gene, taxa[j])
      pdist = c()
      for (n in 1:length(cList)){
        pdist = c(pdist, specUsage[[cList[n]]])
      }
      for (k in 1:B){
        
      }
    }   
    m[,i] = null.sample(B, length(z), pdist)
  }
  n = rowSums(m)
  return(n)
}


# Function to compute the entropy statistics over a vector y of synonymous sites
usage = function(x, y, z){
  entropyList = c()
  
  for (i in 1:length(y)){
    startPos = (y[i]*3)-2
    a = codonToAAone(paste(x$dna[z[1], startPos:(startPos+2)], sep='', collapse=''))
    b = cHash(codonTable[[a]])
    c = c()
    
    for (j in 1:length(z)){
      c = c(c, toupper(paste(x$dna[z[j], startPos:(startPos+2)], sep='', collapse='')))
    }
    
    c = table(c)
    d = names(c)
    for (k in 1:length(d)){
      b[[d[k]]] = (c[[d[k]]])
    }
    e = c()
    for (l in 1:length(d)){
      e = c(e, b[[d[l]]])
    }
    entropyList = c(entropyList, entropy(e))    
  }
  return(sum(entropyList))
}


# Generate a concatenated sequence of variable codons within conserved amino acids. Must uncomment a bunch of other stuff.
toOutput = function(gene, taxa, syn){
  nonSyn = setdiff(1:length(gene$aa[1,]), syn)
  a = setdiff(levels(primates$Family), levels(gene$family))
  if (length(a) >= 1){
  for (p in 1:length(a)){
    fastOut[[a[p]]] = c(fastOut[[a[p]]], paste(rep("-", (length(syn)*3)), collapse = ''))
    aaOut[[a[p]]] = c(aaOut[[a[p]]], paste(rep("-", (length(nonSyn))), collapse = ''))
  }
  }
  for (i in 1:length(taxa)){
    s = character()
    t = character()
    
    for (j in 1:length(syn)){
      startPos = (syn[j]*3)-2
      s = c(s, toupper(paste(gene$dna[taxa[i], startPos:(startPos+2)], sep='', collapse='')))
    }
    
    for (k in 1:length(nonSyn)){
      r = gene$aa[taxa[i], nonSyn[k]]
      if (r == "Stop"){
        r = "X"
      }
      t = c(t, r, sep='', collapse='')
    }
    
    s = paste(s, collapse='')
    t = paste(t, collapse='')
    fastOut[[as.character(gene$family[taxa[i]])]] = c(fastOut[[as.character(gene$family[taxa[i]])]], s)
    aaOut[[as.character(gene$family[taxa[i]])]] = c(aaOut[[as.character(gene$family[taxa[i]])]], t)
  }
}


seqGenerator = function(){
  f = file("Output.fa", "w")
  g = file("aaOutput.aln", "w")
  for (i in 1:length(keys(fastOut))){
    fastOut[[keys(fastOut)[i]]] = paste(fastOut[[keys(fastOut)[i]]], collapse='')
    aaOut[[keys(fastOut)[i]]] = paste(aaOut[[keys(fastOut)[i]]], collapse='')
    writeLines(c(paste(">", keys(fastOut)[i], collapse=''), fastOut[[keys(fastOut)[i]]]), f, sep="\n")
    writeLines(c(paste(">", keys(fastOut)[i], collapse=''), aaOut[[keys(fastOut)[i]]]), g, sep="\n")
  }
  close(f)
  close(g)
}


#The following block is only relevant if sequences are to be output.
fastOut = hash()
aaOut = hash()
for (i in 1:length(levels(primates$Family))){
  fastOut[[(levels(primates$Family)[i])]] = ''
  aaOut[[(levels(primates$Family)[i])]] = ''
}


#Read in the gene names. The file "genes.txt" must be present in the working directory
genes = scan("../data/aligned_coding_genes.txt", what='')

final = Main(genes)
#print(final)
write.table(final[]$GC.All, file="../results/GC.All.txt", quote = FALSE, row.names = TRUE, col.names = TRUE)
write.table(final[]$GC.Var, file="../results/GC.Var.txt", quote = FALSE, row.names = TRUE, col.names = TRUE)
write.table(final[]$Mouse.All, file="../results/Mouse.All.txt", quote = FALSE, row.names = TRUE, col.names = TRUE)
write.table(final[]$Mouse.Var, file="../results/Mouse.Var.txt", quote = FALSE, row.names = TRUE, col.names = TRUE)
write.table(final[]$PerGene.All, file="../results/PerGene.All.txt", quote = FALSE, row.names = TRUE, col.names = TRUE)
write.table(final[]$PerGene.Var, file="../results/PerGene.Var.txt", quote = FALSE, row.names = TRUE, col.names = TRUE)

#seqGenerator() ##Uncomment this, along with an if statement in the "CalculateEntropy" function, to output concatenated sequences