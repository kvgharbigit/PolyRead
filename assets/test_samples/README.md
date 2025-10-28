# Test Sample Files for Phase 0 Validation

This directory should contain sample files for testing core functionality:

## Required PDF Files

Add these PDF files for testing PDF text extraction:

- `fiction_novel.pdf` - Standard novel with normal text layout
- `technical_textbook.pdf` - Complex formatting with tables, figures
- `scanned_document.pdf` - Image-based PDF requiring OCR

## Required EPUB Files

Add these EPUB files for testing EPUB rendering:

- `fiction_novel.epub` - Standard fiction book
- `poetry_collection.epub` - Poetry with special formatting
- `technical_manual.epub` - Complex technical content

## Sample File Sources

### Free PDF Sources:
- Project Gutenberg: https://www.gutenberg.org/
- Archive.org: https://archive.org/details/texts
- OpenStax textbooks: https://openstax.org/

### Free EPUB Sources:
- Project Gutenberg EPUB: https://www.gutenberg.org/ebooks/
- Standard Ebooks: https://standardebooks.org/
- Internet Archive: https://archive.org/details/texts

## Usage

These files are used by the Phase 0 validation tests in:
- `test/proofs/phase_0_validation_test.dart`
- `lib/core/proofs/pdf_extraction_proof.dart`
- `lib/core/proofs/epub_rendering_proof.dart`

## File Size Recommendations

- PDFs: 1-5MB each (not too large for testing)
- EPUBs: 500KB-2MB each
- Total test samples: <20MB

Once you add these files, run:
```bash
flutter test test/proofs/phase_0_validation_test.dart
```