import { Transform } from 'class-transformer';
import { Matches } from 'class-validator';

// These fields store plain text, never HTML. Do not apply normalization to passwords.
export function normalizeText(value: unknown, multiline = false): unknown {
  if (typeof value !== 'string') return value;
  const text = value.normalize('NFC').replace(/\r\n?/g, '\n').trim();
  return multiline ? text : text.replace(/[\t\n ]+/g, ' ');
}
export const PlainText = (multiline = false) => Transform(({ value }) => normalizeText(value, multiline));
export const EmailInput = () => Transform(({ value }) => typeof value === 'string' ? value.trim().toLowerCase() : value);
export const safeTextPattern = /^[^<>\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f\u202a-\u202e\u2066-\u2069]*$/u;
export const SafeText = () => Matches(safeTextPattern, {
  message: '$property debe ser texto plano, sin etiquetas ni caracteres de control.',
});
