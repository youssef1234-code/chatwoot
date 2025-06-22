/**
 * Text direction detection utility for mixed Arabic/English content
 * Provides functions to detect and handle RTL/LTR text content
 */

// RTL Unicode ranges
const RTL_RANGES = [
  [0x0590, 0x05ff], // Hebrew
  [0x0600, 0x06ff], // Arabic
  [0x0700, 0x074f], // Syriac
  [0x0750, 0x077f], // Arabic Supplement
  [0x0780, 0x07bf], // Thaana
  [0x07c0, 0x07ff], // NKo
  [0x0800, 0x083f], // Samaritan
  [0x0840, 0x085f], // Mandaic
  [0x08a0, 0x08ff], // Arabic Extended-A
  [0xfb1d, 0xfb4f], // Hebrew Presentation Forms
  [0xfb50, 0xfdff], // Arabic Presentation Forms-A
  [0xfe70, 0xfeff], // Arabic Presentation Forms-B
];

/**
 * Check if a character is RTL
 * @param {string} char - Single character to check
 * @returns {boolean} - True if character is RTL
 */
export const isRTLChar = (char) => {
  const code = char.charCodeAt(0);
  return RTL_RANGES.some(([start, end]) => code >= start && code <= end);
};

/**
 * Detect if text contains RTL characters
 * @param {string} text - Text to analyze
 * @returns {boolean} - True if text contains RTL characters
 */
export const hasRTLCharacters = (text) => {
  if (!text) return false;
  return Array.from(text).some(char => isRTLChar(char));
};

/**
 * Get the overall direction of text content
 * For mixed content, this determines the primary direction
 * @param {string} text - Text to analyze
 * @returns {'ltr'|'rtl'} - Primary text direction
 */
export const getTextDirection = (text) => {
  if (!text) return 'ltr';
  
  let rtlCount = 0;
  let ltrCount = 0;
  
  // Count RTL and LTR characters
  Array.from(text).forEach(char => {
    const code = char.charCodeAt(0);
    
    if (isRTLChar(char)) {
      rtlCount++;
    } else if (
      // Latin characters
      (code >= 0x0041 && code <= 0x005a) || // A-Z
      (code >= 0x0061 && code <= 0x007a) || // a-z
      // Extended Latin
      (code >= 0x00c0 && code <= 0x024f) ||
      // Cyrillic
      (code >= 0x0400 && code <= 0x04ff)
    ) {
      ltrCount++;
    }
  });
  
  // If we have RTL characters, prefer RTL for mixed content
  // This ensures Arabic text with some English words is treated as RTL
  return rtlCount > 0 ? 'rtl' : 'ltr';
};

/**
 * Determine if text should be displayed as RTL
 * This is different from getTextDirection as it's more conservative
 * Only returns true if text is predominantly RTL
 * @param {string} text - Text to analyze
 * @returns {boolean} - True if text should be displayed as RTL
 */
export const shouldDisplayAsRTL = (text) => {
  if (!text) return false;
  
  let rtlCount = 0;
  let totalChars = 0;
  
  Array.from(text).forEach(char => {
    const code = char.charCodeAt(0);
    
    // Skip whitespace and punctuation for counting
    if (code > 32 && code !== 127) {
      totalChars++;
      if (isRTLChar(char)) {
        rtlCount++;
      }
    }
  });
  
  // Text is RTL if more than 30% of characters are RTL
  return totalChars > 0 && (rtlCount / totalChars) > 0.3;
};

/**
 * Get CSS direction value for text
 * @param {string} text - Text to analyze
 * @returns {'ltr'|'rtl'} - CSS direction value
 */
export const getCSSDirection = (text) => {
  return shouldDisplayAsRTL(text) ? 'rtl' : 'ltr';
};

/**
 * Get appropriate text-align for content
 * @param {string} text - Text to analyze
 * @returns {'left'|'right'} - Text alignment
 */
export const getTextAlign = (text) => {
  return shouldDisplayAsRTL(text) ? 'right' : 'left';
};
