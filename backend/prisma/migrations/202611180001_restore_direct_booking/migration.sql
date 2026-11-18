-- Preserve the applied migration history and refuse to remove any existing data.
BEGIN;
LOCK TABLE "User", "WhatsAppBooking" IN ACCESS EXCLUSIVE MODE;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM "WhatsAppBooking")
     OR EXISTS (SELECT 1 FROM "User" WHERE "whatsappIdentity" IS NOT NULL OR "email" IS NULL OR "passwordHash" IS NULL) THEN
    RAISE EXCEPTION 'Cannot remove the retired booking integration while related data exists';
  END IF;
END $$;
DROP TABLE "WhatsAppBooking";
ALTER TABLE "User"
  DROP CONSTRAINT "user_identity_kind",
  DROP COLUMN "whatsappIdentity",
  ALTER COLUMN "email" SET NOT NULL,
  ALTER COLUMN "passwordHash" SET NOT NULL;
COMMIT;
