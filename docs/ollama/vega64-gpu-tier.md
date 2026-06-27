# Local LLM on Vega 64 (D008) — deferred project record

**Status:** DEFERRED 2026-06-27. Worked out in a prior planning session.

**Relationship:** This is the **GPU evolution** of the CPU-only local-LLM tier
(P005 / `ollama-tier.md`) and the performance enabler for a future D005 resume
(`heartbeat-hybrid-design.md`) — GPU offload is what lifts the CPU tok/s ceiling
that capped D005. **Open scoping question:** which host gets the card — CT172
(existing Ollama LXC) via passthrough, or a separate/new machine — determining
whether it augments or replaces the CPU tier.

**Hardware:** 32 vCPU / 64 GB RAM / Vega 64 (8 GB VRAM).

## Topics Discussed

- Running LLMs locally on 32 vCPU / 64 GB RAM / Vega 64 (8 GB) hardware.
- Using GPU and system RAM together with hybrid inference.
- 4-bit quantization: quality vs. speed trade-off.
- How model weights vs. context (KV cache) consume VRAM.
- Why VRAM headroom must be reserved for context.
- Which current models fit in 8 GB.

## Decisions

- **Backend:** Vulkan, not ROCm (Vega is gfx900, dropped from official ROCm
  support).
- **Quantization:** Q4_K_M — about 1% quality loss, faster, best size/quality
  balance.
- **Strategy:** fully offload weights to GPU, but size context to leave room for
  the KV cache so it does not OOM mid-session.
- **KV cache:** quantize it (8-bit) to free VRAM and allow longer context.
- **Primary model:** Qwen3-8B (current, fits fully, about 16k context on 8 GB).
- **Alternates:** Llama-3.1-8B (safe fallback), Gemma-4 12B (more capable,
  partial offload).
- **Sources:** pull models from official org repos only, not community merges.

## Key Concepts

- LLM inference is memory-bandwidth-bound, so GPU layers run far faster than CPU
  layers.
- A bigger model at 4-bit beats a smaller model at higher precision.
- Weights and a layer's KV cache live together: GPU layer -> VRAM, CPU layer ->
  RAM.
- KV cache grows linearly with context length; that is the headroom to reserve.

## Implementation Steps

1. Confirm the Vega 64 is real PCIe passthrough (IOMMU) in Proxmox, not
   virtualized.
2. Build llama.cpp with the Vulkan backend.
3. Download Qwen3-8B (Q4_K_M) from the official Qwen repo.
4. Launch with full GPU offload, flash attention, quantized KV cache, and
   context sized to about 16k.
5. Benchmark tok/s; tune context size and CPU thread count.
6. Optionally add Gemma-4 12B for heavier tasks (partial offload).

## Open Items / To Verify

- GPU passthrough health and PCIe link width.
- Exact Qwen3 family variants/sizes on the official model card.
- Thinking vs. non-thinking default by use case.
- Which host receives the card: CT172 or a separate/new machine.
