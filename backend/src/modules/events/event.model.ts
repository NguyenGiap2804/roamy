import { SystemEventSeverity } from '@prisma/client';
import { z } from 'zod';

export const eventCreateSchema = z.object({
  body: z.object({
    type: z.string().trim().min(1).max(80),
    action: z.string().trim().max(120).optional().nullable(),
    resourceType: z.string().trim().max(80).optional().nullable(),
    resourceId: z.string().trim().max(120).optional().nullable(),
    screen: z.string().trim().max(120).optional().nullable(),
    message: z.string().trim().max(500).optional().nullable(),
    severity: z.enum(SystemEventSeverity).optional(),
    deviceId: z.string().trim().max(120).optional().nullable(),
    metadata: z.unknown().optional(),
    occurredAt: z.iso.datetime().optional(),
  }),
});

export type EventCreateInput = z.infer<typeof eventCreateSchema>['body'];
