# Trained artifacts belong here

After running the Colab notebook, extract the downloaded run archive and copy
`best_model.pt` and `class_mapping.json` into this directory. Keep `evaluation.json`,
`run_metadata.json`, the split audit, and plots for your academic report.

No model has been trained or bundled in Phase 1. Large weights are ignored by Git.
Only load checkpoints you produced or otherwise trust. The backend uses
`torch.load(..., weights_only=True)` and validates architecture, labels, training
metadata, finite weights, and preprocessing before enabling inference.
