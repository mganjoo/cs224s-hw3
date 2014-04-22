#!/bin/bash

# Note: this TIDIGITS setup has not been tuned at all and has some obvious
# deficiencies; this has been created as a starting point for a tutorial.
# We're just using the "adults" data here, not the data from children.

# Kaldi example running script
# Adapted for Stanford's CS 224s: Spoken Language Processing
# Adapted by Peng Qi 
# Last updated: April 9, 2014

# Do some cleaning up (this is crucial if you modify parts of the script
# and want to compare results before and after)
printf "\033c"
rm -r -f mfcc
rm -r -f data
rm -r -f exp

# Prepare some essential environment variables
. ./path.sh
. ./cmd.sh 

tidigits=/afs/ir/class/cs224s/hw/hw3/data/TIDIGITS
train_cmd="run.pl"
decode_cmd="run.pl"

# The following command prepares the data/{train,dev,test} directories.
traindir=$1
[ -z "$traindir" ] && traindir=1

case $traindir in
1 ) traindir="train_reduced_men"; monodir="train";;
2 ) traindir="train_reduced_women"; monodir="train";;
3 ) traindir="train_reduced"; monodir="train";;
4 ) traindir="train"; monodir="train_1k";;
* ) echo "ERROR: Unknown training directory setting" && exit 1;
esac

local/tidigits_data_prep.sh $tidigits $traindir || exit 1;
local/tidigits_prepare_lang.sh  || exit 1;
utils/validate_lang.pl data/lang/

# Now make MFCC features.

## CS 224s: YOUR CODE HERE
mfccdir=mfcc
for x in test train; do
 steps/make_mfcc.sh --cmd "$train_cmd" --nj 20 \
   data/$x exp/make_mfcc/$x $mfccdir || exit 1;

 steps/compute_cmvn_stats.sh data/$x exp/make_mfcc/$x $mfccdir || exit 1;
done
## END YOUR CODE

[ $traindir -ne "train" ] || utils/subset_data_dir.sh data/train 1000 data/train_1k


# try --boost-silence 1.25 to some of the scripts below (also 1.5, if that helps...
# effect may not be clear till we test triphone system.  See
# wsj setup for examples (../../wsj/s5/run.sh)

## CS 224s Students,
## Here's the main training process for training our acoustic model.
## We've provided you with some starter code that trains a monophone
## acoustic model for you. Please follow the instructions to make
## changes in this section.

steps/train_mono.sh  --nj 4 --cmd "$train_cmd" \
  data/$monodir data/lang exp/mono0a

 utils/mkgraph.sh --mono data/lang exp/mono0a exp/mono0a/graph && \
 steps/decode.sh --nj 10 --cmd "$decode_cmd" \
      exp/mono0a/graph data/test exp/mono0a/decode
 steps/decode.sh --nj 10 --cmd "$decode_cmd" \
      exp/mono0a/graph data/train exp/mono0a/decode_train

## YOUR CODE HERE

steps/align_si.sh --nj 4 --cmd "$train_cmd" \
  data/train data/lang exp/mono0a exp/mono0a_ali

steps/train_deltas.sh --cmd "$train_cmd" \
   100 8000 data/train data/lang exp/mono0a_ali exp/tri1

utils/mkgraph.sh data/lang exp/tri1 exp/tri1/graph
steps/decode.sh --nj 10 --cmd "$decode_cmd" \
     exp/tri1/graph data/test exp/tri1/decode
steps/decode.sh --nj 10 --cmd "$decode_cmd" \
     exp/tri1/graph data/train exp/tri1/decode_train

## END YOUR CODE

# Example of looking at the output.
# utils/int2sym.pl -f 2- data/lang/words.txt  exp/tri1/decode/scoring/19.tra | sed "s/ $//" | sort | diff - data/test/text

# Getting results [see RESULTS file]

echo "=== Word Error Rates ==="
for x in exp/*/decode*; do [ -d $x ] && grep WER $x/wer_* | utils/best_wer.sh; done
echo "=== Sentence Error Rates ==="
for x in exp/*/decode*; do [ -d $x ] && grep SER $x/wer_* | utils/best_wer.sh; done

#exp/mono0a/decode/wer_17:%SER 3.67 [ 319 / 8700 ]
#exp/tri1/decode/wer_19:%SER 2.64 [ 230 / 8700 ]
