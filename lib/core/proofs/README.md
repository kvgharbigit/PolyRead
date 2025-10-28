# Phase 0: Architecture Validation Proofs

This directory contains proof-of-concept implementations to validate core technical assumptions before proceeding with full implementation.

## Validation Tests Required

### 1. PDF Text Extraction Proof
**File**: `pdf_extraction_proof.dart`
**Goal**: Validate that `pdfx` + `pdf_text` can extract text with ≥85% accuracy
**Test Cases**:
- Fiction novel (standard text layout)
- Technical textbook (complex formatting)
- Scanned document (OCR requirements)

### 2. ML Kit Translation Proof  
**File**: `ml_kit_translation_proof.dart`
**Goal**: Validate offline translation performance on mobile
**Test Cases**:
- Download EN↔ES models
- Translate 20 mixed sentences with punctuation
- Measure latency (target: <300ms)

### 3. EPUB Rendering Proof
**File**: `epub_rendering_proof.dart`  
**Goal**: Validate `epub_view` handles complex formatting
**Test Cases**:
- Footnotes and endnotes
- Poetry and special formatting
- RTL text and ruby annotations

### 4. SQLite Performance Proof
**File**: `sqlite_performance_proof.dart`
**Goal**: Validate dictionary lookup performance with FTS
**Test Cases**:
- Import 100K+ dictionary entries
- Measure FTS query performance (target: <10ms)
- Test concurrent access patterns

## Running Validation Tests

```bash
# Run individual proof tests
flutter test test/proofs/pdf_extraction_proof_test.dart
flutter test test/proofs/ml_kit_translation_proof_test.dart
flutter test test/proofs/epub_rendering_proof_test.dart
flutter test test/proofs/sqlite_performance_proof_test.dart

# Run all proof tests
flutter test test/proofs/
```

## Success Criteria

All validation tests must pass before proceeding to Phase 1:

- [ ] PDF text extraction ≥85% accuracy
- [ ] ML Kit translation <300ms latency
- [ ] EPUB rendering acceptable quality
- [ ] SQLite lookups <10ms average

## Fallback Plans

If any validation fails:
- **PDF**: Add ML Kit OCR pipeline for scanned documents
- **EPUB**: Custom WebView HTML renderer
- **Translation**: Reduce model size or add progressive loading
- **SQLite**: Optimize schema or reduce dictionary size