# Translation Popup Redesign Implementation Plan

## 🎯 **Goal**
Transform the current CyclingTranslationPopup into two distinct modes:
1. **Single Word Translation**: Minimal display with tap-to-cycle meanings
2. **Sentence Translation**: Full sentence translation with hyperlinked original text

## 📋 **Current State Analysis**

### Current Implementation:
- ✅ Unified popup for all text selections
- ✅ Dictionary → ML Kit → Server fallback chain
- ✅ Part-of-speech emoji indicators
- ✅ Tap-to-cycle meanings functionality  
- ✅ Long-press-to-expand context functionality
- ✅ Blur backdrop with animations

### Current Issues:
- ❌ No distinction between word vs sentence selections
- ❌ Complex UI shown for all selections (cycling indicators, etc.)
- ❌ Same translation strategy for words and sentences
- ❌ No hyperlinked text functionality

## 🚀 **Implementation Phases**

---

### **Phase 1: Text Type Detection & Routing** 
**Goal**: Detect and route word vs sentence selections to appropriate UI

#### **Phase 1.1: Add Selection Type Parameter**
- [ ] Add `TextSelectionType selectionType` parameter to `CyclingTranslationPopup`
- [ ] Update all calls to pass selection type from `BookReaderWidget`
- [ ] Add conditional UI branching in `build()` method

#### **Phase 1.2: Create UI Mode Detection**
- [ ] Add private method `_isWordMode()` to determine display mode
- [ ] Create placeholder layouts for both modes
- [ ] Test that routing works correctly

#### **Phase 1.3: Basic Mode Switching**
- [ ] Implement basic word mode (current behavior)
- [ ] Implement basic sentence mode (placeholder)
- [ ] Verify mode switching works with tap vs long-press

---

### **Phase 2: Single Word Mode - Minimal UI**
**Goal**: Create extremely minimal word translation display

#### **Phase 2.1: Minimal Word Layout**
- [ ] Create `_buildSingleWordView()` method
- [ ] Design minimal layout: `[emoji] translation`
- [ ] Remove cycling indicators from minimal view
- [ ] Remove expansion indicators from minimal view

#### **Phase 2.2: Preserve Word Functionality**
- [ ] Maintain tap-to-cycle meanings behavior
- [ ] Maintain long-press-to-expand behavior
- [ ] Ensure emoji part-of-speech indicators work
- [ ] Test dictionary → ML Kit fallback chain

#### **Phase 2.3: Polish Word Mode**
- [ ] Optimize animations for minimal layout
- [ ] Adjust popup sizing for minimal content
- [ ] Test visual polish and user experience

---

### **Phase 3: Sentence Mode - Translation Display**
**Goal**: Implement sentence translation with basic display

#### **Phase 3.1: Sentence Translation Layout**
- [ ] Create `_buildSentenceView()` method  
- [ ] Design layout: translated sentence + original sentence
- [ ] Implement sentence translation using ML Kit
- [ ] Handle translation loading states

#### **Phase 3.2: Service Integration**
- [ ] Route sentence selections to ML Kit/Server translation
- [ ] Bypass dictionary lookup for sentences
- [ ] Implement sentence translation caching
- [ ] Handle translation errors gracefully

#### **Phase 3.3: Basic Sentence Display**
- [ ] Show translated sentence at top
- [ ] Show original sentence below
- [ ] Apply appropriate styling and spacing
- [ ] Test with various sentence lengths

---

### **Phase 4: Hyperlinked Original Text**
**Goal**: Make words in original sentence tappable for individual translation

#### **Phase 4.1: Word Boundary Detection**
- [ ] Create `_parseWordsInSentence()` method
- [ ] Implement word boundary detection algorithm
- [ ] Handle punctuation and spacing correctly
- [ ] Support multilingual word boundaries

#### **Phase 4.2: Hyperlink Widget Creation**
- [ ] Create `TappableWord` widget for individual words
- [ ] Implement tap detection for individual words
- [ ] Style hyperlinks (underline, color, etc.)
- [ ] Handle word hover/tap states

#### **Phase 4.3: Nested Translation Integration**
- [ ] Open single-word popup when hyperlinked word is tapped
- [ ] Manage popup layering (sentence popup + word popup)
- [ ] Handle popup dismissal logic
- [ ] Prevent popup cascade issues

---

### **Phase 5: Service Optimization & Polish**
**Goal**: Optimize translation services and polish user experience

#### **Phase 5.1: Smart Service Selection**
- [ ] Use dictionary service for single words
- [ ] Use ML Kit/Server for sentences
- [ ] Implement intelligent fallback logic
- [ ] Cache translations efficiently

#### **Phase 5.2: Performance Optimization**
- [ ] Lazy load sentence translations
- [ ] Optimize hyperlink rendering
- [ ] Minimize popup rebuild frequency
- [ ] Test performance with long sentences

#### **Phase 5.3: Final Polish**
- [ ] Polish animations for both modes
- [ ] Ensure consistent styling
- [ ] Add accessibility support
- [ ] Comprehensive testing

---

## 🧪 **Testing Strategy**

### After Each Phase:
1. **Functional Testing**: Verify new functionality works
2. **Regression Testing**: Ensure existing functionality still works  
3. **User Experience Testing**: Test actual reading workflow
4. **Performance Testing**: Check for performance regressions

### Test Cases:
- [ ] Single word tap → minimal popup with cycling
- [ ] Single word long-press → context expansion
- [ ] Sentence long-press → sentence translation display
- [ ] Hyperlinked word tap → nested single-word popup
- [ ] Dictionary available → use dictionary for words
- [ ] Dictionary unavailable → fallback to ML Kit
- [ ] Multiple meanings → cycling works correctly
- [ ] Long sentences → layout handles overflow

---

## 📝 **Implementation Notes**

### Key Design Decisions:
1. **Backward Compatibility**: Preserve all existing functionality
2. **Progressive Enhancement**: Build new features on top of existing system
3. **Service Reuse**: Leverage existing translation service architecture
4. **Clean Separation**: Clear distinction between word and sentence modes

### Code Structure:
```dart
CyclingTranslationPopup
├── _buildSingleWordView()    // Phase 2
├── _buildSentenceView()      // Phase 3  
├── _parseWordsInSentence()   // Phase 4
└── TappableWord              // Phase 4
```

### Translation Flow:
```
Selection Type Detection → Mode Routing → Service Selection → UI Rendering
```

---

## ✅ **Phase Completion Checklist**

- [ ] **Phase 1**: Text type detection and routing implemented
- [ ] **Phase 2**: Single word minimal UI completed  
- [ ] **Phase 3**: Sentence translation display implemented
- [ ] **Phase 4**: Hyperlinked original text functional
- [ ] **Phase 5**: Optimization and polish completed

**Total Estimated Implementation**: 5 Phases, ~15-20 tasks
**Testing Strategy**: Test after each phase, comprehensive testing at end
**Safety**: Reference commit created (4db9d06) for rollback if needed