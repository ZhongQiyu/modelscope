# The RWKV Language Model

## v2

RWKV v2 is a RNN which can also be directly trained like a GPT transformer.

You only need x_t, a_t, b_t of position t to compute the vectors for position t+1. 

Hence it can be 100x faster than GPT, and 100x more VRAM friendly.

I AM STILL TRAINING A LM TO TEST ITS CONVERGENCE.

The model:

![RWKV-v2-RNN](RWKV-v2-RNN.png)

## v1

We propose the RWKV language model, with alternating time-mix and channel-mix layers:

<img src=
"https://render.githubusercontent.com/render/math?math=%5Cdisplaystyle+%5Cbegin%7Balign%2A%7D%0A%5Ctext%7BTime-mix+%3A%7D+%26%26+%5Ctext%7BTM%7D_%7Bt%2Cc%7D+%26%26%3D%26%26%5Ctext%7Bsigmoid%7D%28%5Ctext%7BR%7D_%7Bt%2Cc%7D%29+%26%26%5Ccdot%26%26+%26%26%5Ctextstyle%5Csum_%7Bu%7D+%26%26%5Ctextbf%7BW%7D_%7Bt%2Cu%2Cc%7D+%26%26%5Ccdot%26%26+%5Ctext%7Bsoftmax%7D_t%28%5Ctext%7BK%7D_%7Bu%2Cc%7D%29+%26%26%5Ccdot%26%26+%5Ctext%7BV%7D_%7Bu%2Cc%7D%5C%5C%0A%5Ctext%7BChannel-mix+%3A%7D+%26%26+%5Ctext%7BCM%7D_%7Bt%2Cc%7D+%26%26%3D%26%26%5Ctext%7Bsigmoid%7D%28%5Ctext%7BR%7D_%7Bt%2Cc%7D%29+%26%26%5Ccdot%26%26+%26%26%5Ctextstyle%5Csum_d+%26%26%5Ctextbf%7BW%7D_%7Bc%2Cd%7D+%26%26%5Ccdot%26%26+%5Ctext%7Bgelu%7D%28%5Ctext%7BK%7D_%7Bt%2Cd%7D%29+%26%26%5Ccdot%26%26+%5Ctext%7BV%7D_%7Bt%2Cd%7D%0A%5Cend%7Balign%2A%7D%0A" 
alt="\begin{align*}
\text{Time-mix :} && \text{TM}_{t,c} &&=&&\text{sigmoid}(\text{R}_{t,c}) &&\cdot&& &&\textstyle\sum_{u} &&\textbf{W}_{t,u,c} &&\cdot&& \text{softmax}_t(\text{K}_{u,c}) &&\cdot&& \text{V}_{u,c}\\
\text{Channel-mix :} && \text{CM}_{t,c} &&=&&\text{sigmoid}(\text{R}_{t,c}) &&\cdot&& &&\textstyle\sum_d &&\textbf{W}_{c,d} &&\cdot&& \text{gelu}(\text{K}_{t,d}) &&\cdot&& \text{V}_{t,d}
\end{align*}
">

* The R, K, V are generated by linear transforms of input, and W is parameter. The idea of RWKV is to decompose attention into R(target) * W(src, target) * K(src). So we can call R "receptance", and sigmoid means it's in 0~1 range.

* The Time-mix is similar to AFT (https://arxiv.org/abs/2105.14103). There are two differences.

(1) We changed the normalization (denominator). For masked language models, we define:

<img src=
"https://render.githubusercontent.com/render/math?math=%5Cdisplaystyle+%5Ctext%7Bsoftmax%7D_t%28%5Ctext%7BK%7D_%7Bu%2Cc%7D%29+%3D+%5Cfrac%7B%5Cexp%28%5Ctext%7BK%7D_%7Bu%2Cc%7D%29%7D%7B%5Csum_%7Bv+%5Cleq+t%7D%5Cexp%28%5Ctext%7BK%7D_%7Bv%2Cc%7D%29%7D" 
alt="\text{softmax}_t(\text{K}_{u,c}) = \frac{\exp(\text{K}_{u,c})}{\sum_{v \leq t}\exp(\text{K}_{v,c})}">  
 
Initialize K and R matrices (and the output projection matrix) to ZERO for fast & stable convergence.
 
(2) We decompose W_{t,u,c} and introduce multi-head W (here h is the corresponding head of c):

<img src=
"https://render.githubusercontent.com/render/math?math=%5Cdisplaystyle+W_%7Bt%2Cu%2Cc%7D%3Df_h%28t-u%29%5Ccdot+%5Calpha_h%28u%29+%5Ccdot+%5Cbeta_h%28t%29" 
alt="W_{t,u,c}=f_h(t-u)\cdot \alpha_h(u) \cdot \beta_h(t)">

Moreover we multiply the final output of Time-mix layer by γ(t). The reason for the α β γ factors, is because the context size is smaller when t is small, and this can be compensated using the α β γ factors.

* The Channel-mix is similar to GeGLU (https://arxiv.org/abs/2002.05202) with an extra R factor. Initialize R and W matrices to ZERO for fast & stable convergence.

* Finally, we add extra token-shift (time-shift mixing) as in (https://github.com/BlinkDL/minGPT-tuned).

# Token-shift (time-shift mixing)

The token-shift explicitly uses (half the channels of this token) & (half the channels of prev token) to generate all vectors (QKV, RWKV, ...).

```
self.time_shift = nn.ZeroPad2d((0,0,1,-1))

x = torch.cat([self.time_shift(x[:, :, :C//2]), x[:, :, C//2:]], dim = -1)
```

Dividing channels by 2 and shift-1 works great for char-level English and char-level Chinese LM.

However for BPE-level English LM, it's only effective if your embedding is large enough (at least 1024 - so the usual small L12-D768 model is not enough).

My theory on the effectiveness of token-shift:

When we train a GPT, the hidden representation of a token has to accomplish two different objects:

1. Predict the next token. Sometimes this is easy (obvious next token).

2. Collect all previous context info, so later tokens can use it. This is always hard.

The shifted channels can focus on (2), so we have good propagation of info. It's like some kind of residual connection, or a small RNN inside the transformer.

You can use token-shift in usual QKV self-attention too. I looked at the weights, and found V really likes the shifted channels, less so for Q. Makes sense if you think about it. I also found you may want to use less mixing in higher layers.

p.s. There is a MHA_pro model in this repo with strong performance. Give it a try :)

# The Head-QK Trick: learning to copy and avoid tokens

In usual transformer, a small model has difficulty copying tokens (such as person names) in the context. We add extra Q & K to the final output such that the model can directly copy (or avoid) tokens in the context. Afterwards the model will teach itself NER (named entity recognition) if you look at the learned weights.
```
q = self.head_q(x)[:,:T,:]
k = self.head_k(x)[:,:T,:]
c = (q @ k.transpose(-2, -1)) * (1.0 / 256)
c = c.masked_fill(self.copy_mask[:T,:T] == 0, 0)
c = c @ F.one_hot(idx, num_classes = self.config.vocab_size).float()       
x = self.head(x) + c
```

# The top-a Sampling method

We also propose a new sampling method called top-a (as in src/utils.py):

(1) Find the max probability p_max after softmax.

(2) Remove all entries whose probability is lower than 0.02 * pow(p_max, 2). So it's adaptive, hence "top-a".

(3) Feel free to tune the 0.02 and 2 factor. Tune 0.02 first.

The idea of top-a:
1. If max_prob=0.9, then remove all tokens with prob < 0.0162 (so, removing most alternatives)
2. If max_prob=0.5, then remove all tokens with prob < 0.0050 (so, allowing more choices)
3. If max_prob=0.1, then remove all tokens with prob < 0.0002 (so, allowing lots of possibilities)

```
probs = F.softmax(logits, dim=-1)

limit = torch.pow(torch.max(probs), 2) * 0.02
logits[probs < limit] = -float('Inf')
```

# Performance

Character-level loss on simplebooks-92 dataset https://dldata-public.s3.us-east-2.amazonaws.com/simplebooks.zip

![RWKV-vs-MHA](RWKV-vs-MHA.png)

Gray: usual MHA+Rotary+GeGLU - performance not as good. 17.2M params.

Red: RWKV ("linear" attention) - VRAM friendly - quite faster when ctx window is long - good performance. 16.6M params.

Green: MHA+Rotary+GeGLU+Token_shift. 17.2M params.

Blue: MHA_pro (MHA with various tweaks & RWKV-type-FFN) - slow - needs more VRAM - good performance. 16.6M params.

```
@software{peng_bo_2021_5196578,
  author       = {PENG Bo},
  title        = {BlinkDL/RWKV-LM: 0.01},
  month        = aug,
  year         = 2021,
  publisher    = {Zenodo},
  version      = {0.01},
  doi          = {10.5281/zenodo.5196577},
  url          = {https://doi.org/10.5281/zenodo.5196577}
}
```

# Initialization

We use careful initialization for RWKV to get fast convergence - orthogonal matrices with proper scaling, and special time_w curves. Check model.py for details.

Some learned time_w examples:

![RWKV-time-w](RWKV-time-w.png)
