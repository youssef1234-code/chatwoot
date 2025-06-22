/**
 * Test for text direction helper
 */

import {
  isRTLChar,
  hasRTLCharacters,
  getTextDirection,
  shouldDisplayAsRTL,
  getCSSDirection,
  getTextAlign,
} from '../textDirectionHelper.js';

describe('TextDirectionHelper', () => {
  describe('isRTLChar', () => {
    it('should detect Arabic characters as RTL', () => {
      expect(isRTLChar('ا')).toBe(true);
      expect(isRTLChar('م')).toBe(true);
      expect(isRTLChar('ع')).toBe(true);
    });

    it('should detect Hebrew characters as RTL', () => {
      expect(isRTLChar('א')).toBe(true);
      expect(isRTLChar('ב')).toBe(true);
    });

    it('should detect Latin characters as LTR', () => {
      expect(isRTLChar('a')).toBe(false);
      expect(isRTLChar('A')).toBe(false);
      expect(isRTLChar('1')).toBe(false);
    });
  });

  describe('hasRTLCharacters', () => {
    it('should return true for text with Arabic characters', () => {
      expect(hasRTLCharacters('مرحبا')).toBe(true);
      expect(hasRTLCharacters('Hello مرحبا')).toBe(true);
      expect(hasRTLCharacters('مرحبا World')).toBe(true);
    });

    it('should return false for text without RTL characters', () => {
      expect(hasRTLCharacters('Hello World')).toBe(false);
      expect(hasRTLCharacters('123 ABC')).toBe(false);
      expect(hasRTLCharacters('')).toBe(false);
    });
  });

  describe('getTextDirection', () => {
    it('should return RTL for Arabic text with some English', () => {
      expect(getTextDirection('مرحبا Hello')).toBe('rtl');
      expect(getTextDirection('Hello مرحبا')).toBe('rtl');
      expect(getTextDirection('مرحبا')).toBe('rtl');
    });

    it('should return LTR for English text', () => {
      expect(getTextDirection('Hello World')).toBe('ltr');
      expect(getTextDirection('Test 123')).toBe('ltr');
    });

    it('should return LTR for empty text', () => {
      expect(getTextDirection('')).toBe('ltr');
      expect(getTextDirection(null)).toBe('ltr');
    });
  });

  describe('shouldDisplayAsRTL', () => {
    it('should return true for predominantly Arabic text', () => {
      expect(shouldDisplayAsRTL('مرحبا بكم في العالم')).toBe(true);
      expect(shouldDisplayAsRTL('مرحبا Hello')).toBe(true);
    });

    it('should return false for predominantly English text', () => {
      expect(shouldDisplayAsRTL('Hello World مرحبا')).toBe(false);
      expect(shouldDisplayAsRTL('This is a test with one مرحبا word')).toBe(false);
    });

    it('should return false for pure English text', () => {
      expect(shouldDisplayAsRTL('Hello World')).toBe(false);
      expect(shouldDisplayAsRTL('Test 123')).toBe(false);
    });
  });

  describe('getCSSDirection', () => {
    it('should return appropriate CSS direction', () => {
      expect(getCSSDirection('مرحبا بكم')).toBe('rtl');
      expect(getCSSDirection('Hello World')).toBe('ltr');
      expect(getCSSDirection('مرحبا Hello World')).toBe('rtl');
    });
  });

  describe('getTextAlign', () => {
    it('should return appropriate text alignment', () => {
      expect(getTextAlign('مرحبا بكم')).toBe('right');
      expect(getTextAlign('Hello World')).toBe('left');
      expect(getTextAlign('مرحبا Hello World')).toBe('right');
    });
  });

  describe('Mixed content scenarios', () => {
    it('should handle Arabic with numbers correctly', () => {
      expect(shouldDisplayAsRTL('مرحبا 123')).toBe(true);
      expect(getCSSDirection('مرحبا 123')).toBe('rtl');
    });

    it('should handle Arabic with English words', () => {
      expect(shouldDisplayAsRTL('مرحبا Hello مرحبا')).toBe(true);
      expect(getCSSDirection('مرحبا Hello مرحبا')).toBe('rtl');
    });

    it('should handle English with few Arabic words', () => {
      expect(shouldDisplayAsRTL('This is a test with مرحبا word')).toBe(false);
      expect(getCSSDirection('This is a test with مرحبا word')).toBe('ltr');
    });
  });
});
