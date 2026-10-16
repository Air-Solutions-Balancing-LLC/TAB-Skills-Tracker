-- Mark ATA Complete for all NEBB Certified technicians (NEBB CT / NEBB CP).
-- Clears Exempt so Complete wins. Safe to re-run.

UPDATE public.technicians
   SET ata_completed_at = coalesce(ata_completed_at, now()),
       ata_archived_at  = NULL
 WHERE deleted_at IS NULL
   AND nebb_status IN ('NEBB CT', 'NEBB CP');
