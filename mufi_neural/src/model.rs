use candle_core::{DType, Device, Result, Tensor, D};
use candle_nn::{self as nn, Embedding, Linear, Module, VarBuilder};
use serde::{Deserialize, Serialize};

// ------------------------------------------------------------------ //
// Manual LayerNorm — uses elementwise ops compatible with Metal.
// nn::layer_norm uses a fused kernel absent from candle's Metal backend.
// ------------------------------------------------------------------ //

struct LayerNorm {
    weight: Tensor, // scale (γ), init 1
    bias: Tensor,   // shift (β), init 0
    eps: f64,
}

impl LayerNorm {
    fn new(size: usize, eps: f64, vb: VarBuilder) -> Result<Self> {
        let weight = vb.get_with_hints(size, "weight", nn::init::Init::Const(1.0))?;
        let bias = vb.get_with_hints(size, "bias", nn::init::Init::Const(0.0))?;
        Ok(Self { weight, bias, eps })
    }

    fn forward(&self, x: &Tensor) -> Result<Tensor> {
        let mean = x.mean_keepdim(D::Minus1)?;
        let diff = x.broadcast_sub(&mean)?;
        let var = diff.sqr()?.mean_keepdim(D::Minus1)?;
        let std = (var + self.eps)?.sqrt()?;
        let norm = diff.broadcast_div(&std)?;
        norm.broadcast_mul(&self.weight)?.broadcast_add(&self.bias)
    }
}

// ------------------------------------------------------------------ //
// Config
// ------------------------------------------------------------------ //

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub vocab_size: usize,
    pub n_layers: usize,
    pub n_heads: usize,
    pub d_model: usize,
    pub d_ff: usize,
    pub max_seq_len: usize,
    pub pad_token_id: u32,
}

impl Config {
    /// Default small config — ~6M parameters, trains on M-series CPU/GPU.
    pub fn small(vocab_size: usize) -> Self {
        Self {
            vocab_size,
            n_layers: 4,
            n_heads: 4,
            d_model: 256,
            d_ff: 1024,
            max_seq_len: 256,
            pad_token_id: 0,
        }
    }

    pub fn head_dim(&self) -> usize {
        self.d_model / self.n_heads
    }

    pub fn param_count(&self) -> usize {
        let emb = (self.vocab_size + self.max_seq_len) * self.d_model;
        // Q, K, V, O projections + biases; 2 FF layers + biases; 2 LN (scale+bias)
        let block = 4 * (self.d_model * self.d_model + self.d_model)
            + 2 * (self.d_model * self.d_ff + self.d_ff)
            + self.d_ff * self.d_model
            + self.d_model
            + 4 * self.d_model;
        let ln_f = 2 * self.d_model;
        let lm_head = self.d_model * self.vocab_size;
        emb + self.n_layers * block + ln_f + lm_head
    }
}

// ------------------------------------------------------------------ //
// Helpers
// ------------------------------------------------------------------ //

/// Returns an additive causal mask: 0.0 for allowed positions, -inf for future.
fn causal_mask(t: usize, device: &Device) -> Result<Tensor> {
    let mask: Vec<f32> = (0..t)
        .flat_map(|i| {
            (0..t).map(move |j| if j <= i { 0.0f32 } else { f32::NEG_INFINITY })
        })
        .collect();
    Tensor::from_slice(&mask, (1, 1, t, t), device)
}

// ------------------------------------------------------------------ //
// Causal Self-Attention
// ------------------------------------------------------------------ //

struct CausalSelfAttention {
    q: Linear,
    k: Linear,
    v: Linear,
    out: Linear,
    n_heads: usize,
    head_dim: usize,
}

impl CausalSelfAttention {
    fn new(cfg: &Config, vb: VarBuilder) -> Result<Self> {
        Ok(Self {
            q: nn::linear(cfg.d_model, cfg.d_model, vb.pp("q"))?,
            k: nn::linear(cfg.d_model, cfg.d_model, vb.pp("k"))?,
            v: nn::linear(cfg.d_model, cfg.d_model, vb.pp("v"))?,
            out: nn::linear(cfg.d_model, cfg.d_model, vb.pp("out"))?,
            n_heads: cfg.n_heads,
            head_dim: cfg.head_dim(),
        })
    }

    fn forward(&self, x: &Tensor) -> Result<Tensor> {
        let (b, t, c) = x.dims3()?;

        // Project and split into heads: (b, heads, t, head_dim)
        // .contiguous() after each transpose is required for Metal — the backend
        // cannot matmul non-contiguous (strided) tensors.
        let q = self
            .q
            .forward(x)?
            .reshape((b, t, self.n_heads, self.head_dim))?
            .transpose(1, 2)?
            .contiguous()?;
        let k = self
            .k
            .forward(x)?
            .reshape((b, t, self.n_heads, self.head_dim))?
            .transpose(1, 2)?
            .contiguous()?;
        let v = self
            .v
            .forward(x)?
            .reshape((b, t, self.n_heads, self.head_dim))?
            .transpose(1, 2)?
            .contiguous()?;

        // Scaled dot-product attention
        let scale = (self.head_dim as f64).sqrt().recip();
        // k_t: (b, heads, head_dim, t)
        let k_t = k.transpose(D::Minus2, D::Minus1)?.contiguous()?;
        let att = q.matmul(&k_t)?.affine(scale, 0.0)?;

        // Add causal mask
        let mask = causal_mask(t, x.device())?;
        let att = att.broadcast_add(&mask)?;

        // Softmax over last dim and weighted sum
        let att = candle_nn::ops::softmax(&att, D::Minus1)?;
        let y = att.matmul(&v)?; // (b, heads, t, head_dim)

        // Merge heads: (b, t, d_model)
        let y = y.transpose(1, 2)?.contiguous()?.reshape((b, t, c))?;
        self.out.forward(&y)
    }
}

// ------------------------------------------------------------------ //
// Feed-Forward Network
// ------------------------------------------------------------------ //

struct FeedForward {
    fc1: Linear,
    fc2: Linear,
}

impl FeedForward {
    fn new(cfg: &Config, vb: VarBuilder) -> Result<Self> {
        Ok(Self {
            fc1: nn::linear(cfg.d_model, cfg.d_ff, vb.pp("fc1"))?,
            fc2: nn::linear(cfg.d_ff, cfg.d_model, vb.pp("fc2"))?,
        })
    }

    fn forward(&self, x: &Tensor) -> Result<Tensor> {
        let h = self.fc1.forward(x)?.gelu()?;
        self.fc2.forward(&h)
    }
}

// ------------------------------------------------------------------ //
// Transformer Block  (pre-LN: LN → sub-layer → residual)
// ------------------------------------------------------------------ //

struct TransformerBlock {
    ln1: LayerNorm,
    attn: CausalSelfAttention,
    ln2: LayerNorm,
    ff: FeedForward,
}

impl TransformerBlock {
    fn new(cfg: &Config, vb: VarBuilder) -> Result<Self> {
        Ok(Self {
            ln1: LayerNorm::new(cfg.d_model, 1e-5, vb.pp("ln1"))?,
            attn: CausalSelfAttention::new(cfg, vb.pp("attn"))?,
            ln2: LayerNorm::new(cfg.d_model, 1e-5, vb.pp("ln2"))?,
            ff: FeedForward::new(cfg, vb.pp("ff"))?,
        })
    }

    fn forward(&self, x: &Tensor) -> Result<Tensor> {
        // Attention sub-layer with residual
        let x = (x + self.attn.forward(&self.ln1.forward(x)?)?)?;
        // FF sub-layer with residual
        let x = (&x + self.ff.forward(&self.ln2.forward(&x)?)?)?;
        Ok(x)
    }
}

// ------------------------------------------------------------------ //
// Full Language Model
// ------------------------------------------------------------------ //

pub struct MufiLM {
    token_emb: Embedding,
    pos_emb: Embedding,
    blocks: Vec<TransformerBlock>,
    ln_f: LayerNorm,
    lm_head: Linear,
    config: Config,
}

impl MufiLM {
    pub fn new(cfg: &Config, vb: VarBuilder) -> Result<Self> {
        let token_emb = nn::embedding(cfg.vocab_size, cfg.d_model, vb.pp("token_emb"))?;
        let pos_emb = nn::embedding(cfg.max_seq_len, cfg.d_model, vb.pp("pos_emb"))?;

        let blocks = (0..cfg.n_layers)
            .map(|i| TransformerBlock::new(cfg, vb.pp(format!("block_{i}"))))
            .collect::<Result<Vec<_>>>()?;

        let ln_f = LayerNorm::new(cfg.d_model, 1e-5, vb.pp("ln_f"))?;
        // No bias on lm_head — standard practice for tied/untied weight LMs
        let lm_head = nn::linear_no_bias(cfg.d_model, cfg.vocab_size, vb.pp("lm_head"))?;

        Ok(Self {
            token_emb,
            pos_emb,
            blocks,
            ln_f,
            lm_head,
            config: cfg.clone(),
        })
    }

    /// Forward pass. Returns logits of shape (batch, seq_len, vocab_size).
    pub fn forward(&self, input_ids: &Tensor) -> Result<Tensor> {
        let (b, t) = input_ids.dims2()?;
        assert!(
            t <= self.config.max_seq_len,
            "sequence length {t} exceeds max_seq_len {}",
            self.config.max_seq_len
        );

        // Token + positional embeddings
        let tok = self.token_emb.forward(input_ids)?;
        let pos_ids = Tensor::arange(0u32, t as u32, input_ids.device())?
            .unsqueeze(0)?
            .expand((b, t))?;
        let pos = self.pos_emb.forward(&pos_ids)?;
        let mut x = (tok + pos)?;

        for block in &self.blocks {
            x = block.forward(&x)?;
        }

        let x = self.ln_f.forward(&x)?;
        self.lm_head.forward(&x)
    }

    pub fn config(&self) -> &Config {
        &self.config
    }
}
