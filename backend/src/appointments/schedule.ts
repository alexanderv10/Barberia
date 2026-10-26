import { DateTime } from 'luxon';

export const shopZone = () => process.env.SHOP_TIMEZONE || 'America/Guayaquil';
export function validSlot(start: DateTime, durationMin: number, now: DateTime = DateTime.utc()): boolean {
  const local = start.setZone(shopZone());
  const end = local.plus({ minutes: durationMin });
  return local.isValid && local.weekday <= 6 && local.hour >= 9 &&
    (end.hour < 19 || (end.hour === 19 && end.minute === 0)) &&
    end.hasSame(local, 'day') && local.minute % 30 === 0 && local.second === 0 && local.millisecond === 0 &&
    start.toMillis() > now.toMillis() && start.toMillis() <= now.plus({ days: 60 }).toMillis();
}
export function overlap(aStart: Date, aEnd: Date, bStart: Date, bEnd: Date) {
  return aStart < bEnd && aEnd > bStart;
}
