ALTER TABLE "User" ALTER COLUMN "email" DROP NOT NULL, ALTER COLUMN "passwordHash" DROP NOT NULL, ADD COLUMN "whatsappIdentity" CHAR(64);
CREATE UNIQUE INDEX "User_whatsappIdentity_key" ON "User"("whatsappIdentity");
ALTER TABLE "User" ADD CONSTRAINT "user_identity_kind" CHECK (("email" IS NOT NULL AND "passwordHash" IS NOT NULL AND "whatsappIdentity" IS NULL) OR ("email" IS NULL AND "passwordHash" IS NULL AND "whatsappIdentity" IS NOT NULL AND "role" = 'CLIENT'));

CREATE TABLE "WhatsAppBooking" (
  "id" UUID NOT NULL PRIMARY KEY,
  "clientId" UUID REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  "guestName" TEXT NOT NULL,
  "codeHash" CHAR(64) NOT NULL UNIQUE,
  "serviceId" UUID NOT NULL,
  "barberId" UUID NOT NULL,
  "startsAt" TIMESTAMPTZ(3) NOT NULL,
  "endsAt" TIMESTAMPTZ(3) NOT NULL,
  "priceCents" INTEGER NOT NULL,
  "isReward" BOOLEAN NOT NULL,
  "expiresAt" TIMESTAMPTZ(3) NOT NULL,
  "appointmentId" UUID UNIQUE REFERENCES "Appointment"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  "messageId" TEXT UNIQUE,
  "senderHash" CHAR(64),
  "response" TEXT,
  "replyClaimedAt" TIMESTAMPTZ(3),
  "repliedAt" TIMESTAMPTZ(3)
);
CREATE INDEX "WhatsAppBooking_clientId_expiresAt_idx" ON "WhatsAppBooking"("clientId", "expiresAt");
