CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE "Appointment" ADD CONSTRAINT "positive_interval" CHECK ("endsAt" > "startsAt");
ALTER TABLE "Appointment" ADD CONSTRAINT "nonnegative_price" CHECK ("priceCents" >= 0);
ALTER TABLE "Service" ADD CONSTRAINT "valid_service" CHECK ("durationMin" BETWEEN 15 AND 240 AND "priceCents" >= 0);
ALTER TABLE "LoyaltyCard" ADD CONSTRAINT "stamp_bounds" CHECK ("currentStamps" BETWEEN 0 AND 10 AND "lifetimeStamps" >= "currentStamps");

-- PostgreSQL is the final authority, even with concurrent requests or multiple API instances.
ALTER TABLE "Appointment" ADD CONSTRAINT "barber_no_overlap"
  EXCLUDE USING gist ("barberId" WITH =, tstzrange("startsAt", "endsAt", '[)') WITH &&)
  WHERE ("status" <> 'CANCELLED');
ALTER TABLE "Appointment" ADD CONSTRAINT "client_no_overlap"
  EXCLUDE USING gist ("clientId" WITH =, tstzrange("startsAt", "endsAt", '[)') WITH &&)
  WHERE ("status" <> 'CANCELLED');

CREATE UNIQUE INDEX "one_pending_reward" ON "Appointment" ("clientId")
  WHERE "isReward" = true AND "status" = 'PENDING';
