import { test } from 'node:test';
import assert from 'node:assert/strict';
import { DateTime } from 'luxon';
import { overlap, validSlot } from '../src/appointments/schedule';

const now = DateTime.fromISO('2026-10-26T08:00:00-05:00');
test('permite el cierre exacto y rechaza servicios que superan el horario', () => {
  assert.equal(validSlot(DateTime.fromISO('2026-10-26T18:30:00-05:00'), 30, now), true);
  assert.equal(validSlot(DateTime.fromISO('2026-10-26T18:30:00-05:00'), 60, now), false);
});
test('rechaza domingos, pasado, segundos y horario fuera de cuadrícula', () => {
  for (const value of ['2026-11-01T10:00:00-05:00', '2026-10-25T10:00:00-05:00', '2026-10-26T10:00:01-05:00', '2026-10-26T10:15:00-05:00']) assert.equal(validSlot(DateTime.fromISO(value), 30, now), false);
});
test('dos citas adyacentes no se traslapan', () => {
  const d = (hour: number) => new Date(Date.UTC(2026, 9, 26, hour));
  assert.equal(overlap(d(9), d(10), d(10), d(11)), false);
  assert.equal(overlap(d(9), d(11), d(10), d(12)), true);
});
